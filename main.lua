--- @since 25.12.29
--- Page-fit PDF previewer with pane-matched resolution.
---
--- Yazi's built-in PDF previewer rasterizes at a fixed 150 DPI, so on a large
--- preview pane the page lands far below the pane's device pixels and Yazi —
--- which never upscales — draws it much smaller than it could. This previewer
--- always shows the whole page, rasterized at exactly the width needed for that:
--- the pane width when the page is wider than the pane, otherwise the
--- height-limited width. Never wider than necessary (a page taller than the pane
--- would otherwise be zoomed until only a slice is visible, at ~3x the pixels),
--- never narrower (so it stays pixel-accurate instead of relying on upscaling).
--- `J`/`K` step through pages.
local M = {}

local PDFINFO = "pdfinfo"
local PDFTOPPM = "pdftoppm"

-- Pane geometry is quantized to these cell steps to limit re-renders.
local QW, QH = 8, 4
-- Cell size in device pixels, used only if the terminal doesn't report one.
local FALLBACK_CW, FALLBACK_CH = 8, 16
-- Bumped whenever the rendering policy changes, so a cache entry produced by an
-- older version is never mistaken for a current one.
local CACHE_TAG = "v2"

local memo = { url = nil, vw = 0, vh = 0, pages = nil }

local function cell_size()
	local cw, ch = rt.term.cell_size()
	cw, ch = tonumber(cw), tonumber(ch)
	if cw and ch and cw > 1 and ch > 1 then
		return cw, ch
	end
	return FALLBACK_CW, FALLBACK_CH
end

local function view(area)
	local w = math.max(QW, math.floor(area.w / QW + 0.5) * QW)
	local h = math.max(QH, math.floor(area.h / QH + 0.5) * QH)
	local cw, ch = cell_size()
	-- rt.term.cell_size() reports floats and pdftoppm rejects non-integer args.
	return {
		w = w,
		h = h,
		vw = math.floor(w * cw + 0.5),
		vh = math.floor(h * ch + 0.5),
	}
end

-- Page aspect ratios, straight from the PDF (no rendering needed).
local function layout(job, v)
	local url = tostring(job.file.url)
	if memo.url == url and memo.vw == v.vw and memo.vh == v.vh then
		return memo.pages
	end

	local pages = {}
	local out = Command(PDFINFO):arg({ "-f", "1", "-l", "10000", tostring(job.file.path) }):output()
	if out and out.status.success then
		for wp, hp in out.stdout:gmatch("Page%s+%d+ size:%s+([%d.]+) x ([%d.]+) pts") do
			local w_pt, h_pt = tonumber(wp), tonumber(hp)
			if w_pt and h_pt and w_pt > 0 and h_pt > 0 then
				pages[#pages + 1] = { w = w_pt, h = h_pt }
			end
		end
	end

	memo = { url = url, vw = v.vw, vh = v.vh, pages = pages }
	return pages
end

-- Width in pixels that shows the whole page, i.e. the most that is ever useful:
-- the pane width for a page wider than the pane, the height-limited width
-- otherwise. Zero when the page size is unknown (= let pdftoppm decide).
local function fit_width(page, v)
	if not page then
		return 0
	end
	return math.floor(math.min(v.vw, v.vh * page.w / page.h) + 0.5)
end

local function cache_url(job, v, skip)
	local c = ya.file_cache({ file = job.file, skip = skip })
	return c and Url(string.format("%s-%s-w%d-h%d.jpg", tostring(c), CACHE_TAG, v.w, v.h))
end

local function preload(job)
	local v = view(job.area)
	local pages = layout(job, v)
	local page = pages[job.skip + 1]
	local dst = cache_url(job, v, job.skip)
	if not dst then
		return true
	end
	if fs.cha(dst) then
		return true
	end

	-- pdftoppm appends the extension itself, so strip ours (the parentheses keep
	-- gsub from expanding its second return value into the argument list).
	local prefix = (tostring(dst):gsub("%.jpg$", ""))
	local tmp = prefix .. ".tmp." .. tostring(math.random(1, 2147483647))
	local w = fit_width(page, v)
	local args = {
		"-f", tostring(job.skip + 1),
		"-l", tostring(job.skip + 1),
		"-singlefile",
		"-jpeg", "-jpegopt", "quality=" .. rt.preview.image_quality,
	}
	if w > 0 then
		args[#args + 1] = "-scale-to-x"
		args[#args + 1] = tostring(w)
		args[#args + 1] = "-scale-to-y"
		args[#args + 1] = "-1"
	end
	args[#args + 1] = tostring(job.file.path)
	-- Render to a unique prefix and rename afterwards: pdftoppm writes straight to
	-- its output path, so a reader could otherwise open a half-written page.
	args[#args + 1] = tmp

	-- stylua: ignore
	local out = Command(PDFTOPPM):arg(args):env("LC_ALL", "C"):output()
	if not out then
		return true, Err("Failed to start `pdftoppm`")
	elseif not out.status.success then
		return true, Err("Failed to convert PDF to image: %s", out.stderr)
	end

	-- pdftoppm appends ".jpg" itself; publish the finished page atomically.
	if not fs.rename(Url(tmp .. ".jpg"), dst) then
		fs.remove("file", Url(tmp .. ".jpg"))
		return true, Err("Failed to publish page")
	end
	return true
end

function M:peek(job)
	local v = view(job.area)
	local src = cache_url(job, v, job.skip)
	if not src then
		return
	end

	local ok, err = preload(job)
	if not ok or err then
		return ya.preview_widget(job, err)
	end

	ya.image_show(src, job.area)
	ya.preview_widget(job, nil)
end

local preview_skip = ya.sync(function(state)
	return cx.active.preview.skip
end)

function M:seek(job)
	local step = ya.clamp(-1, job.units, 1)
	ya.emit("peek", { math.max(0, preview_skip() + step), only_if = job.file.url })
end

return M
