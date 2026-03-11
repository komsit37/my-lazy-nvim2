vim.filetype.add({
  extension = {
    hledgerreport = "hledgerreport",
  },
  pattern = {
    [".*/reports/%d%d%d%d/bse%.txt"] = "hledgerreport",
    [".*/reports/%d%d%d%d/is%.txt"] = "hledgerreport",
  },
})
