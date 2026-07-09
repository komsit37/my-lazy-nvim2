-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
-- vim.o.clipboard = "unnamedplus"
-- do not yank to system registry, so we can maintain system clipboard
vim.opt.clipboard = ""

-- snappier which-key / leader-chord popup (LazyVim default is 300ms)
vim.opt.timeoutlen = 100

-- LazyVim's java extra builds the jdtls command at ft=java time, which can run
-- before mason.nvim sets its env. Without it, `vim.fn.exepath("jdtls")` returns
-- "" and `vim.fn.expand("$MASON/share/jdtls/lombok.jar")` collapses to a bogus
-- "/share/jdtls/lombok.jar", so the jdtls JVM aborts on a missing -javaagent.
-- Set both mason vars early (options.lua loads before lazy startup).
vim.env.MASON = vim.fn.stdpath("data") .. "/mason"
vim.env.PATH = vim.env.MASON
  .. "/bin"
  .. (vim.fn.has("win32") == 1 and ";" or ":")
  .. vim.env.PATH
