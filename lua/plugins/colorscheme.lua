local hostname_fn = (vim.uv or vim.loop).os_gethostname
local hostname = hostname_fn and hostname_fn() or ""
local use_matteblack = hostname == "antec"

return {
  { "rebelot/kanagawa.nvim", enabled = not use_matteblack },
  { "tahayvr/matteblack.nvim", enabled = use_matteblack },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = use_matteblack and "matteblack" or "kanagawa",
    },
  },
}
