-- copy_location.lua
return {
  {
    "nvim-lua/plenary.nvim", -- dummy dependency
    keys = {
      -- Copy file:line:col + context
      {
        "<leader>cy",
        function()
          -- Get current file, line, column
          local filepath = vim.fn.expand("%:p")
          local line = vim.fn.line(".")
          local col = vim.fn.col(".")

          -- Try git root first
          local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")[1]
          if vim.v.shell_error == 0 and git_root and git_root ~= "" then
            filepath = filepath:gsub("^" .. vim.pesc(git_root .. "/"), "")
          else
            filepath = vim.fn.fnamemodify(filepath, ":.")
          end

          -- Detect visual selection
          local mode = vim.fn.mode()
          local context = ""
          if mode:match("[vV]") then
            -- Get visual selection range
            local _, ls, cs = unpack(vim.fn.getpos("'<"))
            local _, le, ce = unpack(vim.fn.getpos("'>"))

            local lines = vim.fn.getline(ls, le)
            -- Defensive: ensure table
            if type(lines) == "string" then
              lines = { lines }
            end

            if #lines > 0 then
              lines[#lines] = string.sub(lines[#lines], 1, ce)
              lines[1] = string.sub(lines[1], cs)
              context = table.concat(lines, "\n")
            end
          else
            -- No selection → word under cursor
            context = vim.fn.expand("<cword>")
          end

          -- Copy to system clipboard
          local result = string.format("%s:%d:%d %s", filepath, line, col, context)
          vim.fn.setreg("+", result)
          print("Copied: " .. result)
        end,
        mode = { "n", "v" },
        desc = "Copy file:line:col + context",
      },
    },
  },
}
