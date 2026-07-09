-- colorfilter: a theme-agnostic colorscheme post-processor.
--
-- Runs on every ColorScheme so it layers over ANY theme:
--   * deep_black  - force large flat background areas to pure #000000 (ideal for
--                   mini-LED / local-dimming monitors so dimming zones fully cut).
--   * gamma       - foreground lightness gamma lift l^(1/g); brightens dim colors
--                   (comments, etc.) for contrast without washing bright ones out.
--   * saturation  - foreground saturation multiply; makes colors more vivid.
--   * brightness  - linear foreground lightness gain; lifts the light end too
--                   (drifts toward white the brighter a color already is).
--
-- All values are percents where 100 = identity/off. State lives in vim.g.colorfilter_*.

local M = {}

local BLACK = "#000000"

-- Only the dominant flat regions get blacked; floats/pmenu/statusline are left to
-- the theme so those UI elements stay visually distinct from the editor.
local black_groups = {
  "Normal",
  "NormalNC",
  "SignColumn",
  "LineNr",
  "LineNrAbove",
  "LineNrBelow",
  "CursorLineNr",
  "FoldColumn",
  "EndOfBuffer",
  "MsgArea",
  "NeoTreeNormal",
  "NeoTreeNormalNC",
  "NeoTreeEndOfBuffer",
}

local defaults = {
  enabled = true, -- master switch: off = raw theme (all params bypassed)
  deep_black = true,
  gamma = 120,
  saturation = 115,
  brightness = 100,
}

-- Numeric knobs: var name, clamp range, and default (used by nudge/reset).
local fields = {
  gamma = { var = "colorfilter_gamma", min = 50, max = 250 },
  saturation = { var = "colorfilter_saturation", min = 0, max = 300 },
  brightness = { var = "colorfilter_brightness", min = 50, max = 200 },
}

-- ── HSL helpers ────────────────────────────────────────────────────────────
local function rgb_to_hsl(r, g, b)
  r, g, b = r / 255, g / 255, b / 255
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local h, s, l = 0, 0, (max + min) / 2
  local d = max - min
  if d > 0 then
    s = l > 0.5 and d / (2 - max - min) or d / (max + min)
    if max == r then
      h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then
      h = (b - r) / d + 2
    else
      h = (r - g) / d + 4
    end
    h = h / 6
  end
  return h, s, l
end

local function hue(p, q, t)
  if t < 0 then
    t = t + 1
  end
  if t > 1 then
    t = t - 1
  end
  if t < 1 / 6 then
    return p + (q - p) * 6 * t
  end
  if t < 1 / 2 then
    return q
  end
  if t < 2 / 3 then
    return p + (q - p) * (2 / 3 - t) * 6
  end
  return p
end

local function hsl_to_rgb(h, s, l)
  local r, g, b
  if s == 0 then
    r, g, b = l, l, l
  else
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    r, g, b = hue(p, q, h + 1 / 3), hue(p, q, h), hue(p, q, h - 1 / 3)
  end
  return math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5)
end

local function transform(fg, gfactor, sfactor, bfactor)
  local r, g, b = math.floor(fg / 65536) % 256, math.floor(fg / 256) % 256, fg % 256
  local h, s, l = rgb_to_hsl(r, g, b)
  l = l ^ (1 / gfactor) -- gamma lift (contrast)
  l = math.max(0, math.min(1, l * bfactor)) -- linear brightness gain
  s = math.max(0, math.min(1, s * sfactor)) -- saturation
  r, g, b = hsl_to_rgb(h, s, l)
  return r * 65536 + g * 256 + b
end

-- ── Apply / refresh ────────────────────────────────────────────────────────
-- Repaint highlights for the current theme. Called from the ColorScheme autocmd.
function M.apply()
  if not vim.g.colorfilter_enabled then
    return -- master switch off: leave the theme untouched
  end
  local gfactor = (vim.g.colorfilter_gamma or 100) / 100
  local sfactor = (vim.g.colorfilter_saturation or 100) / 100
  local bfactor = (vim.g.colorfilter_brightness or 100) / 100
  if not (gfactor == 1.0 and sfactor == 1.0 and bfactor == 1.0) then
    for name, hl in pairs(vim.api.nvim_get_hl(0, {})) do
      if hl.fg and not hl.link then
        hl.fg = transform(hl.fg, gfactor, sfactor, bfactor)
        pcall(vim.api.nvim_set_hl, 0, name, hl)
      end
    end
  end
  if vim.g.colorfilter_deep_black then
    for _, name in ipairs(black_groups) do
      local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
      if ok then
        hl.bg = BLACK
        pcall(vim.api.nvim_set_hl, 0, name, hl)
      end
    end
  end
end

-- Reload the theme so transforms recompute from original colors (no compounding);
-- the ColorScheme autocmd then re-runs M.apply.
local function refresh()
  if vim.g.colors_name then
    vim.cmd.colorscheme(vim.g.colors_name)
  else
    M.apply()
  end
end

-- ── Public controls ────────────────────────────────────────────────────────
function M.set(field, value)
  local f = fields[field]
  if not f or not value then
    return
  end
  vim.g[f.var] = math.max(f.min, math.min(f.max, value))
  refresh()
  M.status()
end

function M.nudge(field, delta)
  local f = fields[field]
  if f then
    M.set(field, (vim.g[f.var] or defaults[field]) + delta)
  end
end

function M.toggle_black()
  vim.g.colorfilter_deep_black = not vim.g.colorfilter_deep_black
  refresh()
  M.status()
end

function M.toggle()
  vim.g.colorfilter_enabled = not vim.g.colorfilter_enabled
  refresh()
  M.status()
end

function M.reset()
  for k, v in pairs(defaults) do
    vim.g["colorfilter_" .. k] = v
  end
  refresh()
  M.status()
end

function M.status()
  local msg = table.concat({
    ("enabled     %s"):format(vim.g.colorfilter_enabled and "on" or "off"),
    ("gamma       %3d%%"):format(vim.g.colorfilter_gamma or 100),
    ("saturation  %3d%%"):format(vim.g.colorfilter_saturation or 100),
    ("brightness  %3d%%"):format(vim.g.colorfilter_brightness or 100),
    ("deep black  %s"):format(vim.g.colorfilter_deep_black and "on" or "off"),
  }, "\n")
  vim.notify(msg, vim.log.levels.INFO, { title = "colorfilter" })
end

-- ── Setup ──────────────────────────────────────────────────────────────────
function M.setup()
  for k, v in pairs(defaults) do
    if vim.g["colorfilter_" .. k] == nil then
      vim.g["colorfilter_" .. k] = v
    end
  end

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("colorfilter", { clear = true }),
    callback = M.apply,
  })

  local subs = { "toggle", "on", "off", "gamma", "saturation", "brightness", "black", "reset", "status" }
  vim.api.nvim_create_user_command("ColorFilter", function(o)
    local sub, arg = o.fargs[1], o.fargs[2]
    if sub == nil or sub == "status" then
      M.status()
    elseif sub == "toggle" then
      M.toggle()
    elseif sub == "on" or sub == "off" then
      vim.g.colorfilter_enabled = sub == "on"
      refresh()
      M.status()
    elseif sub == "reset" then
      M.reset()
    elseif sub == "black" then
      if arg == "on" or arg == "off" then
        vim.g.colorfilter_deep_black = arg == "on"
        refresh()
        M.status()
      else
        M.toggle_black()
      end
    elseif fields[sub] then
      if arg then
        M.set(sub, tonumber(arg))
      else
        M.status()
      end
    else
      vim.notify("colorfilter: unknown subcommand '" .. sub .. "'", vim.log.levels.WARN)
    end
  end, {
    nargs = "*",
    complete = function()
      return subs
    end,
    desc = "colorfilter: toggle|on|off | gamma|saturation|brightness <pct> | black [on|off] | reset | status",
  })

  local function map(lhs, fn, desc)
    vim.keymap.set("n", lhs, fn, { desc = desc })
  end
  map("<leader>uvt", M.toggle, "Toggle colorfilter (all)")
  map("<leader>uvd", M.toggle_black, "Deep black toggle")
  map("<leader>uvg", function()
    M.nudge("gamma", 5)
  end, "Gamma +")
  map("<leader>uvG", function()
    M.nudge("gamma", -5)
  end, "Gamma -")
  map("<leader>uvs", function()
    M.nudge("saturation", 5)
  end, "Saturation +")
  map("<leader>uvS", function()
    M.nudge("saturation", -5)
  end, "Saturation -")
  map("<leader>uvb", function()
    M.nudge("brightness", 5)
  end, "Brightness +")
  map("<leader>uvB", function()
    M.nudge("brightness", -5)
  end, "Brightness -")
  map("<leader>uvr", M.reset, "Reset colorfilter")
  map("<leader>uvo", M.status, "Show colorfilter status")

  M.apply()
end

return M
