return {
  {
    "ledger/vim-ledger",
    lazy = true,
    init = function()
      local hledger = require("user.hledger")
      local bin = vim.fn.exepath("hledger")
      vim.g.ledger_bin = bin ~= "" and bin or "hledger"
      vim.g.ledger_is_hledger = true
      vim.g.ledger_date_format = "%Y-%m-%d"
      vim.g.ledger_align_at = 52
      vim.g.ledger_fuzzy_account_completion = 1
      vim.g.ledger_detailed_first = 1
      vim.g.ledger_use_location_list = 1

      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = { "*.journal", "*.ledger", "*.ldg" },
        callback = function(event)
          if hledger.is_project(event.buf) then
            require("lazy").load({ plugins = { "vim-ledger" } })
            vim.bo[event.buf].filetype = "ledger"
          end
        end,
      })

      vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
        pattern = "*.rules",
        callback = function(event)
          if hledger.is_project(event.buf) then
            vim.bo[event.buf].filetype = "conf"
            vim.bo[event.buf].commentstring = "# %s"
          end
        end,
      })
    end,
  },
}
