-- Wire gitdiff's hunk-kind coloring into Trouble's formatter pipeline —
-- the formatter itself lives in config/gitdiff (trouble_hunk_formatter).
return {
  "folke/trouble.nvim",
  opts = function(_, opts)
    opts.formatters = opts.formatters or {}
    opts.formatters.hunk_text = function(ctx)
      return require("config.gitdiff").trouble_hunk_formatter(ctx)
    end
    -- Default qf format with {text:ts} replaced by {hunk_text|text:ts}.
    -- quickfix/loclist are set explicitly: they alias qflist in the source's
    -- defaults, and gitsigns opens the "quickfix" mode.
    local format = "{severity_icon|item.type:DiagnosticSignWarn} {hunk_text|text:ts} {pos}"
    opts.modes = vim.tbl_deep_extend("force", opts.modes or {}, {
      qflist = { format = format },
      quickfix = { format = format },
      loclist = { format = format },
    })
  end,
}
