return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      previewers = {
        diff = {
          builtin = false, -- use Neovim for previewing diffs (true) or use an external tool (false)
          -- cmd = { "delta" }, -- example to show a diff with delta
          -- temp fix for delta not showing correct width. somehow no issue with git command
          -- cmd = { "delta", "--side-by-side", "--width=180" },
        },
        git = {
          -- builtin = false, -- use Neovim for previewing git output (true) or use git (false)
          args = {}, -- additional arguments passed to the git command. Useful to set pager options usin `-c ...`
        },
      },
      layout = {
        -- preset = function()
        --   return "ivy_split"
        -- end,
      },
      layouts = {
        -- Custom picker layout with 2 changes:
        -- 1. wider width to 90%
        -- 2. expand preview to 60%
        default = {
          layout = {
            box = "horizontal",
            width = 0.9,
            min_width = 120,
            height = 0.8,
            {
              box = "vertical",
              border = true,
              title = "{title} {live} {flags}",
              { win = "input", height = 1, border = "bottom" },
              { win = "list", border = "none" },
            },
            { win = "preview", title = "{preview}", border = true, width = 0.6 },
          },
        },
        --   vertical = { layout = { width = 0.9 } },
        ivy_split = { layout = { height = 0.2 } },
      },
      sources = {
        grep = {
          -- {
          --   layout = {
          --     box = "vertical",
          --     backdrop = false,
          --     row = -1,
          --     width = 0,
          --     height = 0.4,
          --     border = "top",
          --     title = " {title} {live} {flags}",
          --     title_pos = "left",
          --     { win = "input", height = 1, border = "bottom" },
          --     {
          --       box = "horizontal",
          --       { win = "list", border = "none" },
          --       { win = "preview", title = "{preview}", width = 0.6, border = "left" },
          --     },
          --   },
          -- },
        },
        files = {},
        git_status = {},
        git_diff = {},
        git_log = {},
        git_log_file = {},
        explorer = {
          layout = { layout = { position = "left" } },
        },
      },
    },
  },
  keys = {
    {
      "<leader>ch",
      function()
        require("user.enhanced-lsp-refs").enhanced_references()
      end,
      desc = "Find References (LSP)",
      mode = "n",
    },
    -- I forgot the use case for this one?
    -- {
    --   "<leader>cH",
    --   function()
    --     require("user.enhanced-lsp-refs").grep_references()
    --   end,
    --   desc = "Find References (LSP/simple)",
    --   mode = "n",
    -- },
  },
}
