return {
  "sindrets/diffview.nvim",
  cmd = {
    "DiffviewOpen",
    "DiffviewClose",
    "DiffviewToggleFiles",
    "DiffviewFocusFiles",
    "DiffviewRefresh",
    "DiffviewFileHistory",
  },
  keys = {
    { "<leader>gvo", "<cmd>DiffviewOpen<cr>", desc = "Open (working tree vs index)" },
    { "<leader>gvd", "<cmd>DiffviewClose<cr>", desc = "Close" },
    { "<leader>gvt", "<cmd>DiffviewToggleFiles<cr>", desc = "Toggle files panel" },
    { "<leader>gvf", "<cmd>DiffviewFocusFiles<cr>", desc = "Focus files panel" },
    { "<leader>gvr", "<cmd>DiffviewRefresh<cr>", desc = "Refresh" },
    { "<leader>gvh", "<cmd>DiffviewFileHistory<cr>", desc = "History (repo)" },
    { "<leader>gvH", "<cmd>DiffviewFileHistory %<cr>", desc = "History (current file)" },
    { "<leader>gvH", "<Esc><cmd>'<,'>DiffviewFileHistory<cr>", mode = "v", desc = "History (selection)" },
    {
      "<leader>gvm",
      function()
        -- Prefer main, fall back to master (checks remote-tracking, then local).
        local function ref_exists(ref)
          return vim.fn.system({ "git", "rev-parse", "--verify", "--quiet", ref }) ~= ""
            and vim.v.shell_error == 0
        end
        local base
        for _, ref in ipairs({ "origin/main", "origin/master", "main", "master" }) do
          if ref_exists(ref) then
            base = ref
            break
          end
        end
        if not base then
          vim.notify("diffview: no main/master branch found", vim.log.levels.WARN)
          return
        end
        vim.cmd("DiffviewOpen " .. base .. "...HEAD")
      end,
      desc = "Diff vs main/master",
    },
    { "<leader>gvs", "<cmd>DiffviewOpen --staged<cr>", desc = "Staged changes" },
  },
  opts = {
    enhanced_diff_hl = true,
    view = {
      merge_tool = {
        layout = "diff3_mixed",
        disable_diagnostics = true,
      },
    },
  },
}
