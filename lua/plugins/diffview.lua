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
    { "<leader>gvm", "<cmd>DiffviewOpen origin/main...HEAD<cr>", desc = "Diff vs origin/main" },
    { "<leader>gvM", "<cmd>DiffviewOpen origin/master...HEAD<cr>", desc = "Diff vs origin/master" },
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
