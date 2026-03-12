if exists("b:current_syntax")
  finish
endif

syn match hledgerReportTitle /^\(Balance Sheet With Equity\|Income Statement\).*$/
syn match hledgerReportDivider /^\s*[=+-][=+| -]*$/
syn match hledgerReportColumnSep /||/
syn match hledgerReportDate /\d\{4}\%(-\d\{2}-\d\{2}\)\?/
syn match hledgerReportCurrency /\<\%(JPY\|THB\|USD\|EUR\|GBP\)\>/
syn match hledgerReportAmount /-\=\d[\d,]*\%(\.\d\+\)\?/

syn match hledgerReportAssetsSection /^\s*Assets\ze\s*||/
syn match hledgerReportLiabilitiesSection /^\s*Liabilities\ze\s*||/
syn match hledgerReportEquitySection /^\s*Equity\ze\s*||/
syn match hledgerReportRevenuesSection /^\s*Revenues\ze\s*||/
syn match hledgerReportExpensesSection /^\s*Expenses\ze\s*||/
syn match hledgerReportNetSection /^\s*Net:\ze\s*||/

syn match hledgerReportAssets /^\s*assets:[^|]*\ze\s*||/
syn match hledgerReportLiabilities /^\s*liabilities:[^|]*\ze\s*||/
syn match hledgerReportEquity /^\s*equity:[^|]*\ze\s*||/
syn match hledgerReportIncome /^\s*income:[^|]*\ze\s*||/
syn match hledgerReportExpenses /^\s*expenses:[^|]*\ze\s*||/

hi def link hledgerReportTitle Title
hi def link hledgerReportDivider Comment
hi def link hledgerReportColumnSep Delimiter
hi def link hledgerReportDate Constant
hi def link hledgerReportCurrency Type
hi def link hledgerReportAmount Number

hi def link hledgerReportAssetsSection DiagnosticInfo
hi def link hledgerReportLiabilitiesSection DiagnosticWarn
hi def link hledgerReportEquitySection NonText
hi def link hledgerReportRevenuesSection DiagnosticOk
hi def link hledgerReportExpensesSection DiagnosticError
hi def link hledgerReportNetSection Title

hi def link hledgerReportAssets DiagnosticInfo
hi def link hledgerReportLiabilities DiagnosticWarn
hi def link hledgerReportEquity NonText
hi def link hledgerReportIncome DiagnosticOk
hi def link hledgerReportExpenses DiagnosticError

let b:current_syntax = "hledgerreport"
