return {
  {
    "3rd/image.nvim",
    build = false, -- don't try to build the Lua rock (use ImageMagick CLI instead)
    cmd = { "ImageReport" },
    ft = { "markdown", "markdown.mdx" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = function()
      return {
        -- Ghostty supports Kitty graphics protocol; keep this simple and fast.
        -- Override anytime with: `:lua vim.g.image_backend = "ueberzug"` (or "sixel").
        backend = vim.g.image_backend or "kitty",
        processor = "magick_cli",
        integrations = {
          markdown = {
            enabled = true,
            download_remote_images = true,
            clear_in_insert_mode = false,
            only_render_image_at_cursor = false,
            filetypes = { "markdown", "markdown.mdx" },
          },
        },
      }
    end,
    config = function(_, opts)
      local ok, image = pcall(require, "image")
      if not ok then return end
      local ok_setup, err = pcall(image.setup, opts)
      if ok_setup then return end
      vim.schedule(function()
        vim.notify("image.nvim setup failed:\n" .. tostring(err), vim.log.levels.ERROR)
      end)
    end,
  },
}
