return {
  "dmtrKovalenko/fff.nvim",
  build = function()
    -- downloads a prebuilt binary or falls back to cargo build
    require("fff.download").download_or_build_binary()
  end,
  -- for nixos:
  -- build = "nix run .#release",
  init = function()
    -- FFF windows point at these dedicated groups (see opts.hl) so colorfilter
    -- can blacken the picker without touching other floats. Default links keep
    -- the stock float look when colorfilter is off; re-linked on every
    -- ColorScheme because :hi clear wipes them.
    local links = { FFFNormal = "NormalFloat", FFFBorder = "FloatBorder", FFFTitle = "Title" }
    local function link()
      for group, target in pairs(links) do
        vim.api.nvim_set_hl(0, group, { link = target, default = true })
      end
    end
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("fff_hl_links", { clear = true }),
      callback = link,
    })
    link()
  end,
  opts = {
    hl = {
      normal = "FFFNormal",
      border = "FFFBorder",
      title = "FFFTitle",
    },
    debug = {
      enabled = true,
      show_scores = true,
    },
    layout = {
      prompt_position = "top", -- input at top, list below
      preview_position = "right", -- wide terminals: preview on the side
      -- When the terminal is narrower than flex.size, stack instead: list on
      -- top, preview at the bottom.
      flex = { size = 130, wrap = "bottom" },
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
