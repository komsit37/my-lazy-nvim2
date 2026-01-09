-- disable markdown lint
-- In your nvim-lint configuration file (e.g., lua/plugins/lint.lua)
return {
  "mfussenegger/nvim-lint",
  opts = {
    linters_by_ft = {
      -- Set the markdown entry to an empty table or nil to disable markdown linters
      markdown = {},
      -- other linters...
    },
  },
}
