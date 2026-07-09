-- Persist the colorscheme chosen via <leader>uC across restarts. The state file
-- is machine-local (not synced), so each host keeps its own choice; the default
-- below is only the initial fallback before the first pick.
local persist_file = vim.fn.stdpath("state") .. "/colorscheme.txt"
local default_colorscheme = "monokai-pro"

local function saved_colorscheme()
  local f = io.open(persist_file, "r")
  if not f then
    return nil
  end
  local name = f:read("l")
  f:close()
  return name and name ~= "" and name or nil
end

return {
  { "rebelot/kanagawa.nvim" },
  { "tahayvr/matteblack.nvim" },
  { "loctvl842/monokai-pro.nvim" },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = saved_colorscheme() or default_colorscheme,
    },
    init = function()
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = vim.api.nvim_create_augroup("persist_colorscheme", { clear = true }),
        callback = function(ev)
          if ev.match and ev.match ~= "" then
            local f = io.open(persist_file, "w")
            if f then
              f:write(ev.match)
              f:close()
            end
          end
        end,
      })
    end,
  },
}
