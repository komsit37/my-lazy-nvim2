-- gitdiff — switch gitsigns' diff base between review modes and render the
-- diff inline (deleted lines + word-level diff) around every hunk.
--
--   index       current diff  — working tree vs index (staged + unstaged)
--   commit      last commit   — vs HEAD~1
--   mergebase   branch diff   — vs `git merge-base <main> HEAD` (your changes off main)
--   <revision>  ref diff      — vs any branch / tag / commit (anything else is treated
--                               as a literal git revision, e.g. "origin/develop", a SHA)
--
-- Re-selecting the active mode turns it back off (plain working view). `mode`
-- state is module-global because gitsigns' base is global to all buffers.
--
-- Used by:
--   * keymaps  <leader>gd1/2/3/4/5       (config/keymaps.lua)
--   * command  :GitDiffMode {mode|rev|off} (config/keymaps.lua)
--   * AI       code-explainer honors a tour's `diff_base` field via set_mode()
--   * Trouble  plugins/trouble.lua wires trouble_hunk_formatter into its qf modes

local M = {}

M.mode = nil

local LABEL = { index = "current diff", commit = "last commit", mergebase = "merge base" }

local function gitsigns()
  local ok, g = pcall(require, "gitsigns")
  if not ok then
    vim.notify("gitdiff: gitsigns not available", vim.log.levels.ERROR)
    return nil
  end
  return g
end

local function gs_config()
  return require("gitsigns.config").config
end

-- First main-branch ref that exists, preferring the remote's default.
local function main_ref()
  for _, c in ipairs({ "origin/HEAD", "origin/main", "origin/master", "main", "master" }) do
    vim.fn.systemlist({ "git", "rev-parse", "--verify", "--quiet", c })
    if vim.v.shell_error == 0 then return c end
  end
  return "HEAD"
end

local function merge_base()
  local out = vim.fn.systemlist({ "git", "merge-base", "HEAD", main_ref() })
  if vim.v.shell_error == 0 and out[1] and out[1] ~= "" then return out[1] end
  return nil
end

-- True if `rev` names an existing commit-ish (branch, tag, or SHA).
local function valid_rev(rev)
  vim.fn.systemlist({ "git", "rev-parse", "--verify", "--quiet", rev .. "^{commit}" })
  return vim.v.shell_error == 0
end

-- Base revision to hand gitsigns for each named preset (nil = its default = index).
-- Any OTHER mode string is treated as a literal git revision to diff against —
-- see set_mode.
local BASE = {
  index = function() return nil end,
  commit = function() return "HEAD~1" end,
  mergebase = merge_base,
}

-- Set the base + inline-diff config, then (once gitsigns has recomputed hunks
-- against the new base, via change_base's async callback) fill the quickfix with
-- one entry per changed hunk as a review worklist. Populating before the callback
-- would read stale/empty hunks.
local function apply(g, base, on, populate_qf)
  local c = gs_config()
  c.show_deleted = on
  c.word_diff = on
  g.change_base(base, true, function() -- global: affects all buffers, incl. newly opened
    if on and populate_qf then
      g.setqflist("all", { open = true }) -- title "Hunks"; step with ]q/[q, close if unwanted
    end
  end)
end

-- Close the review quickfix if it's the one we opened (title "Hunks").
local function close_review_qf()
  vim.schedule(function()
    if vim.fn.getqflist({ title = 0 }).title == "Hunks" then
      vim.fn.setqflist({}, "r")
      pcall(function() vim.cmd.cclose() end)
    end
  end)
end

-- Turn every mode off: reset to the default base, hide inline deleted/word diff,
-- and close the review quickfix.
function M.off()
  local g = gitsigns()
  if not g then return end
  M.mode = nil
  apply(g, nil, false, false)
  close_review_qf()
  vim.notify("gitdiff: off")
end

-- Enable `mode`, or "off"/nil to disable. `mode` is a named preset
-- ("index"|"commit"|"mergebase") or any git revision (branch/tag/commit) to diff
-- the working tree against, e.g. "origin/develop" or a SHA.
-- opts.force = true always enables (no toggle-off) — used by scripts/AI so the
-- resulting state is deterministic regardless of what was active before.
-- opts.qf  = false suppresses the quickfix worklist (code-explainer uses its own
--            loclist UI and doesn't want the quickfix opened over the tour).
function M.set_mode(mode, opts)
  opts = opts or {}
  if mode == "off" or mode == nil then
    return M.off()
  end
  local g = gitsigns()
  if not g then return end

  if M.mode == mode and not opts.force then
    return M.off()
  end

  -- Resolve the base revision: a named preset, or otherwise a literal git
  -- revision (branch/tag/commit) to diff against.
  local base, label
  local base_fn = BASE[mode]
  if base_fn then
    base = base_fn()
    if mode == "mergebase" and not base then
      vim.notify("gitdiff: could not resolve merge base with main", vim.log.levels.WARN)
      return
    end
    label = (LABEL[mode] or mode) .. (base and (" (" .. base .. ")") or "")
  elseif valid_rev(mode) then
    base = mode
    label = "vs " .. mode
  else
    vim.notify("gitdiff: unknown mode / unknown revision " .. tostring(mode), vim.log.levels.ERROR)
    return
  end

  apply(g, base, true, opts.qf ~= false)
  M.mode = mode
  vim.notify("gitdiff: " .. label)
end

-- ── Hunk-kind coloring for the quickfix worklist ──────────────────────────
-- Worklist entries read "Added   (-x +y): …" / "Removed …" / "Changed …".
-- The kind word gets a background tint in the matching gitsigns sign color,
-- so the code text next to it stays readable with its own highlighting. The
-- groups are derived from the colorscheme (and re-derived when it changes);
-- they are used both by the plain-quickfix matches below and by Trouble's
-- hunk_text formatter — matches can't reach Trouble's window.

local hunk_kind_hl =
  { Added = "HunkKindAdded", Removed = "HunkKindRemoved", Changed = "HunkKindChanged" }
-- Fallback chains mirror how gitsigns derives its own groups — the GitSigns*
-- groups only exist once gitsigns has loaded (and not every colorscheme
-- defines them), so fall through to the diff groups, then a fixed color.
local hunk_kind_src = {
  HunkKindAdded = { "GitSignsAdd", "GitGutterAdd", "diffAdded", "DiffAdd", 0x2ea043 },
  HunkKindChanged = { "GitSignsChange", "GitGutterChange", "diffChanged", "DiffChange", 0xd29922 },
  HunkKindRemoved = { "GitSignsDelete", "GitGutterDelete", "diffRemoved", "DiffDelete", 0xf85149 },
}
local function set_hunk_kind_hl()
  local normal_bg = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg or 0x000000
  for group, srcs in pairs(hunk_kind_src) do
    local color
    for _, src in ipairs(srcs) do
      color = type(src) == "number" and src
        or vim.api.nvim_get_hl(0, { name = src, link = false }).fg
      if color then
        break
      end
    end
    vim.api.nvim_set_hl(0, group, { bg = color, fg = normal_bg })
  end
end
set_hunk_kind_hl()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("gitdiff_hunk_kind_hl", { clear = true }),
  callback = set_hunk_kind_hl,
})
-- Matches are window-local and FileType only fires once per buffer, so also
-- hook BufWinEnter to cover the qf buffer re-shown in a fresh window.
vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  group = vim.api.nvim_create_augroup("gitdiff_qf_hunk_colors", { clear = true }),
  callback = function()
    if vim.bo.filetype ~= "qf" or vim.w.gitdiff_hunk_matches then
      return
    end
    vim.w.gitdiff_hunk_matches = true
    for kind, hl in pairs(hunk_kind_hl) do
      vim.fn.matchadd(hl, [[\<]] .. kind .. [[\ze\s\+(-\d]])
    end
  end,
})

-- Trouble renders list text itself (window matches / qf syntax never reach
-- it), so it needs a formatter instead: split the entry into kind + hunk
-- header + code line — the kind gets the tint, and the code keeps Trouble's
-- treesitter highlighting (hl = "ts" is resolved to the item buffer's
-- language by the renderer). For anything else return nil so the caller's
-- `|text:ts` fallback keeps Trouble's default rendering. Wired into
-- Trouble's formatter pipeline by plugins/trouble.lua.
function M.trouble_hunk_formatter(ctx)
  local text = tostring(ctx.item.text or "")
  local kind, header, code = text:match("^(%a+)(%s+%(%-%d.-%):%s?)(.*)$")
  if not (kind and hunk_kind_hl[kind]) then
    return
  end
  return {
    { text = kind, hl = hunk_kind_hl[kind] },
    { text = header },
    { text = code, hl = "ts" },
  }
end

return M
