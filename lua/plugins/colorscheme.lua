local hostname_fn = (vim.uv or vim.loop).os_gethostname
local hostname = hostname_fn and hostname_fn() or ""
local use_matteblack = hostname == "home-server"

return {
  { "rebelot/kanagawa.nvim" },
  { "tahayvr/matteblack.nvim" },
  { "loctvl842/monokai-pro.nvim" },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = use_matteblack and "matteblack" or "monokai-pro",
    },
  },
}
