return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    opts = {
      sources = {
        "filesystem",
        "git_status",
        "buffers",
        "document_symbols",
      },
      source_selector = {
        winbar = true,
        statusline = false,
        sources = {
          { source = "filesystem", display_name = " 󰉓 Files " },
          { source = "git_status", display_name = " 󰊢 Git " },
          { source = "buffers", display_name = " 󰈚 Buffers " },
          { source = "document_symbols", display_name = " 󰘦 Symbols " },
        },
      },
      filesystem = {
        filtered_items = {
          hide_by_name = {
            "__init__.py",
          },
        },
      },
    },
  },
}
