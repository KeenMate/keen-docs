defmodule KeenDocs.Markup do
  @moduledoc """
  keen-docs' `KeenMarkdown.Profile` — how the engine's generic vocabulary renders here.

  keen-docs keeps the engine's default BEM `km-*` classes for most blocks, but overrides the
  **layout** slots (Level-2 structure) so content columns render on `@keenmate/pure-css`'s native
  `pa-grid` — `:::columns` → `.pa-row`, each `:::col` → `.pa-col-<width>` — instead of the engine's
  standalone CSS-grid. That gets the grid's built-in gutters, container-query responsiveness and
  mobile auto-stacking for free, and shares one grid vocabulary with pure-admin pages.

  The column's width comes from the `:col` assigns' `width` (`{part, total}`, supplied by
  `KeenMarkdown.Extensions.Layout` from the `cols=` spec). It maps to an exact `pa-col` fraction
  when the ratio reduces to one pa-grid ships (`80/20` → `.pa-col-4-5`/`.pa-col-1-5`, thirds →
  `.pa-col-1-3`), otherwise to the nearest 5% column (`.pa-col-75`). A standalone `:::col` (no
  width) is an auto/equal `.pa-col`.
  """

  alias KeenMarkdown.{HTML, Profile}

  # Fraction column classes pa-grid ships (see _pa-grid.scss $grid-columns-fractions).
  @fractions ~w(1-2 1-3 2-3 1-4 3-4 1-5 2-5 3-5 4-5 1-6 5-6 1-12 5-12 7-12 11-12)

  @doc "The active profile (referenced by `config :keen_markdown, :profile, KeenDocs.Markup`)."
  @spec profile() :: Profile.t()
  def profile do
    %Profile{
      components: %{
        columns: &columns/2,
        col: &col/2,
        span: &span/2
      }
    }
  end

  # :::columns / :::showcase grid -> a pa-grid row; each column sizes itself.
  defp columns(a, _cls), do: [~s(<div class="pa-row">), a.body, "</div>"]

  # Non-column children span the full row.
  defp span(a, _cls), do: [~s(<div class="pa-col-100">), a.body, "</div>"]

  # :::col -> a sized pa-col carrying the (optionally accented) label + body. The label/body keep
  # the engine's km-col__* classes (styled in keendocs.css); only the wrapper becomes a pa-col.
  defp col(a, cls) do
    [
      ~s(<div class="#{pa_col(a.width)}">),
      col_header(a.title, a.accent, cls),
      ~s(<div class="#{cls.(:col_body)}">),
      a.body,
      "</div></div>"
    ]
  end

  defp col_header(nil, _accent, _cls), do: ""

  defp col_header(title, accent, cls) do
    base = cls.(:col_header)
    mod = if accent, do: " #{base}--#{HTML.esc(accent)}", else: ""
    ~s(<div class="#{base}#{mod}">#{HTML.esc(title)}</div>)
  end

  # {part, total} -> a pa-col class: an exact fraction when the reduced ratio is one pa-grid ships,
  # else the nearest 5% column. nil -> auto/equal column.
  defp pa_col(nil), do: "pa-col"

  defp pa_col({part, total}) when is_integer(part) and is_integer(total) and total > 0 do
    g = Integer.gcd(part, total)
    frac = "#{div(part, g)}-#{div(total, g)}"

    if frac in @fractions do
      "pa-col-#{frac}"
    else
      pct = (part * 100 / total) |> Kernel./(5) |> round() |> Kernel.*(5) |> max(5) |> min(100)
      "pa-col-#{pct}"
    end
  end

  defp pa_col(_), do: "pa-col"
end
