-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- add centering on vertical movements for smooth scrolling
local opts = { noremap = true, silent = true }

-- add centering on vertical movements for smooth scrolling
vim.keymap.set("n", "j", "jzz", opts)
vim.keymap.set("n", "k", "kzz", opts)
vim.keymap.set("n", "{", "{zz", opts)
vim.keymap.set("n", "}", "}zz", opts)
vim.keymap.set("n", "<C-j>", "<C-d>zz", opts) -- half-page down + center
vim.keymap.set("n", "<C-u>", "<C-u>zz", opts) -- half-page up + center

-- Code

-- Don't let small deletes overwrite your last yank
vim.keymap.set("n", "x", '"_x', opts) -- delete char (no yank)
vim.keymap.set("n", "X", '"_X', opts) -- delete backward char (no yank)

-- Yank to system clipboard
vim.keymap.set("v", "<leader>y", '"+y', { desc = 'Yank to system clipboard "+y' })
vim.keymap.set("v", "<leader>p", '"+p', { desc = 'Paste from system clipboard "+p' })
