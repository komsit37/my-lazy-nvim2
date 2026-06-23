-- nvim-q lives in different places per machine; use whichever exists.
local function nvim_q_dir()
  local candidates = {
    vim.fn.expand("~/work/lab/nvim-q"), -- linux
    vim.fn.expand("~/code/try/nvim-q"), -- osx
  }
  for _, dir in ipairs(candidates) do
    if vim.fn.isdirectory(dir) == 1 then
      return dir
    end
  end
  return candidates[1]
end

return {
  {
    dir = nvim_q_dir(),
    name = "nvim-q",
    ft = "q",
    opts = {
      connections = {
        { name = "local", host = "localhost", port = 5555 },
      },
      keymaps = true,
    },
  },
}
