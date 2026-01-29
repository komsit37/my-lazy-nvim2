local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Paste Image" })
end

local function is_macos()
  return vim.fn.has("mac") == 1
end

local function file_exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

local function compute_target_px()
  local default_max_w, default_max_h = 1600, 1200

  local ok, term = pcall(require, "image/utils/term")
  if not ok then
    return default_max_w, default_max_h
  end

  local size = term.get_size()
  local win_cols = vim.api.nvim_win_get_width(0)
  local win_rows = vim.api.nvim_win_get_height(0)

  if not size or size.cell_width <= 0 or size.cell_height <= 0 then
    return default_max_w, default_max_h
  end

  local max_w = math.floor(win_cols * size.cell_width * 0.9)
  local max_h = math.floor(win_rows * size.cell_height * 0.5)

  if max_w < 300 then max_w = default_max_w end
  if max_h < 200 then max_h = default_max_h end

  return max_w, max_h
end

local function next_number(dir, base, date)
  local esc_base = vim.pesc(base)
  local pat = "^" .. esc_base .. "_" .. date .. "_(%d%d)%.jpg$"
  local max_n = 0

  if vim.uv.fs_stat(dir) then
    for name, t in vim.fs.dir(dir) do
      if t == "file" then
        local n = name:match(pat)
        if n then
          max_n = math.max(max_n, tonumber(n))
        end
      end
    end
  end

  if max_n >= 99 then
    return nil, "Too many images for today (nn reached 99)"
  end

  return max_n + 1
end

local function insert_markdown_image_link(rel_path, alt)
  local line = string.format("![%s](%s)", alt or "", rel_path)
  vim.api.nvim_put({ line }, "l", true, true)
end

local function run(cmd, on_exit)
  vim.system(cmd, { text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        local stderr = (res.stderr or ""):gsub("%s+$", "")
        local stdout = (res.stdout or ""):gsub("%s+$", "")
        local details = stderr ~= "" and stderr or stdout
        on_exit(false, details ~= "" and details or ("exit code " .. tostring(res.code)))
        return
      end
      on_exit(true)
    end)
  end)
end

function M.paste_markdown_image()
  if vim.env.SSH_TTY or vim.env.SSH_CONNECTION or vim.env.SSH_CLIENT then
    notify("Clipboard image paste usually won't work over remote SSH. Paste locally or transfer the file.", vim.log.levels.WARN)
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local bufpath = vim.api.nvim_buf_get_name(bufnr)
  if bufpath == "" then
    notify("Current buffer has no file path. Save it first.", vim.log.levels.ERROR)
    return
  end

  local bufdir = vim.fn.fnamemodify(bufpath, ":p:h")
  local base = vim.fn.fnamemodify(bufpath, ":t:r")
  local base_for_file = base:gsub("%s+", "_")
  local date = os.date("%Y%m%d")

  local attachments_dir = bufdir .. "/attachments"
  ensure_dir(attachments_dir)

  local nn, nn_err = next_number(attachments_dir, base_for_file, date)
  if not nn then
    notify(nn_err or "Failed to pick filename", vim.log.levels.ERROR)
    return
  end

  local filename = string.format("%s_%s_%02d.jpg", base_for_file, date, nn)
  local outpath = attachments_dir .. "/" .. filename
  local relpath = "attachments/" .. filename

  if file_exists(outpath) then
    notify("Target already exists: " .. outpath, vim.log.levels.ERROR)
    return
  end

  if vim.fn.executable("magick") ~= 1 and vim.fn.executable("convert") ~= 1 then
    notify("ImageMagick not found (`magick`/`convert`). Install ImageMagick first.", vim.log.levels.ERROR)
    return
  end

  local tmp = vim.fn.tempname() .. ".png"

  local paste_cmd = nil
  if is_macos() then
    if vim.fn.executable("pngpaste") == 1 then
      paste_cmd = { "pngpaste", tmp }
    else
      -- Fallback: use AppleScript to write PNG clipboard data to tmp
      paste_cmd = {
        "osascript",
        "-e",
        ('set theFile to POSIX file "%s"'):format(tmp),
        "-e",
        "try",
        "-e",
        'set theImage to the clipboard as «class PNGf»',
        "-e",
        "on error",
        "-e",
        'error "Clipboard does not contain an image"',
        "-e",
        "end try",
        "-e",
        "set theFileRef to open for access theFile with write permission",
        "-e",
        "set eof of theFileRef to 0",
        "-e",
        "write theImage to theFileRef",
        "-e",
        "close access theFileRef",
      }
    end
  end

  if not paste_cmd then
    notify("Unsupported OS for clipboard image paste (needs macOS + pngpaste or osascript).", vim.log.levels.ERROR)
    return
  end

  notify("Pasting image from clipboard…")
  run(paste_cmd, function(ok_paste, paste_err)
    if not ok_paste then
      notify(
        "Failed to read clipboard image.\n"
          .. (paste_err or "")
          .. (is_macos() and "\nTip: install `pngpaste` with: brew install pngpaste" or ""),
        vim.log.levels.ERROR
      )
      return
    end

    if not file_exists(tmp) then
      notify("Clipboard paste did not produce an image file.", vim.log.levels.ERROR)
      return
    end

    local max_w, max_h = compute_target_px()
    local resize = string.format("%dx%d>", max_w, max_h)

    local magick = vim.fn.executable("magick") == 1 and "magick" or "convert"
    local convert_cmd = { magick, tmp, "-auto-orient", "-resize", resize, "-strip", "-quality", "85", outpath }

    notify("Resizing + saving…")
    run(convert_cmd, function(ok_convert, convert_err)
      pcall(vim.uv.fs_unlink, tmp)

      if not ok_convert then
        notify("Failed to convert/resize image:\n" .. (convert_err or ""), vim.log.levels.ERROR)
        return
      end

      insert_markdown_image_link(relpath, base)
      notify("Saved " .. relpath)
    end)
  end)
end

return M
