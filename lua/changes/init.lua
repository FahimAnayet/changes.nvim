-- changes.nvim - A Neovim plugin for displaying buffer changes
-- Lua port of chrisbra/changesPlugin

local M = {}

-- Default configuration
local config = {
  autocmd = true,
  vcs_check = false,
  vcs_system = '',
  diff_preview = false,
  respect_signcolumn = false,
  sign_text_utf8 = true,
  linehi_diff = false,
  use_icons = true,
  add_sign = '+',
  delete_sign = '-',
  modified_sign = '*',
  utf8_add_sign = '➕',
  utf8_delete_sign = '➖',
  utf8_modified_sign = '★',
}

-- State management
local state = {
  enabled_buffers = {},
  original_content = {},
  sign_group = 'changes_nvim',
  namespace = vim.api.nvim_create_namespace('changes_nvim'),
}

-- Sign definitions
local signs = {
  add = { name = 'ChangesAdd', text = '+', texthl = 'DiffAdd' },
  delete = { name = 'ChangesDelete', text = '-', texthl = 'DiffDelete' },
  modified = { name = 'ChangesModified', text = '*', texthl = 'DiffChange' },
}

-- Initialize signs
local function init_signs()
  for _, sign in pairs(signs) do
    if config.sign_text_utf8 then
      if sign.name == 'ChangesAdd' then
        sign.text = config.use_icons and config.utf8_add_sign or config.add_sign
      elseif sign.name == 'ChangesDelete' then
        sign.text = config.use_icons and config.utf8_delete_sign or config.delete_sign
      elseif sign.name == 'ChangesModified' then
        sign.text = config.use_icons and config.utf8_modified_sign or config.modified_sign
      end
    else
      if sign.name == 'ChangesAdd' then sign.text = config.add_sign
      elseif sign.name == 'ChangesDelete' then sign.text = config.delete_sign
      elseif sign.name == 'ChangesModified' then sign.text = config.modified_sign
      end
    end
    
    vim.fn.sign_define(sign.name, {
      text = sign.text,
      texthl = config.respect_signcolumn and 'SignColumn' or sign.texthl,
      linehl = config.linehi_diff and sign.texthl or '',
    })
  end
end

-- Get file content from VCS if enabled
local function get_vcs_content(filepath)
  if not config.vcs_check then
    return nil
  end
  
  local cmd
  local vcs_system = config.vcs_system
  
  -- Auto-detect VCS if not specified
  if vcs_system == '' then
    if vim.fn.isdirectory('.git') == 1 then
      vcs_system = 'git'
    elseif vim.fn.isdirectory('.hg') == 1 then
      vcs_system = 'hg'
    else
      -- No VCS found, return nil to fall back to file content
      return nil
    end
  end
  
  if vcs_system == 'git' then
    cmd = {'git', 'show', 'HEAD:' .. vim.fn.fnamemodify(filepath, ':.')}
  elseif vcs_system == 'hg' then
    cmd = {'hg', 'cat', '-r', '.', filepath}
  else
    return nil
  end
  
  local ok, result = pcall(function()
    return vim.system(cmd, { text = true }):wait()
  end)
  
  if ok and result.code == 0 then
    return vim.split(result.stdout, '\n')
  end
  return nil
end

-- Get original file content
local function get_original_content(bufnr)
  local filepath = vim.api.nvim_buf_get_name(bufnr)
  if filepath == '' then 
    -- For unnamed buffers, we can't compare changes
    return nil 
  end
  
  -- Try VCS first if enabled
  if config.vcs_check then
    local vcs_content = get_vcs_content(filepath)
    if vcs_content then
      return vcs_content
    end
    -- If VCS is enabled but fails, still fall back to file content
  end
  
  -- Use saved file content (works without any VCS)
  if vim.fn.filereadable(filepath) == 1 then
    local ok, content = pcall(vim.fn.readfile, filepath)
    if ok then
      return content
    end
  end
  
  return nil
end

-- Calculate diff between original and current content
local function calculate_diff(original_lines, current_lines)
  local changes = {}
  
  -- Use vim's diff algorithm
  local original_file = vim.fn.tempname()
  local current_file = vim.fn.tempname()
  
  vim.fn.writefile(original_lines or {}, original_file)
  vim.fn.writefile(current_lines, current_file)
  
  local diff_cmd = {'diff', '-u', original_file, current_file}
  local result = vim.system(diff_cmd, { text = true }):wait()
  
  -- Clean up temp files
  vim.fn.delete(original_file)
  vim.fn.delete(current_file)
  
  if result.stdout then
    local lines = vim.split(result.stdout, '\n')
    local current_line = 0
    
    for _, line in ipairs(lines) do
      if line:match('^@@') then
        local new_start = line:match('%+(%d+)')
        if new_start then
          current_line = tonumber(new_start)
        end
      elseif line:match('^%-') then
        -- Deleted line
        if current_line > 0 then
          changes[current_line] = 'delete'
        end
      elseif line:match('^%+') then
        -- Added line
        changes[current_line] = 'add'
        current_line = current_line + 1
      elseif line:match('^%s') then
        -- Unchanged line (context)
        current_line = current_line + 1
      end
    end
  end
  
  return changes
end

-- Place signs for changes
local function place_signs(bufnr, changes)
  -- Clear existing signs
  vim.fn.sign_unplace(state.sign_group, { buffer = bufnr })
  
  for line_num, change_type in pairs(changes) do
    local sign_name
    if change_type == 'add' then
      sign_name = 'ChangesAdd'
    elseif change_type == 'delete' then
      sign_name = 'ChangesDelete'
    else
      sign_name = 'ChangesModified'
    end
    
    vim.fn.sign_place(0, state.sign_group, sign_name, bufnr, {
      lnum = line_num,
      priority = 10
    })
  end
end

-- Update changes for a buffer
local function update_changes(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if not state.enabled_buffers[bufnr] then
    return
  end
  
  local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local original_lines = state.original_content[bufnr]
  
  if not original_lines then
    original_lines = get_original_content(bufnr)
    if original_lines then
      state.original_content[bufnr] = original_lines
    else
      return
    end
  end
  
  local changes = calculate_diff(original_lines, current_lines)
  place_signs(bufnr, changes)
end

-- Enable changes tracking for buffer
function M.enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if state.enabled_buffers[bufnr] then
    return
  end
  
  state.enabled_buffers[bufnr] = true
  
  -- Store original content
  local original_content = get_original_content(bufnr)
  if original_content then
    state.original_content[bufnr] = original_content
  end
  
  -- Set up autocommands for this buffer
  if config.autocmd then
    local group = vim.api.nvim_create_augroup('changes_nvim_' .. bufnr, { clear = true })
    
    vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
      buffer = bufnr,
      group = group,
      callback = function()
        vim.schedule(function()
          update_changes(bufnr)
        end)
      end,
    })
    
    vim.api.nvim_create_autocmd('BufWritePost', {
      buffer = bufnr,
      group = group,
      callback = function()
        -- Update original content after save
        local new_original = get_original_content(bufnr)
        if new_original then
          state.original_content[bufnr] = new_original
        end
        update_changes(bufnr)
      end,
    })
    
    vim.api.nvim_create_autocmd('BufDelete', {
      buffer = bufnr,
      group = group,
      callback = function()
        M.disable(bufnr)
      end,
    })
  end
  
  -- Initial update
  update_changes(bufnr)
end

-- Disable changes tracking for buffer
function M.disable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  state.enabled_buffers[bufnr] = nil
  state.original_content[bufnr] = nil
  
  -- Clear signs
  vim.fn.sign_unplace(state.sign_group, { buffer = bufnr })
  
  -- Clear autocommands
  local group_name = 'changes_nvim_' .. bufnr
  pcall(vim.api.nvim_del_augroup_by_name, group_name)
end

-- Toggle changes tracking
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if state.enabled_buffers[bufnr] then
    M.disable(bufnr)
  else
    M.enable(bufnr)
  end
end

-- Jump to next change
function M.next_change()
  local bufnr = vim.api.nvim_get_current_buf()
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  
  local signs = vim.fn.sign_getplaced(bufnr, { group = state.sign_group })[1]
  if not signs or not signs.signs then return end
  
  local next_line = nil
  for _, sign in ipairs(signs.signs) do
    if sign.lnum > current_line then
      if not next_line or sign.lnum < next_line then
        next_line = sign.lnum
      end
    end
  end
  
  -- Wrap to beginning if no next change found
  if not next_line and #signs.signs > 0 then
    next_line = signs.signs[1].lnum
  end
  
  if next_line then
    vim.api.nvim_win_set_cursor(0, { next_line, 0 })
  end
end

-- Jump to previous change
function M.prev_change()
  local bufnr = vim.api.nvim_get_current_buf()
  local current_line = vim.api.nvim_win_get_cursor(0)[1]
  
  local signs = vim.fn.sign_getplaced(bufnr, { group = state.sign_group })[1]
  if not signs or not signs.signs then return end
  
  local prev_line = nil
  for _, sign in ipairs(signs.signs) do
    if sign.lnum < current_line then
      if not prev_line or sign.lnum > prev_line then
        prev_line = sign.lnum
      end
    end
  end
  
  -- Wrap to end if no previous change found
  if not prev_line and #signs.signs > 0 then
    prev_line = signs.signs[#signs.signs].lnum
  end
  
  if prev_line then
    vim.api.nvim_win_set_cursor(0, { prev_line, 0 })
  end
end

-- Show changes in quickfix
function M.show_changes_qf()
  local bufnr = vim.api.nvim_get_current_buf()
  local signs = vim.fn.sign_getplaced(bufnr, { group = state.sign_group })[1]
  
  if not signs or not signs.signs then
    vim.notify('No changes found', vim.log.levels.INFO)
    return
  end
  
  local qf_list = {}
  local filename = vim.api.nvim_buf_get_name(bufnr)
  
  for _, sign in ipairs(signs.signs) do
    local line_content = vim.api.nvim_buf_get_lines(bufnr, sign.lnum - 1, sign.lnum, false)[1] or ''
    table.insert(qf_list, {
      bufnr = bufnr,
      filename = filename,
      lnum = sign.lnum,
      text = string.format('[%s] %s', sign.name:gsub('Changes', ''), line_content),
    })
  end
  
  vim.fn.setqflist(qf_list)
  vim.cmd('copen')
end

-- Show diff in split
function M.show_diff()
  local bufnr = vim.api.nvim_get_current_buf()
  local original_lines = state.original_content[bufnr]
  
  if not original_lines then
    vim.notify('No original content available', vim.log.levels.WARN)
    return
  end
  
  -- Create temporary buffer with original content
  local temp_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(temp_buf, 0, -1, false, original_lines)
  vim.api.nvim_buf_set_option(temp_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(temp_buf, 'bufhidden', 'wipe')
  
  -- Split and show diff
  vim.cmd('split')
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, temp_buf)
  vim.cmd('diffthis')
  vim.cmd('wincmd p')
  vim.cmd('diffthis')
end

-- Setup function
function M.setup(opts)
  config = vim.tbl_deep_extend('force', config, opts or {})
  
  init_signs()
  
  -- Create commands
  vim.api.nvim_create_user_command('ChangesEnable', function()
    M.enable()
  end, { desc = 'Enable changes tracking' })
  
  vim.api.nvim_create_user_command('ChangesDisable', function()
    M.disable()
  end, { desc = 'Disable changes tracking' })
  
  vim.api.nvim_create_user_command('ChangesToggle', function()
    M.toggle()
  end, { desc = 'Toggle changes tracking' })
  
  vim.api.nvim_create_user_command('ChangesShow', function()
    M.show_changes_qf()
  end, { desc = 'Show changes in quickfix' })
  
  vim.api.nvim_create_user_command('ChangesDiff', function()
    M.show_diff()
  end, { desc = 'Show diff in split' })
  
  -- Create keymaps (similar to original plugin)
  vim.keymap.set('n', ']h', M.next_change, { desc = 'Next change' })
  vim.keymap.set('n', '[h', M.prev_change, { desc = 'Previous change' })
end

return M
