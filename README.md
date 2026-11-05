# pdf-fit.yazi

Page-fit PDF previewer for [Yazi](https://github.com/sxyazi/yazi) that rasterizes each page at the preview pane's real resolution.

## Why

Yazi's built-in `pdf` previewer renders each page at a fixed 150 DPI and lets Yazi fit it into the pane. Yazi never upscales a preview, so on a large or HiDPI pane the page is drawn far smaller than the space available — on a 6K display a page can occupy a fifth of the column and the rest stays empty.

`pdf-fit` keeps the same "whole page at a time" behaviour, but asks `pdftoppm` for exactly the pixels the pane can show: the widest rendering that still fits the entire page vertically, computed from the page's own aspect ratio and the terminal's cell size.

## Requirements

- `pdftoppm` and `pdfinfo` (poppler: `brew install poppler`, `apt install poppler-utils`)
- Yazi 26.9.1 or newer (tested; uses `rt.term.cell_size()` and atomic `fs.rename`)

## Install

```sh
ya pkg add juanlopez4691/pdf-fit.yazi
```

```toml
# ~/.config/yazi/yazi.toml
[[plugin.prepend_previewers]]
url = "*.pdf"
run = "pdf-fit"
```

`prepend_` so it wins over the built-in PDF previewer.

## Behaviour

| key | action |
| --- | --- |
| `J` / `K` | next / previous page |

- Raster width = `min(pane width, pane height × page width / page height)`, so a page taller than the pane is height-limited and a landscape page is width-limited — the whole page is always visible.
- Pages are cached per file, page and pane geometry (`…-v2-w120-h40.jpg` in Yazi's preview cache), so only resizes trigger a re-render (~50 ms per page).
- Page files are written to a temporary name and renamed into place, so a preview never renders a half-written JPEG.

## Caveats

- Yazi caps preview rasters at `preview.max_width`/`max_height`. If a very large pane shows the page narrower than it could be, raise them (`4096` is a good start) — this plugin can only produce pixels up to that ceiling.
- Pages with unusual geometry (very wide slides) are shown in full, which can look small in a tall pane; that is the fit-the-whole-page contract, by design.
- Only the page's own margins are shown; there is no zoom or intra-page scrolling.

## License

MIT
