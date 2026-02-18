-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local group = vim.api.nvim_create_augroup("user_markdown_images", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "markdown", "markdown.mdx" },
  callback = function(event)
    vim.keymap.set("n", "<leader>mis", function()
      require("user.paste-image").paste_markdown_image("small")
    end, { buffer = event.buf, desc = "Markdown: Paste Image (Small)" })

    vim.keymap.set("n", "<leader>mim", function()
      require("user.paste-image").paste_markdown_image("medium")
    end, { buffer = event.buf, desc = "Markdown: Paste Image (Medium)" })

    vim.keymap.set("n", "<leader>mil", function()
      require("user.paste-image").paste_markdown_image("large")
    end, { buffer = event.buf, desc = "Markdown: Paste Image (Large)" })
  end,
})
