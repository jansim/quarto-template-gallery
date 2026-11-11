-- Bergluft: slide backgrounds and trail elements for the bergluft-revealjs format.
--
--   bergluft-title: contours | landscape        (front matter)
--   # Section                                   dark contour map, numbered
--   # Results {.signpost .big time=… level=…}   the heading as a big trail sign
--   ## Title {.summit}                          dark closing slide with ridgelines
--   ## Title {.bottom-mountains-1}              pale silhouettes behind a slide
--     (also .bottom-mountains-2, .bottom-trees-1, .bottom-trees-2, .right-tree-1)
--   ::: {.trail} / ::: {.trail-profile}         a list as an elevation profile / map route
--   ::: {.signpost} / ::: {.signpost .small}    links as yellow trail signs
--   ::: {.fieldnote}                            a tilted sheet of paper
--   [text]{.sign} / [text]{.sign .back}         inline trail signs

if not quarto.doc.is_format("revealjs") then
  return {}
end

local NIGHT, PAPER, INK, ALPENGLOW = "#1E2B25", "#F4F2EC", "#1E2621", "#A84C27"
local DECOS = pandoc.List({ "bottom-mountains-1", "bottom-mountains-2", "bottom-trees-1", "bottom-trees-2", "right-tree-1" })
local SVG = '<svg aria-hidden="true" viewBox="0 0 1050 700">'

local dir = PANDOC_SCRIPT_FILE:match("^(.*[/\\])") or "./"
local svg_cache = {}
local function read_svg(name)
  if not svg_cache[name] then
    local f = assert(io.open(dir .. "svg/" .. name .. ".svg", "rb"))
    svg_cache[name] = f:read("a")
    f:close()
  end
  return svg_cache[name]
end

-- a background as a data URI; `drop` moves the drawing down by that many px
local function background(name, drop)
  local svg = read_svg(name)
  if drop then svg = svg:gsub('viewBox="0 0 1050 700"', 'viewBox="0 ' .. -drop .. ' 1050 700"', 1) end
  return "data:image/svg+xml;base64," .. quarto.base64.encode(svg)
end

local function has_background(el)
  for k in pairs(el.attributes) do
    if k:match("^background") or k:match("^data%-background") then return true end
  end
  return false
end

local function set_background(el, image, color)
  if has_background(el) then return end
  el.attributes["background-color"] = color
  el.attributes["background-image"] = image
  el.attributes["background-size"] = "cover"
  el.attributes["background-position"] = "center"
end

local function swap_class(el, old, new)
  el.classes = el.classes:filter(function(c) return c ~= old end)
  if new then el.classes:insert(new) end
end

local function html(inlines)
  return (pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "html"):gsub("%s+$", ""))
end

local function escape_attr(s)
  return (s:gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"))
end

-- the inlines of a list item, and whether it is marked [..]{.here}
local function item_content(item)
  local inlines = pandoc.List()
  for _, block in ipairs(item) do
    if block.t == "Plain" or block.t == "Para" then inlines:extend(block.content) end
  end
  if #inlines == 1 and inlines[1].t == "Span" and inlines[1].classes:includes("here") then
    return inlines[1].content, true
  end
  return inlines, false
end

local function first_list(div)
  for _, block in ipairs(div.content) do
    if block.t == "BulletList" or block.t == "OrderedList" then return block end
  end
end

-- one stop label; the last stop is the summit
local function stop(i, n, here, extra, x, y, inlines)
  local cls = (i == n and "summit" or "") .. (here and " here" or "") .. (extra or "")
  return string.format('<li class="%s" data-label="%s" style="left:%.1fpx;top:%.1fpx">%s</li>',
    cls, i == n and "Summit" or string.format("%02d", i), x, y, html(inlines))
end

-- ---------------------------------------------------------------- .trail: elevation profile

local profile
local function profile_y(x)
  if not profile then
    profile = {}
    local d = read_svg("profile"):match('<path d="([^"]*)" fill="none" stroke="#2F4A3C" stroke%-width="1.6"')
    for px, py in d:gmatch("(-?[%d.]+),(-?[%d.]+)") do table.insert(profile, { tonumber(px), tonumber(py) }) end
  end
  for i = 2, #profile do
    local a, b = profile[i - 1], profile[i]
    if b[1] >= x then return a[2] + (x - a[1]) / math.max(b[1] - a[1], 1e-6) * (b[2] - a[2]) end
  end
  return profile[#profile][2]
end

local function trail_profile(list)
  local n, marks, items = #list.content, { SVG }, {}
  for i, item in ipairs(list.content) do
    local inlines, here = item_content(item)
    local x = n > 1 and 110 + (i - 1) * 840 / (n - 1) or 525
    local y = profile_y(x)
    table.insert(marks, string.format('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#8A928B" stroke-dasharray="2 3"/>',
      x, y - 20, x, y - 7))
    if i == n then
      table.insert(marks, string.format('<path d="M%.1f,%.1f L%.1f,%.1f L%.1f,%.1f Z" fill="%s"/>',
        x, y - 9, x + 8, y + 5, x - 8, y + 5, ALPENGLOW))
    else
      table.insert(marks, string.format('<circle cx="%.1f" cy="%.1f" r="5" fill="%s" stroke="#2F4A3C" stroke-width="1.6"/>',
        x, y, here and ALPENGLOW or PAPER))
    end
    table.insert(items, stop(i, n, here, nil, x - 70, y - 84, inlines))
  end
  local art = read_svg("profile"):gsub("<svg ", '<svg aria-hidden="true" ', 1)
  return '<div class="trail-art">' .. art .. table.concat(marks) .. "</svg></div>\n"
    .. '<ol class="trail-stops">' .. table.concat(items) .. "</ol>"
end

-- ---------------------------------------------------------------- .trail-profile: top-down route on a contour map

local ROUTE = "M150,610 C182,602 307,582 340,559 C373,536 307,503 348,475 C389,447 550,418 586,391 C622,364 536,339 562,314 C588,289 710,252 740,240"

-- points along the route, each with its distance from the start
local route
local function route_at(t)
  if not route then
    local nums = {}
    for v in ROUTE:gmatch("%d+") do table.insert(nums, tonumber(v)) end
    route = { { nums[1], nums[2], 0 } }
    for s = 3, #nums, 6 do
      local x0, y0 = nums[s - 2], nums[s - 1]
      for k = 1, 60 do
        local u, v = k / 60, 1 - k / 60
        local x = v ^ 3 * x0 + 3 * v ^ 2 * u * nums[s] + 3 * v * u ^ 2 * nums[s + 2] + u ^ 3 * nums[s + 4]
        local y = v ^ 3 * y0 + 3 * v ^ 2 * u * nums[s + 1] + 3 * v * u ^ 2 * nums[s + 3] + u ^ 3 * nums[s + 5]
        local p = route[#route]
        table.insert(route, { x, y, p[3] + math.sqrt((x - p[1]) ^ 2 + (y - p[2]) ^ 2) })
      end
    end
  end
  local total = route[#route][3]
  local want = math.max(0, math.min(1, t)) * total
  for i = 2, #route do
    local a, b = route[i - 1], route[i]
    if b[3] >= want then
      local f = (want - a[3]) / math.max(b[3] - a[3], 1e-6)
      return a[1] + f * (b[1] - a[1]), a[2] + f * (b[2] - a[2]), total
    end
  end
  return route[#route][1], route[#route][2], total
end

local map_count = 0
local function trail_map(list)
  map_count = map_count + 1
  local id = "berg" .. map_count
  local map = read_svg("map"):gsub('id="(%a)"', 'id="' .. id .. '-%1"'):gsub("url%(#(%a)%)", "url(#" .. id .. "-%1)")
    :gsub("<svg ", '<svg aria-hidden="true" ', 1)
  local n, items = #list.content, {}
  local marks = {
    SVG,
    '<path d="' .. ROUTE .. '" fill="none" stroke="' .. PAPER .. '" stroke-width="7" stroke-linecap="round"/>',
    '<path d="' .. ROUTE .. '" fill="none" stroke="' .. ALPENGLOW .. '" stroke-width="2.2" stroke-dasharray="7 5" stroke-linecap="round"/>',
  }
  for i, item in ipairs(list.content) do
    local inlines, here = item_content(item)
    local t = n > 1 and (i - 1) / (n - 1) or 1
    local x, y, total = route_at(t)
    -- put the label on the side the route does not run to
    local before, after = route_at(t - 30 / total), route_at(t + 30 / total)
    local left = i > 1 and i < n and (before + after) / 2 > x
    if i == n then
      table.insert(marks, string.format('<path d="M%.1f,%.1f L%.1f,%.1f L%.1f,%.1f Z" fill="%s"/>',
        x, y - 10, x + 9, y + 6, x - 9, y + 6, INK))
      table.insert(items, stop(i, n, here, nil, x + 20, y - 18, inlines))
    else
      table.insert(marks, string.format('<circle cx="%.1f" cy="%.1f" r="%d" fill="%s" stroke="%s" stroke-width="1.6"/>',
        x, y, i == 1 and 6 or 5, here and ALPENGLOW or PAPER, INK))
      table.insert(items, stop(i, n, here, left and " left" or nil, left and x - 16 or x + 16, i == 1 and y + 4 or y - 14, inlines))
    end
  end
  local north = '<div class="trail-north" aria-hidden="true"><span>N</span>'
    .. '<svg width="10" height="26" viewBox="0 0 10 26"><path d="M5,0 L10,26 L5,20 L0,26 Z" fill="' .. INK .. '"/></svg></div>'
  return '<div class="trail-art">' .. map .. table.concat(marks) .. "</svg></div>\n"
    .. north .. '<ol class="trail-stops map">' .. table.concat(items) .. "</ol>"
end

-- ---------------------------------------------------------------- .signpost

local function signpost(div, list)
  local signs = {}
  for i, item in ipairs(list.content) do
    local inlines = item_content(item)
    local href, label, time, level = "#", inlines, nil, nil
    if #inlines == 1 and inlines[1].t == "Link" then
      local link = inlines[1]
      href, label, time, level = link.target, link.content, link.attributes.time, link.attributes.level
    end
    local timespan = (time or level)
      and string.format('<span class="signpost-time %s">%s</span>', escape_attr(level or ""), escape_attr(time or ""))
      or ""
    table.insert(signs, string.format(
      '<a class="signpost-sign %s" href="%s"><span class="signpost-board"><span class="signpost-label">%s</span>%s</span></a>',
      i % 2 == 1 and "to-right" or "to-left", escape_attr(href), html(label), timespan))
  end
  return string.format('<nav class="signpost %s" aria-label="Trail signs"><span class="signpost-pole" aria-hidden="true"></span>%s</nav>',
    div.classes:includes("small") and "small" or "full", table.concat(signs))
end

local function Div(div)
  local list = first_list(div)
  if list and div.classes:includes("trail") then return pandoc.RawBlock("html", trail_profile(list)) end
  if list and div.classes:includes("trail-profile") then return pandoc.RawBlock("html", trail_map(list)) end
  if list and div.classes:includes("signpost") then return pandoc.RawBlock("html", signpost(div, list)) end
  if div.classes:includes("fieldnote") then
    div.attributes["data-label"] = div.attributes.label or "Field note"
    div.attributes.label = nil
    return pandoc.Div({ div }, pandoc.Attr("", { "fieldnote-wrap" }))
  end
end

local function Span(span)
  if span.classes:includes("sign") then return pandoc.Span({ span }, pandoc.Attr("", { "sign-wrap" })) end
end

-- ---------------------------------------------------------------- slides

local section_count = 0

local function Header(header)
  if header.level == 1 then
    section_count = section_count + 1
    local style = header.attributes.style
    header.attributes.style = string.format("--berg-section: '%02d';", section_count) .. (style and (" " .. style) or "")
    if not (header.classes:includes("signpost") and header.classes:includes("big")) then
      header.classes:insert("bergluft-section")
      set_background(header, background("contours-dark"), NIGHT)
      return header
    end
    -- the heading as a big sign, with an optional time and difficulty
    swap_class(header, "signpost")
    swap_class(header, "big", "bergluft-bigsign")
    local time, level = header.attributes.time, header.attributes.level
    header.attributes.time, header.attributes.level = nil, nil
    header.content = pandoc.List({ pandoc.Span(header.content, pandoc.Attr("", { "bigsign-title" })) })
    if time or level then
      header.content:insert(pandoc.Span(time and pandoc.Inlines(time) or {}, pandoc.Attr("", { "bigsign-time", level or "" })))
    end
    if not has_background(header) then header.attributes["background-color"] = PAPER end
    return { header, pandoc.RawBlock("html", '<div class="bigsign-pole" aria-hidden="true"></div>') }
  end
  if header.level == 2 and header.classes:includes("summit") then
    swap_class(header, "summit", "bergluft-summit")
    set_background(header, background("summit", 70), NIGHT)
  elseif header.level == 2 then
    local deco = DECOS:find_if(function(c) return header.classes:includes(c) end)
    if deco then set_background(header, background(deco), PAPER) end
  end
  return header
end

local function Meta(meta)
  local style = meta["bergluft-title"] and pandoc.utils.stringify(meta["bergluft-title"]) == "landscape" and "landscape" or "contours"
  local attrs = meta["title-slide-attributes"]
  if type(attrs) ~= "table" or attrs.t == "MetaList" then attrs = {} end
  attrs["data-bergluft-title"] = style
  local custom = false
  for k in pairs(attrs) do
    if tostring(k):match("^data%-background") then custom = true end
  end
  if not custom then
    attrs["data-background-color"] = PAPER
    attrs["data-background-image"] = style == "landscape" and background("landscape", 40) or background("contours")
    attrs["data-background-size"] = "cover"
    attrs["data-background-position"] = "center"
  end
  meta["title-slide-attributes"] = pandoc.MetaMap(attrs)
  return meta
end

-- only top-level headings make slides
local function Pandoc(doc)
  local blocks = pandoc.List()
  for _, block in ipairs(doc.blocks) do
    local result = block.t == "Header" and Header(block) or block
    if result.t then blocks:insert(result) else blocks:extend(result) end
  end
  doc.blocks = blocks
  return doc
end

return {
  { Meta = Meta },
  { Div = Div, Span = Span },
  { Pandoc = Pandoc },
}
