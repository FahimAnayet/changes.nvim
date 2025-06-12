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
  
  if not original_lines or not current_lines then
    return changes
  end
  
  -- Simple line-by-line comparison for now
  -- This is more reliable than external diff command
  local max_lines = math.max(#original_lines, #current_lines)
  
  for i = 1, max_lines do
    local original_line = original_lines[i] or ''
    local current_line = current_lines[i] or ''
    
    if i > #original_lines then
      -- Line was added
      changes[i] = 'add'
    elseif i > #current_lines then
      -- Line was deleted (mark the previous line)
      if i > 1 then
        changes[i - 1] = 'delete'
      end
    elseif original_line ~= current_line then
      -- Line was modified
      changes[i] = 'modified'
    end
  end
  
  -- Remove any invalid line numbers (should be >= 1)
  local valid_changes = {}
  for line_num, change_type in pairs(changes) do
    if line_num >= 1 and line_num <= #current_lines then
      valid_changes[line_num] = change_type
    end
  end
  
  return valid_changes
end

-- Place signs for changes
local function place_signs(bufnr, changes)
  -- Clear existing signs for this group and buffer
  pcall(vim.fn.sign_unplace, state.sign_group, { buffer = bufnr })
  
  for line_num, change_type in pairs(changes) do
    local sign_name
    if change_type == 'add' then
      sign_name = 'ChangesAdd'
    elseif change_type == 'delete' then
      sign_name = 'ChangesDelete'
    else
      sign_name = 'ChangesModified'
    end
    
    -- Use pcall to handle any sign placement errors gracefully
    local ok, err = pcall(vim.fn.sign_place, 0, state.sign_group, sign_name, bufnr, {
      lnum = line_num,
      priority = 10
    })
    
    if not ok then
      -- If sign placement fails, try without priority (for older Vim versions)
      pcall(vim.fn.sign_place, 0, state.sign_group, sign_name, bufnr, { lnum = line_num })
    end
  end
end

-- Update changes for a buffer
local function update_changes(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if not state.enabled_buffers[bufnr] then
    return
  end
  
  -- Check if buffer is valid
  if not vim.api.nvim_buf_is_valid(bufnr) then
    M.disable(bufnr)
    return
  end
  
  local ok, current_lines = pcall(vim.api.nvim_buf_get_lines, bufnr, 0, -1, false)
  if not ok then
    return
  end
  
  local original_lines = state.original_content[bufnr]
  
  if not original_lines then
    original_lines = get_original_content(bufnr)
    if original_lines then
      state.original_content[bufnr] = original_lines
    else
      -- No original content available, can't show changes
      return
    end
  end
  
  local changes = calculate_diff(original_lines, current_lines)
  
  -- Only place signs if we have valid changes
  if next(changes) then
    place_signs(bufnr, changes)
  else
    -- Clear signs if no changes
    pcall(vim.fn.sign_unplace, state.sign_group, { buffer = bufnr })
  end
end

-- Enable changes tracking for buffer
function M.enable(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if state.enabled_buffers[bufnr] then
    return
  end
  
  -- Make sure signs are initialized
  init_signs()
  
  state.enabled_buffers[bufnr] = true
  
  -- Store original content
  local original_content = get_original_content(bufnr)
  if original_content then
    state.original_content[bufnr] = original_content
  else
    -- If we can't get original content, notify user and disable
    vim.notify('changes.nvim: Cannot read original file content for comparison', vim.log.levels.WARN)
    state.enabled_buffers[bufnr] = nil
    return
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
        vim.schedule(function()
          update_changes(bufnr)
        end)
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
  vim.schedule(function()
    update_changes(bufnr)
  end)
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
