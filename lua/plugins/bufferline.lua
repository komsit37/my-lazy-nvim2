return {
  {
    "akinsho/bufferline.nvim",
    opts = {
      options = {
        numbers = function(opts)
          return string.format("[%d]", opts.ordinal)
        end,
      },
    },
  },
}
