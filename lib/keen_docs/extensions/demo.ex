defmodule KeenDocs.Extensions.Demo do
  @moduledoc """
  The **live** fence roles that a docs site needs: `demo` and `run`.

  Demo-ness lives on the fence, never on the layout (DESIGN.md §5):

    * ` ```html demo ` — mounts the markup for real and shows its source.
    * ` ```js run ` — executes against the *preceding* demo, with `el` bound to the
      demo's first element and `out/1` printing into the demo's output pane.

  The generic ` ```lang example ` role (highlighted, copyable source that is not
  executed) lives in `KeenMarkdown.Extensions.Example` — any content site wants it,
  not just docs. Only the live-mounting roles are docs-specific and stay here.

  A `run` block is paired with its demo through the render context, and its script is
  contributed to the page **footer** rather than inlined mid-body, so the element it
  drives is guaranteed to exist by the time the module runs.

  Demo ids come from a per-document counter, so the same document always renders to
  the same bytes — see `KeenMarkdown.Context`.
  """

  use KeenMarkdown.Extension

  alias KeenMarkdown.{Context, Renderer}

  @impl true
  def fences, do: ~w(demo run)

  @impl true
  def render({:fence, lang, flags, code}, ctx) do
    cond do
      "demo" in flags -> demo(lang, code, ctx)
      "run" in flags -> run(code, ctx)
      true -> {[~s(<div class="kd-code">), Renderer.highlight(code, lang, ctx), "</div>"], ctx}
    end
  end

  defp demo(lang, code, ctx) do
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

  defp run(code, ctx) do
    case Context.last_demo(ctx) do
      nil ->
        # Previously this silently bound to whatever demo was rendered last — including
        # one from an earlier document. Surface it instead of guessing.
        {~s(<div class="kd-demo-orphan">A <code>js run</code> block needs a <code>demo</code> fence above it.</div>),
         ctx}

      id ->
        {"", Context.put_footer(ctx, script(id, code))}
    end
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
