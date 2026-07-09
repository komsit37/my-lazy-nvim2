-- code-explainer — companion module for the `nvim-code-explainer` Claude skill.
--
-- Each present() opens its own TABPAGE with an independent walkthrough:
--   * a per-window LOCATION LIST (so each tab's list is truly independent;
--     the quickfix list is global to nvim and can't be per-tab),
--   * per-tab diagnostic namespaces driving inline virt_lines + gutter signs,
--   * a floating progress HUD (tab-local in nvim),
--   * an ASCII/image diagram side split,
--   * per-tab state keyed by tabpage handle, so ]w/[w/detail/clear act on the
--     walkthrough in the CURRENT tab.
--
-- The Claude skill's walkthrough.py prefers this module when present and falls
-- back to a single-tab quickfix payload otherwise, so the skill stays portable.
--
-- Tour keymaps (active while any walkthrough exists):
--   ]w / [w  next/prev (current tab)   <leader>cd  detail (LazyVim float)
--   :CodeExplain next|prev|detail|clear|clearall

local M = {}

M.tours = {}        -- [tabpage_handle] = tour
M._saved = {}       -- saved pre-existing maps for ]w/[w
M._keys_on = false

local function wrap(text, w)
  local out = {}
  for _, para in ipairs(vim.split(text or "", "\n")) do
    if para == "" then
      table.insert(out, "")
    else
      local line = ""
      for word in para:gmatch("%S+") do
        if #line == 0 then line = word
        elseif #line + 1 + #word <= w then line = line .. " " .. word
        else table.insert(out, line); line = word end
      end
      if #line > 0 then table.insert(out, line) end
    end
  end
  return out
end

local function resolve(it, root)
  local p = it.file
  if root and not p:match("^/") then p = root .. "/" .. p end
  return p
end

local function render_annotations(tour, data)
  local inline = data.inline or "virt_lines"
  local width = math.max(40, math.min(100, vim.o.columns - 12))
  local items = data.items or {}
  local n = #items
  local by_buf = {}
  for i, it in ipairs(items) do
    local bufnr = vim.fn.bufadd(resolve(it, tour.root))
    vim.fn.bufload(bufnr)
    tour.bufs[bufnr] = true
    local tag = string.format("[%d/%d] ", i, n)

    by_buf[bufnr] = by_buf[bufnr] or {}
    local msg = tag .. (it.label or "")
    if it.detail and #it.detail > 0 then msg = msg .. "\n\n" .. it.detail end
    table.insert(by_buf[bufnr], {
      lnum = (it.line or 1) - 1, col = (it.col or 1) - 1,
      message = msg, severity = vim.diagnostic.severity.INFO, source = "walkthrough",
    })

    if inline == "virt_lines" then
      local vlines = {}
      for _, l in ipairs(wrap("▸ " .. tag .. (it.label or ""), width)) do
        table.insert(vlines, { { l, "DiagnosticVirtualTextInfo" } })
      end
      if data.inline_detail and it.detail then
        for _, l in ipairs(wrap(it.detail, width - 2)) do
          table.insert(vlines, { { "  " .. l, "Comment" } })
        end
      end
      pcall(vim.api.nvim_buf_set_extmark, bufnr, tour.vlns, (it.line or 1) - 1, 0,
        { virt_lines = vlines, virt_lines_above = (data.inline_above ~= false) })
    end
  end
  vim.diagnostic.config({
    virtual_text = (inline == "eol") and { prefix = "▸", spacing = 2, source = false } or false,
    signs = true, underline = false, update_in_insert = false,
  }, tour.ns)
  for bufnr, ds in pairs(by_buf) do
    vim.diagnostic.set(tour.ns, bufnr, ds)
  end
end

local HELP_LINES = {
  " Code explainer  —  keys",
  " ─────────────────────────",
  " ]w / [w    next / prev step",
  " <leader>cd show full detail",
  " <CR>       jump (in list below)",
  "",
  " :CodeExplain clear     close this tab",
  " :CodeExplain clear_all close all tours",
}

local function make_scratch(name, lines, ft)
  local buf = vim.api.nvim_create_buf(false, true)
  pcall(vim.api.nvim_buf_set_name, buf, name)
  vim.bo[buf].buftype = "nofile"
  if lines then vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines) end
  if ft then vim.bo[buf].filetype = ft end
  return buf
end

local function open_help(tour, win)
  local buf = make_scratch("walkthrough://help/" .. tour.tab, HELP_LINES, "markdown")
  vim.bo[buf].modifiable = false
  tour.help_buf = buf
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_height(win, #HELP_LINES)
  vim.wo[win].winfixheight = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = false
  vim.wo[win].signcolumn = "no"
end

local function open_side(tour, data)
  local has_img = data.diagram_image and #data.diagram_image > 0
  local has_ascii = data.diagram and #data.diagram > 0

  vim.cmd("botright vsplit")
  local top = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(top, math.min(64, math.floor(vim.o.columns * 0.42)))

  if has_img then
    local buf = make_scratch("walkthrough://image/" .. tour.tab, nil, nil)
    tour.side_buf = buf
    vim.api.nvim_win_set_buf(top, buf)
    local ok_img, image = pcall(require, "image")
    if ok_img then
      local img = image.from_file(data.diagram_image, { window = top, buffer = buf, with_virtual_padding = true })
      if img then img:render(); tour.image = img end
    else
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(string.format("# Diagram\n\n![](%s)\n", data.diagram_image), "\n"))
      vim.bo[buf].filetype = "markdown"
      pcall(function() require("snacks").image.attach(buf) end)
    end
  elseif has_ascii then
    local buf = make_scratch("walkthrough://diagram/" .. tour.tab, vim.split(data.diagram, "\n"), "markdown")
    vim.bo[buf].modifiable = false
    tour.side_buf = buf
    vim.api.nvim_win_set_buf(top, buf)
  end

  -- Help panel: bottom split of the right column when there's a diagram above,
  -- otherwise the right column itself.
  if has_img or has_ascii then
    vim.api.nvim_set_current_win(top)
    vim.cmd("belowright split")
    open_help(tour, vim.api.nvim_get_current_win())
  else
    open_help(tour, top)
  end
  vim.api.nvim_set_current_win(tour.code_win)
end

local function build_loclist(tour, data)
  local items = data.items or {}
  local n = #items
  local loc = {}
  for i, it in ipairs(items) do
    loc[i] = {
      filename = resolve(it, tour.root),
      lnum = it.line or 1, col = it.col or 1,
      text = string.format("[%d/%d] %s", i, n, it.label or ""),
    }
  end
  vim.fn.setloclist(tour.code_win, {}, " ", { title = data.title or "Code explainer", items = loc })
end

local function hud(tour)
  if #tour.items == 0 then return end
  local it = tour.items[tour.idx]
  local label = (it and (it.label or "")) or ""
  local line = string.format(" %d/%d  %s ", tour.idx, #tour.items, label)
  local cwin = vim.api.nvim_win_is_valid(tour.code_win) and tour.code_win or 0
  local w = math.max(10, math.min(#line, vim.api.nvim_win_get_width(cwin) - 2))
  if not (tour.hud_buf and vim.api.nvim_buf_is_valid(tour.hud_buf)) then
    tour.hud_buf = vim.api.nvim_create_buf(false, true)
  end
  vim.api.nvim_buf_set_lines(tour.hud_buf, 0, -1, false, { line })
  -- Anchor to the CODE window's top-right (not the editor's), so the HUD stays
  -- over the code column and never covers the diagram/help side split.
  local cfg = {
    relative = "win", win = cwin, anchor = "NE", row = 0,
    col = vim.api.nvim_win_get_width(cwin),
    width = w, height = 1, style = "minimal", focusable = false, zindex = 200, border = "rounded",
  }
  if tour.hud_win and vim.api.nvim_win_is_valid(tour.hud_win) then
    vim.api.nvim_win_set_config(tour.hud_win, cfg)
  else
    tour.hud_win = vim.api.nvim_open_win(tour.hud_buf, false, cfg)
    pcall(function() vim.wo[tour.hud_win].winhl = "Normal:DiagnosticInfo,FloatBorder:DiagnosticInfo" end)
  end
end

-- ── keymaps (global, ref-counted; act on the current tab's tour) ──────────────
local TOUR_KEYS = {
  { "]w", function() M.next() end, "code-explainer: next" },
  { "[w", function() M.prev() end, "code-explainer: prev" },
}

local function set_keymaps()
  if M._keys_on then return end
  M._saved = {}
  for _, k in ipairs(TOUR_KEYS) do
    M._saved[k[1]] = vim.fn.maparg(k[1], "n", false, true)
    vim.keymap.set("n", k[1], k[2], { desc = k[3], silent = true })
  end
  M._keys_on = true
end

local function clear_keymaps()
  if not M._keys_on then return end
  for lhs, saved in pairs(M._saved) do
    pcall(vim.keymap.del, "n", lhs)
    if saved and not vim.tbl_isempty(saved) then pcall(vim.fn.mapset, "n", false, saved) end
  end
  M._saved = {}
  M._keys_on = false
end

-- ── public navigation ─────────────────────────────────────────────────────────
function M.current()
  return M.tours[vim.api.nvim_get_current_tabpage()]
end

function M.jump(i)
  local tour = M.current()
  if not tour or #tour.items == 0 then return end
  if not vim.api.nvim_win_is_valid(tour.code_win) then return end
  i = math.max(1, math.min(#tour.items, i))
  tour.idx = i
  vim.api.nvim_set_current_win(tour.code_win)
  pcall(vim.cmd, "ll " .. i)
  pcall(vim.cmd, "normal! zz")
  hud(tour)
end

-- The location list tracks its own current entry; reading it keeps next/prev in
-- sync after a direct <CR> jump (or :lnext) instead of resuming from a stale idx.
local function cur_idx(tour)
  local ok, info = pcall(vim.fn.getloclist, tour.code_win, { idx = 0 })
  if ok and info and (info.idx or 0) > 0 then return info.idx end
  return tour.idx
end

function M.next() local t = M.current(); if t then M.jump(cur_idx(t) + 1) end end
function M.prev() local t = M.current(); if t then M.jump(cur_idx(t) - 1) end end

-- Driven from the CLI (`walkthrough.py goto N`): if the current tab has no tour,
-- switch to a tour's tab first, then jump. Optionally target a tour by title.
function M.focus_goto(i, title)
  if not M.current() then
    for tab, tour in pairs(M.tours) do
      if (not title or tour.title == title) and vim.api.nvim_tabpage_is_valid(tab) then
        vim.api.nvim_set_current_tabpage(tab); break
      end
    end
  end
  M.jump(i)
end

function M.detail()
  local tour = M.current()
  if not tour then return end
  vim.diagnostic.open_float(nil, { scope = "line", namespace = tour.ns, border = "rounded" })
end

-- ── lifecycle ──────────────────────────────────────────────────────────────────
local teardown  -- forward declaration (present() replaces an existing tour via it)

function M.present(data)
  local title = data.title or "Code explainer"

  -- Idempotent by default: a present() whose title matches an existing tour
  -- REPLACES it in its own tab instead of stacking a new tab. `new_tab = true`
  -- forces a fresh tab.
  local tab
  if data.new_tab ~= true then
    for t, tour in pairs(M.tours) do
      if tour.title == title and vim.api.nvim_tabpage_is_valid(t) then tab = t; break end
    end
  end
  if tab then
    vim.api.nvim_set_current_tabpage(tab)
    local old = M.tours[tab]
    if old and vim.api.nvim_win_is_valid(old.code_win) then
      vim.api.nvim_set_current_win(old.code_win)
    end
    teardown(old, false)        -- clear old content, keep the tab
    pcall(vim.cmd, "only")      -- collapse back to a single window
  else
    vim.cmd("tabnew")
    tab = vim.api.nvim_get_current_tabpage()
  end

  local tour = {
    tab = tab,
    title = title,
    items = data.items or {},
    root = data.root,
    idx = 0,
    ns = vim.api.nvim_create_namespace("claude_walkthrough_" .. tab),
    vlns = vim.api.nvim_create_namespace("claude_walkthrough_vl_" .. tab),
    code_win = vim.api.nvim_get_current_win(),
    bufs = {},
    hud_win = nil, hud_buf = nil, image = nil,
  }
  M.tours[tab] = tour
  pcall(vim.api.nvim_tabpage_set_var, tab, "walkthrough", true)

  render_annotations(tour, data)
  open_side(tour, data)
  build_loclist(tour, data)
  vim.api.nvim_win_call(tour.code_win, function() pcall(vim.cmd, "lopen") end)
  -- In a loclist window each line == its entry index, so <CR>/o jump to that
  -- step via M.jump, which syncs tour.idx + the HUD (the default <CR> wouldn't).
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tour.tab)) do
    local info = vim.fn.getwininfo(w)[1]
    if info and info.loclist == 1 then
      local lbuf = vim.api.nvim_win_get_buf(w)
      local function jump() M.jump(vim.fn.line(".")) end
      vim.keymap.set("n", "<CR>", jump, { buffer = lbuf, silent = true, desc = "code-explainer: jump to step" })
      vim.keymap.set("n", "o", jump, { buffer = lbuf, silent = true })
    end
  end
  vim.api.nvim_set_current_win(tour.code_win)
  set_keymaps()
  M.jump(1)
  return #tour.items
end

teardown = function(tour, close_tab)
  if not tour then return end
  pcall(vim.diagnostic.reset, tour.ns)
  for buf in pairs(tour.bufs) do
    if vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_clear_namespace, buf, tour.vlns, 0, -1)
    end
  end
  if tour.image then pcall(function() tour.image:clear() end) end
  if tour.hud_win and vim.api.nvim_win_is_valid(tour.hud_win) then
    pcall(vim.api.nvim_win_close, tour.hud_win, true)
  end
  for _, b in ipairs({ tour.side_buf, tour.help_buf }) do
    if b and vim.api.nvim_buf_is_valid(b) then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
  M.tours[tour.tab] = nil
  if close_tab and vim.api.nvim_tabpage_is_valid(tour.tab)
      and #vim.api.nvim_list_tabpages() > 1 then
    -- tour.tab is a tabpage HANDLE; :tabclose wants the 1-based NUMBER.
    local nr = vim.api.nvim_tabpage_get_number(tour.tab)
    pcall(function() vim.cmd(nr .. "tabclose") end)
  end
  if vim.tbl_isempty(M.tours) then clear_keymaps() end
end

-- Clear the walkthrough in the CURRENT tab (and close that tab).
function M.clear()
  teardown(M.current(), true)
end

-- Nuke every walkthrough in every tab. Stateless: also sweeps orphaned artifacts
-- (e.g. tours whose in-memory tracking was lost across a module reload), so it
-- always returns nvim to a clean state regardless of M.tours.
function M.clear_all()
  local tours = {}
  for _, tour in pairs(M.tours) do tours[#tours + 1] = tour end
  for _, tour in ipairs(tours) do teardown(tour, true) end

  -- reset every per-tab walkthrough diagnostic namespace
  for name, ns in pairs(vim.api.nvim_get_namespaces()) do
    if name:match("^claude_walkthrough") then
      pcall(vim.diagnostic.reset, ns)
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(b) then
          pcall(vim.api.nvim_buf_clear_namespace, b, ns, 0, -1)
        end
      end
    end
  end

  -- close any walkthrough tab: identified by the tabpage var (survives module
  -- reloads / lost tracking) OR by a lingering walkthrough:// buffer
  local function is_wt_tab(tab)
    local ok, v = pcall(vim.api.nvim_tabpage_get_var, tab, "walkthrough")
    if ok and v then return true end
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):match("walkthrough://") then
        return true
      end
    end
    return false
  end
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    if vim.api.nvim_tabpage_is_valid(tab) and is_wt_tab(tab) and #vim.api.nvim_list_tabpages() > 1 then
      pcall(function() vim.cmd(vim.api.nvim_tabpage_get_number(tab) .. "tabclose") end)
    end
  end
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_get_name(b):match("walkthrough://") then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
  M.tours = {}
  clear_keymaps()
end

vim.api.nvim_create_user_command("CodeExplain", function(o)
  local sub = (o.args ~= "" and o.args) or "next"
  if M[sub] then M[sub]() else vim.notify("code-explainer: unknown subcommand " .. sub, vim.log.levels.WARN) end
end, {
  nargs = "?",
  complete = function() return { "next", "prev", "detail", "clear", "clear_all" } end,
})

return M
