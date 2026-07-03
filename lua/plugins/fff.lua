return {
  "dmtrKovalenko/fff.nvim",
  build = function()
    -- downloads a prebuilt binary or falls back to cargo build
    require("fff.download").download_or_build_binary()
  end,
  -- for nixos:
  -- build = "nix run .#release",
  opts = {
    debug = {
      enabled = true,
      show_scores = true,
    },
    layout = {
      prompt_position = "top", -- input at top, list below
      preview_position = "bottom", -- file list above, preview below
      -- flex swaps to a stacked layout when the window is narrower than
      -- flex.size (default 130 cols); force its wrap to also put the list on top.
      flex = { wrap = "bottom" },
    },
  },
  lazy = false, -- the plugin lazy-initialises itself
  keys = {
    {
      "<leader><space>",
      function()
        require("fff").find_files()
      end,
      desc = "Find Files (FFF)",
    },
    {
      "<leader>ff",
      function()
        require("fff").find_files()
      end,
      desc = "Find Files (FFF)",
    },
    {
      "<leader>sg",
      function()
        require("fff").live_grep()
      end,
      desc = "Grep (FFF)",
    },
    {
      "<leader>/",
      function()
        require("fff").live_grep()
      end,
      desc = "Grep (FFF)",
    },
    {
      "<leader>sz",
      function()
        require("fff").live_grep({ grep = { modes = { "fuzzy", "plain" } } })
      end,
      desc = "Fuzzy Grep (FFF)",
    },
    {
      "<leader>sw",
      function()
        require("fff").live_grep({ query = vim.fn.expand("<cword>") })
      end,
      desc = "Grep Current Word (FFF)",
      mode = { "n", "x" },
    },
  },
}
