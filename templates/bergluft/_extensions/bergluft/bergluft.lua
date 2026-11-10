-- Bergluft: slide backgrounds and trail elements for the bergluft-revealjs format.
--
--   bergluft-title: contours | landscape    (front matter)
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

local NIGHT = "#1E2B25"
local PAPER = "#F4F2EC"
local DECOS = {
  ["bottom-mountains-1"] = true, ["bottom-mountains-2"] = true,
  ["bottom-trees-1"] = true, ["bottom-trees-2"] = true, ["right-tree-1"] = true,
}

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

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function base64(data)
  return ((data:gsub(".", function(c)
    local byte, bits = c:byte(), ""
    for i = 8, 1, -1 do bits = bits .. (byte % 2 ^ i - byte % 2 ^ (i - 1) > 0 and "1" or "0") end
    return bits
  end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(bits)
    if #bits < 6 then return "" end
    local n = 0
    for i = 1, 6 do n = n + (bits:sub(i, i) == "1" and 2 ^ (6 - i) or 0) end
    return B64:sub(n + 1, n + 1)
  end) .. ({ "", "==", "=" })[#data % 3 + 1])
end

-- a background as a data URI; `drop` moves the drawing down by that many px
local function background(name, drop)
  local svg = read_svg(name)
  if drop then
    svg = svg:gsub('viewBox="0 0 1050 700"', 'viewBox="0 ' .. -drop .. ' 1050 700"', 1)
  end
  return "data:image/svg+xml;base64," .. base64(svg)
end

local function has_class(el, cls)
  for _, c in ipairs(el.classes) do
    if c == cls then return true end
  end
  return false
end

local function remove_class(el, cls)
  local keep = pandoc.List()
  for _, c in ipairs(el.classes) do
    if c ~= cls then keep:insert(c) end
  end
  el.classes = keep
end

local function has_background(el)
  for k, _ in pairs(el.attributes) do
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

local function html(inlines)
  local out = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "html")
  return (out:gsub("%s+$", ""))
end

local function escape_attr(s)
  return (s:gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"))
end

local function fmt(n)
  return string.format("%.1f", n)
end

-- the inlines of a list item, and whether it is marked [..]{.here}
local function item_content(item)
  local inlines = pandoc.List()
  for _, block in ipairs(item) do
    if block.t == "Plain" or block.t == "Para" then
      inlines:extend(block.content)
    end
  end
  local here = false
  if #inlines == 1 and inlines[1].t == "Span" and has_class(inlines[1], "here") then
    here = true
    inlines = inlines[1].content
  end
  return inlines, here
end

local function first_list(div)
  for _, block in ipairs(div.content) do
    if block.t == "BulletList" or block.t == "OrderedList" then return block end
  end
end

local uid = 0
local function next_id()
  uid = uid + 1
  return "berg" .. uid
end

-- ---------------------------------------------------------------- .trail: elevation profile

local profile_points
local function profile_y(x)
  if not profile_points then
    profile_points = {}
    local svg = read_svg("profile")
    local d = svg:match('<path d="([^"]*)" fill="none" stroke="#2F4A3C" stroke%-width="1.6"')
    for px, py in d:gmatch("(-?[%d.]+),(-?[%d.]+)") do
      table.insert(profile_points, { tonumber(px), tonumber(py) })
    end
  end
  local pts = profile_points
  for i = 2, #pts do
    if pts[i][1] >= x then
      local a, b = pts[i - 1], pts[i]
      local t = (x - a[1]) / math.max(b[1] - a[1], 1e-6)
      return a[2] + t * (b[2] - a[2])
    end
  end
  return pts[#pts][2]
end

local function stop_label(i, n)
  return i == n and "Summit" or string.format("%02d", i)
end

local function trail_profile(list)
  local n = #list.content
  local art, items = {}, {}
  local svg = read_svg("profile"):gsub("<svg ", '<svg aria-hidden="true" ', 1)
  table.insert(art, svg)
  local marks = { '<svg aria-hidden="true" viewBox="0 0 1050 700">' }
  for i, item in ipairs(list.content) do
    local inlines, here = item_content(item)
    local x = n > 1 and 110 + (i - 1) * 840 / (n - 1) or 525
    local y = profile_y(x)
    table.insert(marks, string.format(
      '<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="#8A928B" stroke-dasharray="2 3"/>',
      fmt(x), fmt(y - 20), fmt(x), fmt(y - 7)))
    if i == n then
      table.insert(marks, string.format('<path d="M%s,%s L%s,%s L%s,%s Z" fill="#A84C27"/>',
        fmt(x), fmt(y - 9), fmt(x + 8), fmt(y + 5), fmt(x - 8), fmt(y + 5)))
    else
      table.insert(marks, string.format(
        '<circle cx="%s" cy="%s" r="5" fill="%s" stroke="#2F4A3C" stroke-width="1.6"/>',
        fmt(x), fmt(y), here and "#A84C27" or PAPER))
    end
    local cls = (i == n and "summit" or "") .. (here and " here" or "")
    table.insert(items, string.format('<li class="%s" data-label="%s" style="left:%spx;top:%spx">%s</li>',
      cls, stop_label(i, n), fmt(x - 70), fmt(y - 84), html(inlines)))
  end
  table.insert(marks, "</svg>")
  return '<div class="trail-art">' .. table.concat(art) .. table.concat(marks, "") .. "</div>\n"
    .. '<ol class="trail-stops">' .. table.concat(items) .. "</ol>"
end

-- ---------------------------------------------------------------- .trail-profile: top-down route on a contour map

local ROUTE = {
  { 150, 610 },
  { 182, 602, 307, 582, 340, 559 },
  { 373, 536, 307, 503, 348, 475 },
  { 389, 447, 550, 418, 586, 391 },
  { 622, 364, 536, 339, 562, 314 },
  { 588, 289, 710, 252, 740, 240 },
}

local route_samples
local function route_at(t)
  if not route_samples then
    route_samples = { { ROUTE[1][1], ROUTE[1][2], 0 } }
    local x0, y0 = ROUTE[1][1], ROUTE[1][2]
    for s = 2, #ROUTE do
      local c = ROUTE[s]
      for k = 1, 60 do
        local u = k / 60
        local v = 1 - u
        local x = v ^ 3 * x0 + 3 * v ^ 2 * u * c[1] + 3 * v * u ^ 2 * c[3] + u ^ 3 * c[5]
        local y = v ^ 3 * y0 + 3 * v ^ 2 * u * c[2] + 3 * v * u ^ 2 * c[4] + u ^ 3 * c[6]
        local prev = route_samples[#route_samples]
        table.insert(route_samples, { x, y, prev[3] + math.sqrt((x - prev[1]) ^ 2 + (y - prev[2]) ^ 2) })
      end
      x0, y0 = c[5], c[6]
    end
  end
  local total = route_samples[#route_samples][3]
  local want = math.max(0, math.min(1, t)) * total
  for i = 2, #route_samples do
    local a, b = route_samples[i - 1], route_samples[i]
    if b[3] >= want then
      local f = (want - a[3]) / math.max(b[3] - a[3], 1e-6)
      return a[1] + f * (b[1] - a[1]), a[2] + f * (b[2] - a[2]), total
    end
  end
  local last = route_samples[#route_samples]
  return last[1], last[2], total
end

local function route_path()
  local parts = { "M" .. ROUTE[1][1] .. "," .. ROUTE[1][2] }
  for s = 2, #ROUTE do
    local c = ROUTE[s]
    table.insert(parts, string.format("C%d,%d %d,%d %d,%d", c[1], c[2], c[3], c[4], c[5], c[6]))
  end
  return table.concat(parts, " ")
end

local function trail_map(list)
  local n = #list.content
  local id = next_id()
  local map = read_svg("map")
    :gsub('id="g"', 'id="' .. id .. '-g"'):gsub("url%(#g%)", "url(#" .. id .. "-g)")
    :gsub('id="m"', 'id="' .. id .. '-m"'):gsub("url%(#m%)", "url(#" .. id .. "-m)")
    :gsub("<svg ", '<svg aria-hidden="true" ', 1)
  local d = route_path()
  local marks = {
    '<svg aria-hidden="true" viewBox="0 0 1050 700">',
    '<path d="' .. d .. '" fill="none" stroke="#F4F2EC" stroke-width="7" stroke-linecap="round"/>',
    '<path d="' .. d .. '" fill="none" stroke="#A84C27" stroke-width="2.2" stroke-dasharray="7 5" stroke-linecap="round"/>',
  }
  local items = {}
  for i, item in ipairs(list.content) do
    local inlines, here = item_content(item)
    local t = n > 1 and (i - 1) / (n - 1) or 1
    local x, y, total = route_at(t)
    -- put the label on the side the route does not run to
    local step = 30 / total
    local bx = route_at(t - step)
    local ax = route_at(t + step)
    local left = i > 1 and i < n and ((bx + ax) / 2 > x)
    local cls = (i == n and "summit" or "") .. (here and " here" or "") .. (left and " left" or "")
    local lx, ly
    if i == n then
      table.insert(marks, string.format('<path d="M%s,%s L%s,%s L%s,%s Z" fill="#1E2621"/>',
        fmt(x), fmt(y - 10), fmt(x + 9), fmt(y + 6), fmt(x - 9), fmt(y + 6)))
      lx, ly = x + 20, y - 18
    else
      table.insert(marks, string.format(
        '<circle cx="%s" cy="%s" r="%s" fill="%s" stroke="#1E2621" stroke-width="1.6"/>',
        fmt(x), fmt(y), i == 1 and 6 or 5, here and "#A84C27" or PAPER))
      lx, ly = left and x - 16 or x + 16, i == 1 and y + 4 or y - 14
    end
    table.insert(items, string.format('<li class="%s" data-label="%s" style="left:%spx;top:%spx">%s</li>',
      cls, stop_label(i, n), fmt(lx), fmt(ly), html(inlines)))
  end
  table.insert(marks, "</svg>")
  local north = '<div class="trail-north" aria-hidden="true"><span>N</span>'
    .. '<svg width="10" height="26" viewBox="0 0 10 26"><path d="M5,0 L10,26 L5,20 L0,26 Z" fill="#1E2621"/></svg></div>'
  return '<div class="trail-art">' .. map .. table.concat(marks) .. "</div>\n"
    .. north .. '<ol class="trail-stops map">' .. table.concat(items) .. "</ol>"
end

-- ---------------------------------------------------------------- .signpost

local function signpost(div, list)
  local small = has_class(div, "small")
  local signs = {}
  for i, item in ipairs(list.content) do
    local inlines = item_content(item)
    local href, label, time, level = "#", inlines, nil, nil
    if #inlines == 1 and inlines[1].t == "Link" then
      local link = inlines[1]
      href, label = link.target, link.content
      time, level = link.attributes.time, link.attributes.level
    end
    local side = i % 2 == 1 and "to-right" or "to-left"
    local timespan = ""
    if time or level then
      timespan = string.format('<span class="signpost-time %s">%s</span>',
        escape_attr(level or ""), escape_attr(time or ""))
    end
    table.insert(signs, string.format(
      '<a class="signpost-sign %s" href="%s"><span class="signpost-board"><span class="signpost-label">%s</span>%s</span></a>',
      side, escape_attr(href), html(label), timespan))
  end
  local classes = "signpost" .. (small and " small" or " full")
  return string.format('<nav class="%s" aria-label="Trail signs"><span class="signpost-pole" aria-hidden="true"></span>%s</nav>',
    classes, table.concat(signs))
end

-- ---------------------------------------------------------------- inline and block elements

local function Div(div)
  if has_class(div, "trail") or has_class(div, "trail-profile") then
    local list = first_list(div)
    if not list then return nil end
    local out = has_class(div, "trail") and trail_profile(list) or trail_map(list)
    return pandoc.RawBlock("html", out)
  end
  if has_class(div, "signpost") then
    local list = first_list(div)
    if not list then return nil end
    return pandoc.RawBlock("html", signpost(div, list))
  end
  if has_class(div, "fieldnote") then
    div.attributes["data-label"] = div.attributes.label or "Field note"
    div.attributes.label = nil
    return pandoc.Div({ div }, pandoc.Attr("", { "fieldnote-wrap" }))
  end
end

local function Span(span)
  if has_class(span, "sign") then
    return pandoc.Span({ span }, pandoc.Attr("", { "sign-wrap" }))
  end
end

-- ---------------------------------------------------------------- slides

local function big_sign(header)
  remove_class(header, "signpost")
  remove_class(header, "big")
  header.classes:insert("bergluft-bigsign")
  local time, level = header.attributes.time, header.attributes.level
  header.attributes.time, header.attributes.level = nil, nil
  local content = pandoc.List({ pandoc.Span(header.content, pandoc.Attr("", { "bigsign-title" })) })
  if time or level then
    content:insert(pandoc.Span(time and pandoc.Inlines(time) or {}, pandoc.Attr("", { "bigsign-time", level or "" })))
  end
  header.content = content
  if not has_background(header) then header.attributes["background-color"] = PAPER end
  return { header, pandoc.RawBlock("html", '<div class="bigsign-pole" aria-hidden="true"></div>') }
end

local section_count = 0

local function slide_header(header)
  if header.level == 1 then
    section_count = section_count + 1
    local style = header.attributes.style
    header.attributes.style = string.format("--berg-section: '%02d';", section_count) .. (style and (" " .. style) or "")
    if has_class(header, "signpost") and has_class(header, "big") then
      return big_sign(header)
    end
    header.classes:insert("bergluft-section")
    set_background(header, background("contours-dark"), NIGHT)
    return header
  end
  if has_class(header, "summit") then
    remove_class(header, "summit")
    header.classes:insert("bergluft-summit")
    set_background(header, background("summit", 70), NIGHT)
    return header
  end
  for _, c in ipairs(header.classes) do
    if DECOS[c] then
      set_background(header, background(c), PAPER)
      return header
    end
  end
  return header
end

local function Meta(meta)
  local style = meta["bergluft-title"] and pandoc.utils.stringify(meta["bergluft-title"]) or "contours"
  if style ~= "landscape" then style = "contours" end
  local attrs = meta["title-slide-attributes"]
  if type(attrs) ~= "table" or attrs.t == "MetaList" then attrs = {} end
  attrs["data-bergluft-title"] = style
  local custom = false
  for k, _ in pairs(attrs) do
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

local function Pandoc(doc)
  local blocks = pandoc.List()
  for _, block in ipairs(doc.blocks) do
    if block.t == "Header" and block.level <= 2 then
      local result = slide_header(block)
      if result.t then blocks:insert(result) else blocks:extend(result) end
    else
      blocks:insert(block)
    end
  end
  doc.blocks = blocks
  return doc
end

return {
  { Meta = Meta },
  { Div = Div, Span = Span },
  { Pandoc = Pandoc },
}
