" Vim syntax file for hledger picker preview output
" Supports: print, reg, areg formats
" Account-type colors aligned with hledgerreport.vim

if exists("b:current_syntax")
  finish
endif

syntax case match

" ── areg heading ──────────────────────────────────────────────────────
syn match hledgerPHeading /^Transactions in .*$/

" ── Dates ─────────────────────────────────────────────────────────────
syn match hledgerPDate  /^\d\{4\}[-/.]\d\{1,2\}[-/.]\d\{1,2\}/
syn match hledgerPDate2 /=\d\{4\}[-/.]\d\{1,2\}[-/.]\d\{1,2\}/

" ── Status markers (* !) ──────────────────────────────────────────────
syn match hledgerPStatus /^\d\{4\}[-/.]\d\{1,2\}[-/.]\d\{1,2\}\s\+\zs[*!]/

" ── Account names by type ─────────────────────────────────────────────
" Tail: (non-space | single-space + non-space)+
" Stops at double-space or EOL — handles accounts with internal spaces

" Assets (assets, asset, as:..., a:...)
syn match hledgerPAsset     /\<assets\?\(:\([^ ]\| [^ ]\)\+\)\?/
syn match hledgerPAsset     /\<as:\([^ ]\| [^ ]\)\+/
syn match hledgerPAsset     /\<a:\([^ ]\| [^ ]\)\+/

" Liabilities (liabilities, liability, li:..., l:...)
syn match hledgerPLiability /\<liabilit\w*\(:\([^ ]\| [^ ]\)\+\)\?/
syn match hledgerPLiability /\<li:\([^ ]\| [^ ]\)\+/
syn match hledgerPLiability /\<l:\([^ ]\| [^ ]\)\+/

" Expenses (expenses, expense, ex:..., e:...)
syn match hledgerPExpense   /\<expenses\?\(:\([^ ]\| [^ ]\)\+\)\?/
syn match hledgerPExpense   /\<ex:\([^ ]\| [^ ]\)\+/
syn match hledgerPExpense   /\<e:\([^ ]\| [^ ]\)\+/

" Income / Revenue (income, revenues, revenue, in:..., i:..., re:...)
syn match hledgerPIncome    /\<income\(:\([^ ]\| [^ ]\)\+\)\?/
syn match hledgerPIncome    /\<revenues\?\(:\([^ ]\| [^ ]\)\+\)\?/
syn match hledgerPIncome    /\<in:\([^ ]\| [^ ]\)\+/
syn match hledgerPIncome    /\<i:\([^ ]\| [^ ]\)\+/
syn match hledgerPIncome    /\<re:\([^ ]\| [^ ]\)\+/

" Equity (equity, eq:...)
syn match hledgerPEquity    /\<equity\(:\([^ ]\| [^ ]\)\+\)\?/
syn match hledgerPEquity    /\<eq:\([^ ]\| [^ ]\)\+/

" ── Currency codes ────────────────────────────────────────────────────
syn match hledgerPCurrency  /\<\(JPY\|THB\|USD\|EUR\|GBP\|AUD\|SGD\|HKD\|MYR\|VND\|CNY\|KRW\|TWD\|INR\|IDR\|PHP\|NZD\|CAD\|CHF\|SEK\|NOK\|DKK\|BRL\|ZAR\|AED\|SAR\|ILS\|TRY\|PLN\|CZK\|HUF\|MXN\|ARS\|CLP\|COP\|PEN\|RUB\|UAH\)\>/

" ── Negative amounts ──────────────────────────────────────────────────
syn match hledgerPNegAmount /-[0-9,]\+\.\?[0-9]*/

" ── Comments (region blocks account matches inside) ───────────────────
syn region hledgerPComment  start=/;/ end=/$/ contains=hledgerPTag oneline
syn region hledgerPComment  start=/^[;#*]/ end=/$/ contains=hledgerPTag oneline
syn match  hledgerPTag      /[-\w]\+:[^,;]*/ contained

" ── Highlight links ───────────────────────────────────────────────────
" Structural
hi def link hledgerPDate      Constant
hi def link hledgerPDate2     Constant
hi def link hledgerPStatus    Keyword
hi def link hledgerPHeading   Title
hi def link hledgerPCurrency  Type
hi def link hledgerPNegAmount DiagnosticError
hi def link hledgerPComment   Comment
hi def link hledgerPTag       Tag

" Account types — semantic accounting colors
"   positive (asset, income)  → green
"   negative (liability, expense) → red
"   neutral  (equity) → muted
hi def link hledgerPAsset     DiagnosticOk
hi def link hledgerPIncome    DiagnosticOk
hi def link hledgerPLiability DiagnosticError
hi def link hledgerPExpense   DiagnosticError
hi def link hledgerPEquity    NonText

let b:current_syntax = "hledger_preview"
