-- Enhanced LSP references: full UI with icons/paths + enriched line content.
-- Grep references: compact "file:line: content" format using the same finder/enrichment.
local M = {}

-- Enhanced format function for LSP references
local function format_enhanced_reference(item, picker)
  ---@type snacks.picker.Highlight[]
  local ret = {}
  
  -- Add file icon and name
  if item.file then
    local filename = vim.fn.fnamemodify(item.file, ":t")
    local dir = vim.fn.fnamemodify(item.file, ":h:t")
    
    -- File icon
    if picker.opts.icons.files.enabled ~= false then
      local icon, hl = Snacks.util.icon(filename, "file")
      icon = Snacks.picker.util.align(icon, 2)
      ret[#ret + 1] = { icon, hl, virtual = true }
    end
    
    -- Filename
    ret[#ret + 1] = { filename, "SnacksPickerFile", field = "file" }
    
    -- Directory (dimmed, only if not current)
    if dir and dir ~= "." then
      ret[#ret + 1] = { " " .. dir, "SnacksPickerDir", field = "file" }
    end
    
    -- Line number
    if item.pos and item.pos[1] then
      ret[#ret + 1] = { ":" .. item.pos[1], "SnacksPickerLineNr" }
      ret[#ret + 1] = { " " }
    end
  end
  
  -- Add syntax highlighted line content
  if item.line then
    Snacks.picker.highlight.format(item, item.line, ret)
    ret[#ret + 1] = { " " }
  end
  
  return ret
end

-- Enhanced references function
function M.enhanced_references(opts)
  opts = opts or {}
  
  -- Start with the built-in lsp_references configuration
  local config = vim.tbl_deep_extend("force", {}, Snacks.picker.config.get().sources.lsp_references or {})
  
  -- Override the format
  config.format = format_enhanced_reference
  
  -- Enhance the finder
  local original_finder = config.finder
  if type(original_finder) == "string" then
    original_finder = require("snacks.picker.source.lsp").references
  end
  
  config.finder = function(finder_opts, ctx)
    local base_finder = original_finder(finder_opts, ctx)
    
    return function(cb)
      local enhanced_cb = function(item)
        if item and item.file and item.pos then
          local line_num = item.pos[1]
          local file_buf = item.buf
          
          -- Get better line content from loaded buffer
          if file_buf and vim.api.nvim_buf_is_loaded(file_buf) then
            local lines = vim.api.nvim_buf_get_lines(file_buf, line_num - 1, line_num, false)
            if lines[1] then
              item.line = lines[1]:gsub("^%s*", "")
              -- Adjust column position after trimming
              local original_line = lines[1]
              local trimmed_start = original_line:find("%S") or 1
              local original_col = item.pos[2] or 0
              item.pos[2] = math.max(0, original_col - (trimmed_start - 1))
            end
          elseif not item.line or item.line:match("^%s*$") then
            -- Fallback: read from file
            local ok, file_lines = pcall(vim.fn.readfile, item.file, "", line_num)
            if ok and file_lines and file_lines[line_num] then
              item.line = file_lines[line_num]:gsub("^%s*", "")
            end
          end
          
          -- Ensure we have some content
          if not item.line or item.line == "" then
            item.line = "<no content>"
          end
        end
        cb(item)
      end
      
      base_finder(enhanced_cb)
    end
  end
  
  -- Merge with user options
  config = vim.tbl_deep_extend("force", config, opts)
  
  return Snacks.picker(config)
end

-- Grep-style references (compact format)
function M.grep_references(opts)
  opts = opts or {}
  opts.format = function(item, picker)
    local ret = {}
    
    if item.file and item.pos then
      local filename = vim.fn.fnamemodify(item.file, ":~:.")
      local line_num = item.pos[1]
      
      -- Format: "file:line: content" (like grep)
      ret[#ret + 1] = { filename, "SnacksPickerFile" }
      ret[#ret + 1] = { ":", "SnacksPickerDelim" }
      ret[#ret + 1] = { tostring(line_num), "SnacksPickerLineNr" }
      ret[#ret + 1] = { ":", "SnacksPickerDelim" }
      ret[#ret + 1] = { " " }
      
      if item.line then
        Snacks.picker.highlight.format(item, item.line, ret)
      end
    end
    
    return ret
  end
  
  return M.enhanced_references(opts)
end

return M
