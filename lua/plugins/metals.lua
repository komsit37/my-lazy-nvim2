-- By default the LazyVim scala extra attaches metals to `java` too
-- (ft = { "scala", "sbt", "java" }), which conflicts with jdtls and errors
-- when coursier isn't installed. Restrict metals to scala/sbt so jdtls owns
-- `.java`. Everything else (keys, settings) comes from the extra via opts.
return {
  {
    "scalameta/nvim-metals",
    config = function(_, metals_config)
      local group = vim.api.nvim_create_augroup("nvim-metals", { clear = true })
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "scala", "sbt" },
        callback = function()
          require("metals").initialize_or_attach(metals_config)
        end,
        group = group,
      })
    end,
  },
}
