local M = {}

local config = require('blink.indent.config')
local utils = require('blink.indent.utils')

M.cache = utils.make_buffer_cache()

--- @param winnr integer
--- @param bufnr integer
--- @param ns integer
--- @param indent_levels table<integer, integer>
--- @param scope_range blink.indent.ScopeRange
--- @param range blink.indent.ParseRange
function M.draw(winnr, bufnr, ns, indent_levels, scope_range, range)
  local cache_entry = M.cache[bufnr]
  if
    cache_entry ~= nil
    and cache_entry.start_line == scope_range.start_line
    and cache_entry.end_line == scope_range.end_line
    and cache_entry.indent_level == scope_range.indent_level
    and range.horizontal_offset == cache_entry.horizontal_offset
  then
    return
  end
  M.cache[bufnr] = {
    start_line = scope_range.start_line,
    end_line = scope_range.end_line,
    indent_level = scope_range.indent_level,
    horizontal_offset = range.horizontal_offset,
  }

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  local indent_level = scope_range.indent_level
  if indent_level == 0 then return end

  local win_col = (indent_level - 1) * utils.get_shiftwidth(bufnr) - range.horizontal_offset
  if win_col < 0 then return end

  local breakindent = utils.get_breakindent(winnr)
  local symbol = config.scope.char
  local hl_group = utils.get_rainbow_hl(indent_level - 1, config.scope.highlights)

  for i = scope_range.start_line, scope_range.end_line do
    local virt_text = M.get_scope_symbol(bufnr, i, scope_range, win_col, symbol)

    vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
      virt_text = { { virt_text, hl_group } },
      virt_text_pos = 'overlay',
      virt_text_win_col = win_col,
      virt_text_repeat_linebreak = breakindent,
      hl_mode = 'combine',
      priority = config.scope.priority,
    })
  end

  if config.scope.underline.enabled then M.draw_underline(bufnr, ns, indent_levels, scope_range) end
end

--- @param bufnr integer
--- @param line_number integer
--- @param scope_range blink.indent.ScopeRange
--- @param win_col integer
--- @param symbol string
--- @return string
function M.get_scope_symbol(bufnr, line_number, scope_range, win_col, symbol)
  if line_number == scope_range.start_line then return M.get_scope_start_symbol(bufnr, line_number, win_col, symbol) end
  if line_number == scope_range.end_line then return M.get_scope_end_symbol(bufnr, line_number, win_col, symbol) end
  return symbol
end

--- @param bufnr integer
--- @param line_number integer
--- @param win_col integer
--- @param symbol string
--- @return string
function M.get_scope_start_symbol(bufnr, line_number, win_col, symbol)
  local right_arrow = config.scope.chars.right_arrow
  local top = config.scope.chars.top or symbol
  if right_arrow == nil or right_arrow == '' then return top end

  local shiftwidth = utils.get_shiftwidth(bufnr)
  local line = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1] or ''
  local whitespace_chars = line:match('^%s*') or ''
  local whitespace_width = whitespace_chars:find('\t') ~= nil
      and whitespace_chars:gsub('\t', (' '):rep(shiftwidth)):len()
    or whitespace_chars:len()
  local arrow_width = whitespace_width - win_col - 1

  if arrow_width <= 0 then return top end
  return top .. right_arrow:rep(arrow_width)
end

--- @param bufnr integer
--- @param line_number integer
--- @param win_col integer
--- @param symbol string
--- @return string
function M.get_scope_end_symbol(bufnr, line_number, win_col, symbol)
  local bottom_right_arrow = config.scope.chars.bottom_right_arrow
  local bottom = config.scope.chars.bottom or symbol
  if bottom_right_arrow == nil or bottom_right_arrow == '' then return bottom end

  local shiftwidth = utils.get_shiftwidth(bufnr)
  local line = vim.api.nvim_buf_get_lines(bufnr, line_number - 1, line_number, false)[1] or ''
  local whitespace_chars = line:match('^%s*') or ''
  local whitespace_width = whitespace_chars:find('\t') ~= nil
      and whitespace_chars:gsub('\t', (' '):rep(shiftwidth)):len()
    or whitespace_chars:len()
  local arrow_width = whitespace_width - win_col - 1

  if arrow_width <= 0 then return bottom end
  return bottom .. bottom_right_arrow:rep(arrow_width)
end

function M.draw_underline(bufnr, ns, indent_levels, scope_range)
  local indent_level = scope_range.indent_level
  local previous_line_indent_level = indent_levels[scope_range.start_line - 1]

  if previous_line_indent_level == nil or previous_line_indent_level >= indent_level then return end
  local line = vim.api.nvim_buf_get_lines(bufnr, scope_range.start_line - 2, scope_range.start_line - 1, false)[1]
  local whitespace_chars = line:match('^%s*')
  vim.hl.range(
    bufnr,
    ns,
    utils.get_rainbow_hl(previous_line_indent_level, config.scope.underline.highlights),
    { scope_range.start_line - 2, #whitespace_chars },
    { scope_range.start_line - 2, -1 }
  )
end

return M
