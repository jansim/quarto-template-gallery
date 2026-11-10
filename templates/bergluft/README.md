# Bergluft

A quiet outdoors theme for Quarto reveal.js: survey-paper ground, pine ink,
contour maps and ridgelines, and yellow alpine trail signs. Headings are set in
Instrument Sans, code and labels in IBM Plex Mono.

## Use it

Copy this folder (it holds the extension in `_extensions/bergluft/` and an
example deck in `template.qmd`) and render:

```bash
quarto render template.qmd
```

To use the format in another project, copy `_extensions/bergluft/` next to your
document and set:

```yaml
format:
  bergluft-revealjs:
    footer: "Your talk"
    bergluft-title: contours   # or: landscape
    venue: "Your venue"        # shown above the title in the landscape style
```

## What it adds

| Markdown | Result |
|----------|--------|
| `bergluft-title: contours` / `landscape` | Title slide on a contour map, or centred above layered ridgelines |
| `# Section` | Numbered section slide on a dark contour map |
| `# Results {.signpost .big time="20 min" level="moderate"}` | The section heading as a big trail sign |
| `::: {.trail}` around a list | Overview as an elevation profile, the last item as the summit |
| `::: {.trail-profile}` around a list | Overview as a dashed route on a contour map |
| `[Results]{.here}` in either list | Marks the current stop |
| `::: {.signpost}` around a list of links | Yellow trail signs on a pole; add `{time="5 min" level="easy"}` to a link |
| `::: {.signpost .small}` | A smaller signpost that sits in a column |
| `[Results]{.sign}`, `[Methods]{.sign .back}` | Inline signs pointing ahead or back |
| `[hard]{.difficult}`, `.moderate`, `.easy` | Trail-grade dots (black, red, blue) |
| `[one phrase]{.blaze}` | A soft marker under one key phrase |
| `::: {.fieldnote}` | A slightly tilted sheet of lined paper (`label="…"` changes its heading) |
| `::: {.callout-grid}` | Lays callouts (or anything) out in three columns |
| `## Thank you {.summit}` | Dark closing slide with ridgelines |
| `## Title {.bottom-mountains-1}` | Pale silhouettes behind a slide; also `.bottom-mountains-2`, `.bottom-trees-1`, `.bottom-trees-2`, `.right-tree-1` |

Callouts are drawn as a coloured rule with a line icon: note in lake blue, tip
in moss, warning in ochre, important in pine, caution in red. In numbered
incremental lists, upcoming items stay faintly visible and the current one's
number turns alpenglow.

The colours are SCSS variables (`$berg-paper`, `$berg-pine`, `$berg-alpenglow`,
…) in `_extensions/bergluft/bergluft.scss`, so a theme file of your own can
override them.
