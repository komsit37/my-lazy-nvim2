-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Don't let small deletes overwrite your last yank
vim.keymap.set("n", "x", '"_x', opts) -- delete char (no yank)
vim.keymap.set("n", "X", '"_X', opts) -- delete backward char (no yank)

-- Yank to system clipboard
vim.keymap.set("v", "<leader>y", '"+y', { desc = 'Yank to system clipboard "+y' })
vim.keymap.set("v", "<leader>p", '"+p', { desc = 'Paste from system clipboard "+p' })

-- For bufferline
-- jump to buffer by number
local wk = require("which-key")

local ok, bufferline = pcall(require, "bufferline")
if ok then
  for i = 1, 9 do
    wk.add({
      "<leader>" .. i,
      function()
        bufferline.go_to(i, true)
      end,
      -- no desc: hidden from which-key popup
    })
  end
end

-- Keymaps: keep cursor centered after common navigation moves
-- Drop this into (for example):
--   ~/.config/nvim/lua/config/keymaps.lua
-- or in LazyVim: lua/config/keymaps.lua (it gets loaded automatically)

local opts = { noremap = true, silent = true }

-- ─────────────────────────────────────────────────────────────────────────────
-- Core vertical movement centering (you already have most of this)
-- ─────────────────────────────────────────────────────────────────────────────
vim.keymap.set("n", "j", "jzz", opts)
vim.keymap.set("n", "k", "kzz", opts)
vim.keymap.set("n", "{", "{zz", opts)
vim.keymap.set("n", "}", "}zz", opts)

-- Page/half-page jumps
vim.keymap.set("n", "<C-d>", "<C-d>zz", opts) -- half-page down + center
vim.keymap.set("n", "<C-u>", "<C-u>zz", opts) -- half-page up + center
vim.keymap.set("n", "<C-f>", "<C-f>zz", opts) -- full page down + center
vim.keymap.set("n", "<C-b>", "<C-b>zz", opts) -- full page up + center

-- Big jumps: keep centered
vim.keymap.set("n", "G", "Gzz", opts) -- end of file
vim.keymap.set("n", "gg", "ggzz", opts) -- start of file
vim.keymap.set("n", "%", "%zz", opts) -- matching bracket/paren

-- ─────────────────────────────────────────────────────────────────────────────
-- Git/Diff/Quickfix bracket motions (STATIC maps)
-- These assume the motions already exist (gitsigns/diff/quickfix etc.)
-- ─────────────────────────────────────────────────────────────────────────────
-- Git hunks (commonly from gitsigns)
vim.keymap.set("n", "]h", "]hzz", opts) -- next hunk
vim.keymap.set("n", "[h", "[hzz", opts) -- prev hunk
vim.keymap.set("n", "]H", "]Hzz", opts) -- last hunk
vim.keymap.set("n", "[H", "[Hzz", opts) -- first hunk

-- Diff mode changes (built-in)
vim.keymap.set("n", "]c", "]czz", opts) -- next diff change
vim.keymap.set("n", "[c", "[czz", opts) -- prev diff change

-- Quickfix list navigation (built-in)
vim.keymap.set("n", "]q", "]qzz", opts) -- next quickfix item (:cnext)
vim.keymap.set("n", "[q", "[qzz", opts) -- prev quickfix item (:cprev)

-- Location list navigation (built-in)
vim.keymap.set("n", "]l", "]lzz", opts) -- next loclist item (:lnext)
vim.keymap.set("n", "[l", "[lzz", opts) -- prev loclist item (:lprev)

-- ─────────────────────────────────────────────────────────────────────────────
-- Search navigation centering
-- (Also opens folds with zv so match is visible)
-- ─────────────────────────────────────────────────────────────────────────────
vim.keymap.set("n", "n", "nzzzv", opts) -- next search result + center + open folds
vim.keymap.set("n", "N", "Nzzzv", opts) -- prev search result + center + open folds
vim.keymap.set("n", "*", "*zzzv", opts) -- search word under cursor forward
vim.keymap.set("n", "#", "#zzzv", opts) -- search word under cursor backward
vim.keymap.set("n", "g*", "g*zzzv", opts)
vim.keymap.set("n", "g#", "g#zzzv", opts)

-- ─────────────────────────────────────────────────────────────────────────────
-- Useful “next/prev” in LazyVim land (LSP, diagnostics, todo-comments, etc.)
-- These are STATIC mappings to built-in commands where possible.
-- ─────────────────────────────────────────────────────────────────────────────

-- Diagnostics (built-in in Neovim)
vim.keymap.set("n", "]d", vim.diagnostic.goto_next, { desc = "Next Diagnostic", silent = true })
vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev Diagnostic", silent = true })

-- If you want centering after diagnostics too, use wrappers:
vim.keymap.set("n", "]D", function()
  vim.diagnostic.goto_next()
  vim.cmd("normal! zz")
end, { desc = "Next Diagnostic (center)", silent = true })

vim.keymap.set("n", "[D", function()
  vim.diagnostic.goto_prev()
  vim.cmd("normal! zz")
end, { desc = "Prev Diagnostic (center)", silent = true })

-- LSP references/definitions jumps (LazyVim often uses Telescope; these are pure LSP)
vim.keymap.set("n", "gd", function()
  vim.lsp.buf.definition()
  vim.cmd("normal! zz")
end, { desc = "Go to Definition (center)", silent = true })

vim.keymap.set("n", "gD", function()
  vim.lsp.buf.declaration()
  vim.cmd("normal! zz")
end, { desc = "Go to Declaration (center)", silent = true })

vim.keymap.set("n", "gi", function()
  vim.lsp.buf.implementation()
  vim.cmd("normal! zz")
end, { desc = "Go to Implementation (center)", silent = true })

vim.keymap.set("n", "gr", function()
  vim.lsp.buf.references()
  -- references opens a list/UI; centering happens when you jump from it
end, { desc = "References", silent = true })

-- TODO comments (if you use folke/todo-comments.nvim, common in LazyVim)
-- These commands won't error if the plugin isn't installed? (They will if called)
-- so they are just keymaps; safe if you don't press them without the plugin.
vim.keymap.set("n", "]t", "<cmd>TodoNext<cr>zz", { desc = "Next TODO", silent = true })
vim.keymap.set("n", "[t", "<cmd>TodoPrev<cr>zz", { desc = "Prev TODO", silent = true })

-- Trouble (if you use folke/trouble.nvim, common in LazyVim)
vim.keymap.set("n", "]x", "<cmd>Trouble next<cr>zz", { desc = "Next Trouble Item", silent = true })
vim.keymap.set("n", "[x", "<cmd>Trouble prev<cr>zz", { desc = "Prev Trouble Item", silent = true })

-- Tmux-like buffer/tab navigation (handy for “next/prev” mental model)
vim.keymap.set("n", "]b", "<cmd>bnext<cr>zz", { desc = "Next Buffer (center)", silent = true })
vim.keymap.set("n", "[b", "<cmd>bprevious<cr>zz", { desc = "Prev Buffer (center)", silent = true })
vim.keymap.set("n", "]<tab>", "<cmd>tabnext<cr>zz", { desc = "Next Tab (center)", silent = true })
vim.keymap.set("n", "[<tab>", "<cmd>tabprevious<cr>zz", { desc = "Prev Tab (center)", silent = true })

-- ─────────────────────────────────────────────────────────────────────────────
-- Notes / gotchas
-- ─────────────────────────────────────────────────────────────────────────────
-- 1) The bracket maps like ]h, ]H require a plugin (e.g. gitsigns) or config that
--    defines them. If they don't exist, pressing them will just do nothing or beep.
-- 2) For maximum consistency, you can add zz to ANY other “jump” you use often:
--    :cnext/:cprev, :lnext/:lprev, ]m/[m, etc.
-- 3) If you ever want "match anything ]+?" you need expr mapping; static maps can’t.
