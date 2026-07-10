-- gitdiff — switch gitsigns' diff base between three review modes and render the
-- diff inline (deleted lines + word-level diff) around every hunk.
--
--   index      current diff  — working tree vs index (staged + unstaged)
--   commit     last commit   — vs HEAD~1
--   mergebase  branch diff   — vs `git merge-base <main> HEAD` (your changes off main)
--
-- Re-selecting the active mode turns it back off (plain working view). `mode`
-- state is module-global because gitsigns' base is global to all buffers.
--
-- Used by:
--   * keymaps  <leader>gd1/2/3           (config/keymaps.lua)
--   * command  :GitDiffMode {mode|off}   (config/keymaps.lua)
--   * AI       code-explainer honors a tour's `diff_base` field via set_mode()

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

-- Base revision to hand gitsigns for each mode (nil = its default = index).
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

-- Enable `mode` ("index"|"commit"|"mergebase"), or "off"/nil to disable.
-- opts.force = true always enables (no toggle-off) — used by scripts/AI so the
-- resulting state is deterministic regardless of what was active before.
-- opts.qf  = false suppresses the quickfix worklist (code-explainer uses its own
--            loclist UI and doesn't want the quickfix opened over the tour).
function M.set_mode(mode, opts)
  opts = opts or {}
  if mode == "off" or mode == nil then
    return M.off()
  end
  local base_fn = BASE[mode]
  if not base_fn then
    vim.notify("gitdiff: unknown mode " .. tostring(mode), vim.log.levels.ERROR)
    return
  end
  local g = gitsigns()
  if not g then return end

  if M.mode == mode and not opts.force then
    return M.off()
  end

  local base = base_fn()
  if mode == "mergebase" and not base then
    vim.notify("gitdiff: could not resolve merge base with main", vim.log.levels.WARN)
    return
  end
  apply(g, base, true, opts.qf ~= false)
  M.mode = mode
  vim.notify("gitdiff: " .. (LABEL[mode] or mode) .. (base and (" (" .. base .. ")") or ""))
end

return M
