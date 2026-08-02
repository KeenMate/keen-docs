---
title: Form Integration
description: Submit multiselect values with native HTML forms — live, from real markdown.
nav:
  section: Features
  order: 5
uses: "@keenmate/web-multiselect"
---

To integrate the multiselect with HTML forms you set the `name` attribute. The
component keeps a hidden input in sync as the selection changes.

:::callout{type=info title="Setup"}
This whole page is **one markdown file**. The demo below is a *real*
`<web-multiselect>` loaded from the CDN — selecting items runs live JS and prints
the value the server would receive.
:::

## FI01 — JSON Format (default)

:::showcase{title="FI01 JSON Format (Default)" subtitle="Hidden input with a JSON array value"}

:::col{title="Demo"}
```html demo
<web-multiselect name="languages" value-format="json"
  data-options="JavaScript,TypeScript,Python,Go,Rust,Elixir"></web-multiselect>
```
```js run
el.addEventListener('change', (e) => out({ selected: e.detail, value: el.value }));
```
:::

:::col{title="Controls"}
Select items to see how the hidden input updates. On submit, the server parses one field:

```js
app.post('/submit', (req, res) => {
  const langs = JSON.parse(req.body.languages);
});
```
:::

:::col{title="Description"}
Creates a **single** hidden input containing a JSON array. Best for modern
backends that expect JSON.

```html
<input type="hidden" name="languages" value='["js","ts"]'>
```
:::

:::

## Big demos want more room

Some components (trees, grids) need most of the width. Layout is a generic
primitive — this is an **80/20** split, impossible with a 12-column grid:

:::columns{cols="80/20"}

:::col{title="Demo"}
```html demo
<web-multiselect value-format="csv"
  data-options="Prague,Vienna,Berlin,Warsaw,Budapest,Bratislava,Ljubljana"></web-multiselect>
```
:::

:::col{title="Notes"}
Typeahead search, keyboard nav, CSV value format — all from attributes.
:::

:::

And the full source of a demo can span the whole page underneath it:

```svelte example
<script>
  import '@keenmate/web-multiselect';
</script>

<web-multiselect
  value-format="csv"
  data-options="Prague,Vienna,Berlin" />
```

## Value formats

| `value-format` | Hidden input value | Use when |
| --- | --- | --- |
| `json` | `["js","ts"]` | modern JSON backends |
| `csv`  | `js,ts`        | classic form posts |
| `array`| `js` + `ts` (multiple inputs) | PHP-style `name[]` |

:::card{title="Tip"}
`:::col` is a plain labelled column (no box). `:::card` — like this one — is the
boxed variant, and it can sit **inside** a column.
:::
