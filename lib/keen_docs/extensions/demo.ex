defmodule KeenDocs.Extensions.Demo do
  @moduledoc """
  The **live** directives a docs site needs: `:::demo` and `:::run`.

  Liveness is an explicit directive, never a flag smuggled onto a code fence — the same
  markup renders live in a `:::demo` or as plain source in a `:::code`. Both are raw-body
  directives, so the markup/script inside is captured verbatim.

    * `:::demo{lang=html}` — mounts the markup for real (into `.kd-demo-live`) and shows
      its highlighted source below. `lang` defaults to `html`.
    * `:::run{lang=js}` — executes against the *preceding* demo, with `el` bound to the
      demo's first element and `out/1` printing into the demo's output pane. Its script is
      contributed to the page **footer**, so the element it drives already exists when it
      runs.

  Plain code display (`:::code`, ```` ```lang ````) is generic and lives in
  `KeenMarkdown.Extensions.Code`; only the live-mounting directives are docs-specific and
  stay here.

  Demo ids come from a per-document counter, so the same document always renders to the
  same bytes — see `KeenMarkdown.Context`.
  """

  use KeenMarkdown.Extension

  alias KeenMarkdown.{Context, Renderer}

  @impl true
  def directives, do: ~w(demo run)

  @impl true
  def raw_directives, do: ~w(demo run)

  @impl true
  def render({:directive, "demo", attrs, children}, ctx) do
    code = raw_text(children)
    lang = attrs["lang"] || "html"
    {id, ctx} = Context.next_demo_id(ctx)

    {[
       ~s(<div class="kd-demo" id="#{id}">),
       ~s(<div class="kd-demo-live">),
       code,
       "</div>",
       ~s(<details class="kd-demo-source"><summary>source</summary>),
       Renderer.highlight(code, lang, ctx),
       "</details></div>"
     ], ctx}
  end

  def render({:directive, "run", _attrs, children}, ctx) do
    code = raw_text(children)

    case Context.last_demo(ctx) do
      nil ->
        # Surface a stray run rather than silently binding to some earlier demo.
        {~s(<div class="kd-demo-orphan">A <code>:::run</code> block needs a <code>:::demo</code> above it.</div>),
         ctx}

      id ->
        {"", Context.put_footer(ctx, script(id, code))}
    end
  end

  # The raw body arrives as a single `{:raw, text}` child; trim only surrounding blank
  # lines so indentation inside the markup/script is preserved.
  defp raw_text(children) do
    children
    |> Enum.map_join("\n", fn
      {:raw, text} -> text
      {:markdown, text} -> text
      _ -> ""
    end)
    |> String.trim("\n")
  end

  defp script(id, code) do
    """
    <script type="module">
    (function () {
      const root = document.getElementById("#{id}");
      if (!root) return;
      const el = root.querySelector(".kd-demo-live > *") || root;
      const out = (v) => {
        let o = root.querySelector(".kd-out");
        if (!o) { o = document.createElement("pre"); o.className = "kd-out"; root.appendChild(o); }
        o.textContent = typeof v === "string" ? v : JSON.stringify(v, null, 2);
      };
    #{code}
    })();
    </script>
    """
  end
end
