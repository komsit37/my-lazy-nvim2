local M = {}

local main_file_cache = {}
local last_args = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "hledger" })
end

local function get_buf_dir(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr or 0)
  if name == "" then
    return vim.uv.cwd()
  end
  if vim.fn.isdirectory(name) == 1 then
    return name
  end
  return vim.fs.dirname(name)
end

local function ancestor_with_ledger_dir(start_dir)
  local dir = start_dir
  while dir and dir ~= "" do
    if vim.fn.isdirectory(vim.fs.joinpath(dir, "ledger")) == 1 then
      return dir
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
end

local function find_upward(start_dir, names)
  local matches = vim.fs.find(names, {
    path = start_dir,
    upward = true,
    stop = vim.uv.os_homedir(),
  })

  if #matches > 0 then
    return vim.fs.dirname(matches[1])
  end
end

function M.find_project_root(bufnr)
  local start_dir = get_buf_dir(bufnr)

  return find_upward(start_dir, { "hledger.conf", ".hledger.conf", ".envrc" }) or ancestor_with_ledger_dir(start_dir)
end

function M.find_root(bufnr)
  local start_dir = get_buf_dir(bufnr)
  local project_root = M.find_project_root(bufnr)
  if project_root then
    return project_root
  end

  local markers = vim.fs.find({ ".git" }, {
    path = start_dir,
    upward = true,
    stop = vim.uv.os_homedir(),
  })

  if #markers > 0 then
    return vim.fs.dirname(markers[1])
  end

  return ancestor_with_ledger_dir(start_dir) or start_dir
end

function M.is_project(bufnr)
  return M.find_project_root(bufnr) ~= nil
end

local function sort_by_depth(paths)
  table.sort(paths, function(a, b)
    local depth_a = select(2, a:gsub("/", ""))
    local depth_b = select(2, b:gsub("/", ""))
    if depth_a == depth_b then
      return a < b
    end
    return depth_a < depth_b
  end)
  return paths
end

function M.find_main_file(bufnr)
  if vim.env.LEDGER_FILE and vim.env.LEDGER_FILE ~= "" then
    return vim.env.LEDGER_FILE
  end

  local root = M.find_root(bufnr)
  if main_file_cache[root] ~= nil then
    return main_file_cache[root]
  end

  local candidates = {}
  for _, pattern in ipairs({ "**/main.journal", "**/main.ledger", "**/index.journal", "**/index.ledger" }) do
    vim.list_extend(candidates, vim.fn.globpath(root, pattern, false, true))
  end

  if #candidates > 0 then
    local match = sort_by_depth(candidates)[1]
    main_file_cache[root] = match
    return match
  end

  local bufname = vim.api.nvim_buf_get_name(bufnr or 0)
  if bufname:match("%.journal$") or bufname:match("%.ledger$") then
    main_file_cache[root] = bufname
    return bufname
  end

  main_file_cache[root] = false
  return nil
end

function M.binary()
  local bin = vim.fn.exepath("hledger")
  if bin ~= "" then
    return bin
  end
  if vim.fn.executable("hledger") == 1 then
    return "hledger"
  end
  return nil
end

local function shellescape(value)
  return vim.fn.shellescape(value)
end

local function has_explicit_input(args)
  if not args or args == "" then
    return false
  end

  return args:match("(^|%s)%-f(%s|$)") ~= nil
    or args:match("(^|%s)%-%-file(%s|=)") ~= nil
    or args:match("(^|%s)%-%-rules%-file(%s|=)") ~= nil
end

local function has_explicit_input_parts(parts)
  for index, part in ipairs(parts or {}) do
    if part == "-f" or part == "--file" or part == "--rules-file" then
      return true
    end
    if vim.startswith(part, "--file=") or vim.startswith(part, "--rules-file=") then
      return true
    end
    if part == "-f" and parts[index + 1] then
      return true
    end
  end
  return false
end

local function trim(value)
  return vim.trim(value or "")
end

local function get_lines(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false)
end

local function bufname(bufnr)
  return vim.api.nvim_buf_get_name(bufnr or 0)
end

local function normalize_bufnr(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function is_rules_buffer(bufnr)
  return bufname(bufnr):match("%.rules$") ~= nil
end

local function cursor_pos(bufnr)
  bufnr = normalize_bufnr(bufnr)

  if bufnr == vim.api.nvim_get_current_buf() then
    local pos = vim.api.nvim_win_get_cursor(0)
    return { pos[1], pos[2] }
  end

  local win = vim.fn.bufwinid(bufnr)
  if win == -1 then
    return { 1, 0 }
  end
  local pos = vim.api.nvim_win_get_cursor(win)
  return { pos[1], pos[2] }
end

local function normalize_date(date)
  local normalized = trim(date):gsub("/", "-")
  if normalized:match("^%d%d%d%d%-%d%d%-%d%d$") then
    return normalized
  end
end

local function next_day(date)
  local year, month, day = date:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)$")
  if not year then
    return nil
  end

  local timestamp = os.time({
    year = tonumber(year),
    month = tonumber(month),
    day = tonumber(day),
    hour = 12,
  })

  if not timestamp then
    return nil
  end

  return os.date("%Y-%m-%d", timestamp + 86400)
end

local function parse_header(line)
  if not line then
    return nil
  end

  local primary, secondary, rest = line:match("^(%d[%d%-%./]+)%s*(=?[%d%-%./]*)%s*(.*)$")
  if not primary then
    return nil
  end

  rest = trim(rest)
  rest = rest:gsub("^[*!]%s*", "")
  rest = rest:gsub("^%b()%s*", "")

  return {
    date = normalize_date(primary),
    date2 = normalize_date((secondary or ""):gsub("^=", "")),
    description = trim(rest),
  }
end

local function parse_posting_account(line)
  if not line or line:match("^%s*[%*%!;#]") then
    return nil
  end

  local account = line:match("^%s+(.+)%s%s+[^%s].*$")
  if not account then
    return nil
  end

  return trim(account)
end

local function account_token_under_cursor(line, col)
  if not line or line == "" then
    return nil
  end

  local idx = col + 1
  if idx < 1 or idx > #line + 1 then
    return nil
  end

  local allowed = "[%w:_%-]"
  local start_col = idx
  local end_col = idx

  while start_col > 1 and line:sub(start_col - 1, start_col - 1):match(allowed) do
    start_col = start_col - 1
  end

  while end_col <= #line and line:sub(end_col, end_col):match(allowed) do
    end_col = end_col + 1
  end

  local token = line:sub(start_col, end_col - 1)
  if token:find(":") then
    return token
  end
end

local function find_transaction_context(bufnr)
  local lines = get_lines(bufnr)
  local row = cursor_pos(bufnr)[1]
  local header_line
  local header_index

  for index = row, 1, -1 do
    local line = lines[index]
    if trim(line) == "" and index ~= row then
      break
    end
    if parse_header(line) then
      header_line = line
      header_index = index
      break
    end
  end

  if not header_line then
    return nil
  end

  local parsed_header = parse_header(header_line)
  local last_line = header_index
  local first_account
  local current_account

  for index = header_index + 1, #lines do
    local line = lines[index]
    if trim(line) == "" then
      break
    end
    last_line = index
    local account = parse_posting_account(line)
    if account and not first_account then
      first_account = account
    end
    if index == row and account then
      current_account = account
    end
  end

  return {
    start_line = header_index,
    end_line = last_line,
    header = parsed_header,
    account = current_account or first_account,
  }
end

local function find_rules_source(bufnr)
  local lines = get_lines(bufnr)
  local root = M.find_root(bufnr)

  for _, line in ipairs(lines) do
    local source = line:match("^#%s*Source:%s*(.+)$")
    if source then
      local candidate = trim(source)
      if candidate ~= "" then
        if vim.fn.filereadable(candidate) == 1 then
          return candidate
        end

        local rooted = vim.fs.joinpath(root, candidate)
        if vim.fn.filereadable(rooted) == 1 then
          return rooted
        end
      end
    end
  end
end

local function find_rules_account(bufnr)
  for _, line in ipairs(get_lines(bufnr)) do
    local account = line:match("^account1%s+(.+)$")
    if account then
      return trim(account)
    end
  end
end

local function cache_key(bufnr)
  return M.find_root(bufnr)
end

local function get_last_args(cmd, bufnr)
  local project = cache_key(bufnr)
  return last_args[project] and last_args[project][cmd] or nil
end

local function set_last_args(cmd, value, bufnr)
  local project = cache_key(bufnr)
  last_args[project] = last_args[project] or {}
  last_args[project][cmd] = value
end

local function join_args(parts)
  return table.concat(vim.tbl_filter(function(item)
    return item and item ~= ""
  end, parts), " ")
end

local function context_args_from_transaction(context, include_account)
  if not context or not context.header then
    return nil
  end

  local parts = {}
  if include_account and context.account then
    table.insert(parts, shellescape(context.account))
  end
  if context.header.description ~= "" then
    table.insert(parts, shellescape("desc:" .. context.header.description))
  end
  if context.header.date then
    table.insert(parts, "-b " .. context.header.date)
    local end_date = next_day(context.header.date)
    if end_date then
      table.insert(parts, "-e " .. end_date)
    end
  end
  return join_args(parts)
end

function M.default_register_args(bufnr)
  if is_rules_buffer(bufnr) then
    return find_rules_account(bufnr) or get_last_args("reg", bufnr) or ""
  end

  local row, col = unpack(cursor_pos(bufnr))
  local line = get_lines(bufnr)[row] or ""
  local token = account_token_under_cursor(line, col)
  if token then
    return token
  end

  local context = find_transaction_context(bufnr)
  if context and context.account then
    return context.account
  end

  return get_last_args("reg", bufnr) or ""
end

function M.default_print_args(bufnr)
  if is_rules_buffer(bufnr) then
    local source = find_rules_source(bufnr)
    local rules_file = bufname(bufnr)
    local parts = { "--rules-file", shellescape(rules_file) }
    if source then
      table.insert(parts, "-f")
      table.insert(parts, shellescape(source))
    end
    return join_args(parts)
  end

  local row, col = unpack(cursor_pos(bufnr))
  local line = get_lines(bufnr)[row] or ""
  local token = account_token_under_cursor(line, col)
  local context = find_transaction_context(bufnr)
  local args = context_args_from_transaction(context, true)

  if token and not (args or ""):find(token, 1, true) then
    args = join_args({ shellescape(token), args })
  end

  return args ~= "" and args or get_last_args("print", bufnr) or ""
end

local function build_command(args, bufnr)
  local bin = M.binary()
  if not bin then
    notify("`hledger` is not available in PATH", vim.log.levels.ERROR)
    return nil
  end

  local root = M.find_root(bufnr)
  local cmd = { "cd", shellescape(root), "&&" }

  if vim.fn.executable("direnv") == 1 and vim.fn.filereadable(vim.fs.joinpath(root, ".envrc")) == 1 then
    table.insert(cmd, "direnv")
    table.insert(cmd, "exec")
    table.insert(cmd, ".")
  end

  table.insert(cmd, shellescape(bin))

  if not (vim.fn.executable("direnv") == 1 and vim.fn.filereadable(vim.fs.joinpath(root, ".envrc")) == 1)
    and not has_explicit_input(args)
  then
    local main_file = M.find_main_file(bufnr)
    if main_file then
      table.insert(cmd, "-f")
      table.insert(cmd, shellescape(main_file))
    end
  end

  if args and args ~= "" then
    table.insert(cmd, args)
  end

  return table.concat(cmd, " ")
end

local function build_job_spec(parts, bufnr, opts)
  local bin = M.binary()
  if not bin then
    notify("`hledger` is not available in PATH", vim.log.levels.ERROR)
    return nil
  end

  bufnr = normalize_bufnr(bufnr)
  opts = opts or {}

  local root = M.find_root(bufnr)
  local use_direnv = vim.fn.executable("direnv") == 1 and vim.fn.filereadable(vim.fs.joinpath(root, ".envrc")) == 1
  local cmd = use_direnv and { "direnv", "exec", ".", bin } or { bin }

  if not use_direnv and not has_explicit_input_parts(parts) then
    local main_file = M.find_main_file(bufnr)
    if main_file then
      vim.list_extend(cmd, { "-f", main_file })
    end
  end

  vim.list_extend(cmd, opts.common_flags or {})
  vim.list_extend(cmd, parts or {})

  return {
    cmd = cmd,
    cwd = root,
  }
end

local function run_system(spec)
  local result = vim.system(spec.cmd, {
    cwd = spec.cwd,
    text = true,
  }):wait()

  if result.code ~= 0 then
    local message = trim(result.stderr ~= "" and result.stderr or result.stdout)
    notify(message ~= "" and message or "hledger command failed", vim.log.levels.ERROR)
    return nil
  end

  return result
end

local function open_float(cmd)
  local width = math.min(math.floor(vim.o.columns * 0.9), 160)
  local height = math.min(math.floor(vim.o.lines * 0.8), 40)
  local row = math.floor((vim.o.lines - height) / 2 - 1)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "terminal"

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(row, 0),
    col = math.max(col, 0),
    style = "minimal",
    border = "rounded",
    title = " hledger ",
    title_pos = "center",
  })

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].winfixbuf = true

  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, silent = true, desc = "Close hledger window" })

  vim.keymap.set("t", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, silent = true, desc = "Close hledger window" })

  vim.fn.termopen({ "zsh", "-lc", cmd }, {
    on_exit = function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.schedule(function()
          if vim.api.nvim_buf_is_valid(buf) then
            vim.bo[buf].modifiable = false
            if vim.api.nvim_win_is_valid(win) and vim.api.nvim_get_current_win() == win then
              vim.cmd("stopinsert")
            end
          end
        end)
      end
    end,
  })
end

local function open_float_with_syntax(args, syntax, bufnr)
  bufnr = normalize_bufnr(bufnr)
  local spec = build_job_spec(vim.split("--color=never " .. args, "%s+"), bufnr)
  if not spec then
    return
  end

  local result = run_system(spec)
  if not result then
    return
  end

  local lines = vim.split(trim(result.stdout or ""), "\n")
  if #lines == 0 then
    notify("No output from hledger", vim.log.levels.WARN)
    return
  end

  local max_line = 0
  for _, line in ipairs(lines) do
    max_line = math.max(max_line, vim.fn.strdisplaywidth(line))
  end

  local width = math.min(math.max(max_line + 2, 40), math.floor(vim.o.columns * 0.9))
  local height = math.min(#lines + 1, math.floor(vim.o.lines * 0.8))
  local row = math.floor((vim.o.lines - height) / 2 - 1)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.bo[buf].syntax = syntax

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.max(row, 0),
    col = math.max(col, 0),
    style = "minimal",
    border = "rounded",
    title = " hledger ",
    title_pos = "center",
  })

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = true

  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, silent = true, desc = "Close hledger window" })
end

local function list_accounts(bufnr)
  local spec = build_job_spec({ "--color=never", "accounts", "--flat" }, bufnr)
  if not spec then
    return {}
  end

  local result = run_system(spec)
  if not result then
    return {}
  end

  local lines = vim.split(trim(result.stdout or ""), "\n", { trimempty = true })
  return vim.tbl_filter(function(line)
    return trim(line) ~= ""
  end, lines)
end

local function picker_account_query(bufnr)
  if is_rules_buffer(bufnr) then
    return find_rules_account(bufnr) or get_last_args("reg", bufnr) or ""
  end

  local row, col = unpack(cursor_pos(bufnr))
  local line = get_lines(bufnr)[row] or ""
  local token = account_token_under_cursor(line, col)
  if token then
    return token
  end

  local context = find_transaction_context(bufnr)
  if context and context.account then
    return context.account
  end

  return get_last_args("reg", bufnr) or ""
end

local function preview_command(ctx)
  local preview = require("snacks.picker.preview")
  local item = ctx.item
  if not item or not item.account then
    return preview.none(ctx)
  end

  local width = vim.api.nvim_win_get_width(ctx.win)
  local spec = build_job_spec({
    "--color=never",
    "-w",
    tostring(width),
    item.subcommand,
    item.account,
  }, item.bufnr)
  if not spec then
    return preview.none(ctx)
  end

  ctx.preview:set_title(item.preview_title or (item.subcommand .. " " .. item.account))
  local job = preview.cmd(spec.cmd, ctx, {
    cwd = spec.cwd,
    ft = "hledger_preview",
  })
  -- preview.cmd skips highlight when previewers.diff.style == "fancy",
  -- so apply hledger_preview syntax directly on the preview buffer.
  vim.bo[ctx.preview.win.buf].syntax = "hledger_preview"
  return job
end

local function open_picker(subcommand, title, bufnr)
  bufnr = normalize_bufnr(bufnr)

  local ok, snacks = pcall(require, "snacks")
  if not ok then
    notify("Snacks picker is not available", vim.log.levels.ERROR)
    return
  end

  local accounts = list_accounts(bufnr)
  if #accounts == 0 then
    notify("No hledger accounts found", vim.log.levels.WARN)
    return
  end

  local items = vim.tbl_map(function(account)
    return {
      text = account,
      account = account,
      bufnr = bufnr,
      subcommand = subcommand,
      preview_title = subcommand .. " " .. account,
    }
  end, accounts)

  snacks.picker({
    title = title,
    items = items,
    format = "text",
    preview = preview_command,
    search = picker_account_query(bufnr),
    confirm = function(picker, item)
      picker:close()
      if not item or not item.account then
        return
      end
      set_last_args(subcommand, item.account, bufnr)
      M.run(subcommand .. " " .. shellescape(item.account), bufnr)
    end,
    matcher = {
      fuzzy = true,
      smartcase = true,
      ignorecase = true,
    },
    layout = "default",
  })
end

function M.command(args, bufnr)
  return build_command(args, bufnr)
end

function M.run(args, bufnr)
  local cmd = build_command(args, bufnr)
  if not cmd then
    return
  end

  open_float(cmd)
end

function M.run_report(args, syntax, bufnr)
  open_float_with_syntax(args, syntax or "hledgerreport", bufnr)
end

local function prompt_and_run(base_cmd, prompt, default, bufnr)
  bufnr = normalize_bufnr(bufnr)

  vim.fn.inputsave()
  local ok, input = pcall(vim.fn.input, prompt, default or "")
  vim.fn.inputrestore()

  if not ok or input == nil then
    return
  end

  local trimmed = trim(input)
  set_last_args(base_cmd, trimmed, bufnr)
  local args = base_cmd
  if trimmed ~= "" then
    args = args .. " " .. trimmed
  end
  M.run(args, bufnr)
end

function M.print_prompt(bufnr)
  prompt_and_run("print", "hledger print args: ", M.default_print_args(bufnr), bufnr)
end

function M.register_prompt(bufnr)
  prompt_and_run("reg", "hledger reg args: ", M.default_register_args(bufnr), bufnr)
end

function M.print_picker(bufnr)
  open_picker("print", "hledger Print Accounts", bufnr)
end

function M.register_picker(bufnr)
  open_picker("reg", "hledger Register Accounts", bufnr)
end

function M.aregister_picker(bufnr)
  open_picker("areg", "hledger Account Register", bufnr)
end

function M.print_current(bufnr)
  local args = trim(M.default_print_args(bufnr))
  if args == "" then
    notify("No print context found at the cursor", vim.log.levels.WARN)
    return
  end
  set_last_args("print", args, bufnr)
  M.run("print " .. args, bufnr)
end

function M.register_current(bufnr)
  local args = trim(M.default_register_args(bufnr))
  if args == "" then
    notify("No register context found at the cursor", vim.log.levels.WARN)
    return
  end
  set_last_args("reg", args, bufnr)
  M.run("reg " .. args, bufnr)
end

return M
