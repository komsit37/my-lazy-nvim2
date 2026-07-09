-- colorfilter: theme-agnostic colorscheme post-processor (deep black bg + gamma/
-- saturation/brightness foreground tuning). Logic lives in lua/colorfilter/.
--
-- Anchored to which-key (not LazyVim/LazyVim) because colorscheme.lua already
-- attaches an init to LazyVim/LazyVim, and lazy.nvim keeps only one init per
-- plugin — a second one would be silently dropped.
return {
  {
    "folke/which-key.nvim",
    optional = true,
    init = function()
      require("colorfilter").setup()
    end,
    opts = {
      spec = {
        { "<leader>uv", group = "colorfilter", icon = "󰸉 " },
      },
    },
  },
}
