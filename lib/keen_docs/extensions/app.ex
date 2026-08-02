defmodule KeenDocs.Extensions.App do
  @moduledoc """
  Mounts a `../keen-phoenix-svelte` island — the markdown equivalent of `<.app>`.

  Islands are the rare end of the demo spectrum (DESIGN.md §5): most demos are markup
  plus a CDN web component, and only genuinely interactive apps (inline-edit, chat, a
  LiveView-backed browser) need a compiled bundle with an `api`/`live`/`channel`
  bridge. This renders the same wrapper contract `<.app>` does:

      <div id="kd-app-1" phx-hook="KeenApp" phx-update="ignore"
           data-app="org-browser" data-props='{"org_id":42}' data-eager="false">…placeholder…</div>

  Authoring is explicit — every part is a named block rather than an inferred one:

      :::app{name="org-browser" component="tree"}

      :::props
      ```json
      { "org_id": 42, "depth": 3 }
      ```
      :::

      :::placeholder
      Loading the org browser…
      :::

      :::

  Attributes: `name` (required), `id`, `component`, `class`, `tag`, `eager`, and `src`
  to point at a specific bundle.

  ## Bundle resolution

  A bundle URL comes from `src`, else from front matter `apps: {name: url}`, else from
  the configured base path — mirroring `KeenPhoenixSvelte.Apps.base_path/0`:

      config :keen_docs, #{inspect(__MODULE__)},
        base_path: "/apps",
        context: %{},
        runtime: nil

  `runtime` is the URL of a module that calls `mountStatic()`, for standalone pages
  that have no Phoenix `app.js`. Left `nil`, no bootstrap is emitted and the host
  application is assumed to mount islands itself, as a real Phoenix page does.

  ## Why `finalize/1`

  The `keen-apps` manifest has to list every island on the page, which is only known
  once the body is rendered. `document/3` runs too early, so the used apps accumulate
  in the context's private store and the manifest, preloads and context script are
  emitted from `c:KeenDocs.Markdown.Extension.finalize/1`.

  Note that `<.app>` tracks its used apps in `Process.put/2`. Here the render context
  carries them instead, so two documents rendered in the same process cannot bleed
  into each other's manifest.
  """

  use KeenMarkdown.Extension

  alias KeenMarkdown.{Context, HTML, Renderer}

  @default_base_path "/apps"
  @tag_re ~r/^[a-zA-Z][\w-]*$/

  @impl true
  def directives, do: ~w(app props placeholder)

  @impl true
  def render({:directive, "app", attrs, children}, ctx), do: island(attrs, children, ctx)

  # `:::props` is data consumed by its parent `:::app`; on its own it renders nothing.
  def render({:directive, "props", _attrs, _children}, ctx), do: {"", ctx}

  # `:::placeholder` outside an island is just its content.
  def render({:directive, "placeholder", _attrs, children}, ctx),
    do: Renderer.render_nodes(children, ctx)

  @impl true
  def finalize(ctx) do
    case used_apps(ctx) do
      [] -> ctx
      apps -> apps |> Enum.reverse() |> emit_runtime(ctx)
    end
  end

  # ---- the island wrapper ----

  defp island(attrs, children, ctx) do
    with {:ok, name} <- fetch_name(attrs),
         {:ok, props} <- props(children) do
      {id, ctx} = island_id(attrs["id"], ctx)
      {placeholder, ctx} = placeholder(children, ctx)
      ctx = track(ctx, name, attrs["src"])

      {wrapper(id, name, merge_component(props, attrs["component"]), attrs, placeholder), ctx}
    else
      {:error, message} -> {error(message), ctx}
    end
  end

  defp wrapper(id, name, props, attrs, placeholder) do
    tag = tag(attrs["tag"])

    [
      "<#{tag} id=\"#{HTML.esc(id)}\"",
      class_attr(attrs["class"]),
      ~s( phx-hook="KeenApp" phx-update="ignore"),
      ~s( data-app="#{HTML.esc(name)}"),
      ~s( data-props="#{HTML.esc(Jason.encode!(props))}"),
      ~s( data-eager="#{eager(attrs["eager"])}">),
      placeholder,
      "</#{tag}>"
    ]
  end

  defp fetch_name(attrs) do
    case attrs["name"] do
      name when is_binary(name) and name != "" -> {:ok, name}
      _ -> {:error, "<code>:::app</code> needs a <code>name</code> attribute."}
    end
  end

  defp island_id(id, ctx) when is_binary(id) and id != "", do: {id, ctx}
  defp island_id(_id, ctx), do: Context.next_id(ctx, "kd-app")

  # Props are validated here rather than passed through, so malformed JSON fails at
  # build time instead of shipping an island that cannot mount.
  defp props(children) do
    case find_directive(children, "props") do
      nil ->
        {:ok, %{}}

      {:directive, _name, _attrs, props_children} ->
        case find_fence(props_children) do
          nil -> {:ok, %{}}
          code -> decode(code)
        end
    end
  end

  defp decode(code) do
    case Jason.decode(code) do
      {:ok, props} when is_map(props) -> {:ok, props}
      {:ok, _other} -> {:error, "<code>:::props</code> must contain a JSON object."}
      {:error, _reason} -> {:error, "<code>:::props</code> does not contain valid JSON."}
    end
  end

  defp placeholder(children, ctx) do
    case find_directive(children, "placeholder") do
      nil -> {"", ctx}
      {:directive, _name, _attrs, inner} -> Renderer.render_nodes(inner, ctx)
    end
  end

  # `component=` is sugar for a `component` prop, and wins over one already in props.
  defp merge_component(props, nil), do: props
  defp merge_component(props, ""), do: props
  defp merge_component(props, component), do: Map.put(props, "component", component)

  defp find_directive(children, name) do
    Enum.find(children, &match?({:directive, ^name, _attrs, _children}, &1))
  end

  defp find_fence(children) do
    Enum.find_value(children, fn
      {:fence, _lang, _flags, code} -> code
      _node -> nil
    end)
  end

  defp tag(tag) when is_binary(tag), do: if(Regex.match?(@tag_re, tag), do: tag, else: "div")
  defp tag(_tag), do: "div"

  defp class_attr(nil), do: ""
  defp class_attr(""), do: ""
  defp class_attr(class), do: ~s( class="#{HTML.esc(class)}")

  defp eager(true), do: "true"
  defp eager("true"), do: "true"
  defp eager(_other), do: "false"

  defp error(message), do: ~s(<div class="kd-app-error">#{message}</div>)

  # ---- page-level runtime, emitted once the body is known ----

  defp track(ctx, name, src) do
    apps = used_apps(ctx)

    if Enum.any?(apps, &(elem(&1, 0) == name)) do
      ctx
    else
      Context.put_private(ctx, __MODULE__, [{name, src} | apps])
    end
  end

  defp used_apps(ctx), do: Context.get_private(ctx, __MODULE__, [])

  defp emit_runtime(apps, ctx) do
    manifest = Map.new(apps, fn {name, src} -> {name, url(name, src, ctx)} end)

    ctx
    |> Context.put_asset("keen-context", :head, context_script(ctx))
    |> Context.put_asset("keen-apps", :head, manifest_script(manifest))
    |> preloads(manifest)
    |> bootstrap()
  end

  defp context_script(ctx) do
    context = Map.merge(config(:context, %{}), Context.meta(ctx)["app_context"] || %{})

    ~s(<script type="application/json" id="keen-context">#{Jason.encode!(context, escape: :html_safe)}</script>\n)
  end

  defp manifest_script(manifest),
    do:
      ~s(<script type="application/json" id="keen-apps">#{Jason.encode!(manifest, escape: :html_safe)}</script>\n)

  defp preloads(ctx, manifest) do
    Enum.reduce(manifest, ctx, fn {name, url}, ctx ->
      Context.put_asset(ctx, "keen-app:#{name}", :head, preload(url))
    end)
  end

  defp preload(url),
    do: ~s(<link rel="modulepreload" href="#{HTML.esc(url)}"#{crossorigin(url)} />\n)

  # Mirrors the library: an absolute http(s) bundle is cross-origin, a rooted path is not.
  defp crossorigin("http://" <> _rest), do: ~s( crossorigin="anonymous")
  defp crossorigin("https://" <> _rest), do: ~s( crossorigin="anonymous")
  defp crossorigin(_url), do: ""

  # A real Phoenix page calls mountStatic() from its own app.js, so nothing is emitted
  # unless a standalone page explicitly configures a runtime module.
  defp bootstrap(ctx) do
    case config(:runtime, nil) do
      nil ->
        ctx

      runtime ->
        Context.put_asset(ctx, "keen-runtime", :footer, """
        <script type="module">
        import { mountStatic } from "#{runtime}";
        mountStatic();
        </script>
        """)
    end
  end

  defp url(_name, src, _ctx) when is_binary(src) and src != "", do: src

  defp url(name, _src, ctx) do
    case Context.meta(ctx)["apps"] do
      %{^name => url} when is_binary(url) -> url
      _ -> "#{config(:base_path, @default_base_path)}/#{name}/main.mjs"
    end
  end

  defp config(key, default),
    do: :keen_docs |> Application.get_env(__MODULE__, []) |> Keyword.get(key, default)
end
