local changes = {}

-- Configuration
changes.config = {
  autocmd = true,
  vcs_check = false,
  vcs_system = nil,
  fast = true,
  sign_text_utf8 = false,
  use_icons = true,
  respect_signcolumn = false,
  linehi_diff = false,
  max_filesize = 0,
  grep_diff = false,
  diff_preview = false,
  sign_hi_style = 0,
  add_sign = '+',
  delete_sign = '-',
  modified_sign = '*',
  utf8_add_sign = '➕',
  utf8_delete_sign = '➖',
  utf8_modified_sign = '★'
}

-- State
changes.state = {
  msg = {},
  ignore = {},
  signs = {},
  old_signs = {},
  placed_signs = {},
  diff_out = vim.fn.tempname(),
  diff_in_cur = vim.fn.tempname(),
  diff_in_old = vim.fn.tempname(),
  jobid = 1,
  nodiff = false,
  changes_sign_hi_style = 0,
  precheck = false,
  changes_last_inserted_sign = nil,
  jobs = {}
}

-- VCS commands
changes.vcs_cat = {
  git = 'show :',
  bzr = 'cat ',
  cvs = '-q update -p ',
  darcs = '--show-contents ',
  fossil = 'finfo -p ',
  rcs = 'co -p ',
  svn = 'cat ',
  hg = 'cat ',
  mercurial = 'cat ',
  subversion = 'cat '
}

changes.vcs_diff = {
  git = ' diff -U0 --no-ext-diff --no-color ',
  hg = ' diff -U0 '
}

changes.vcs_apply = {
  git = ' apply --cached --unidiff-zero ',
  hg = ' import - '
}

-- Helper functions
local function store_message(msg)
  table.insert(changes.state.msg, msg)
end

local function warning_msg()
  if vim.o.verbose == 0 then return end
  if #changes.state.msg > 0 then
    vim.cmd('redraw!')
    vim.cmd('echohl WarningMsg')
    for _, m in ipairs(changes.state.msg) do
      vim.cmd(string.format('echomsg "Changes.nvim: %s"', m))
    end
    vim.cmd('echohl Normal')
    vim.v.errmsg = changes.state.msg[1]
    changes.state.msg = {}
  end
end

local function current_buffer_is_ignored()
  return changes.state.ignore[vim.fn.bufnr()] or false
end

local function ignore_current_buffer()
  changes.state.ignore[vim.fn.bufnr()] = true
end

local function unignore_current_buffer()
  changes.state.ignore[vim.fn.bufnr()] = nil
end

local function set_sign_column()
  if not changes.config.respect_signcolumn and vim.wo.signcolumn ~= 'yes' and vim.bo.buftype ~= 'terminal' then
    vim.wo.signcolumn = 'yes'
  end
end

-- Sign management
local function init_sign_def()
  local signs = {}
  local sign_hi = changes.state.changes_sign_hi_style
  
  local plus = changes.config.sign_text_utf8 and changes.config.utf8_add_sign or changes.config.add_sign
  local del = changes.config.sign_text_utf8 and changes.config.utf8_delete_sign or changes.config.delete_sign
  local mod = changes.config.sign_text_utf8 and changes.config.utf8_modified_sign or changes.config.modified_sign

  signs.add = {
    text = plus,
    texthl = sign_hi < 2 and "ChangesSignTextAdd" or "SignColumn",
    linehl = sign_hi > 0 and 'DiffAdd' or '',
    name = 'add'
  }

  signs.del = {
    text = del,
    texthl = sign_hi < 2 and "ChangesSignTextDel" or "SignColumn",
    linehl = sign_hi > 0 and 'DiffDelete' or '',
    name = 'del'
  }

  signs.cha = {
    text = mod,
    texthl = sign_hi < 2 and "ChangesSignTextCh" or "SignColumn",
    linehl = sign_hi > 0 and 'DiffChange' or '',
    name = 'cha'
  }

  signs.add_dummy = {
    text = plus,
    texthl = sign_hi < 2 and "ChangesSignTextDummyAdd" or "SignColumn",
    linehl = sign_hi > 0 and 'DiffAdd' or '',
    name = 'add_dummy'
  }

  signs.cha_dummy = {
    text = mod,
    texthl = sign_hi < 2 and "ChangesSignTextDummyCh" or "SignColumn",
    linehl = sign_hi > 0 and 'DiffChange' or '',
    name = 'cha_dummy'
  }

  -- Remove empty values
  for name, def in pairs(signs) do
    for k, v in pairs(def) do
      if v == '' then def[k] = nil end
    end
  end

  return signs
end

local function define_signs(undef)
  if undef then
    for name, _ in pairs(changes.state.signs) do
      vim.fn.sign_undefine(name)
    end
  end

  for name, def in pairs(changes.state.signs) do
    local ok, err = pcall(vim.fn.sign_define, name, def)
    if not ok then
      if string.find(err, "Can't read icons") then
        def.icon = nil
        vim.fn.sign_define(name, def)
      end
    end
  end
end

-- Diff functionality
local function get_diff(arg, file)
  if current_buffer_is_ignored() or vim.bo.buftype ~= '' or vim.fn.line2byte(vim.fn.line('$')) == -1 then
    store_message('Buffer is ignored')
    return
  end

  local _wsv = vim.fn.winsaveview()
  vim.bo.lz = true

  if not vim.fn.filereadable(vim.fn.bufname()) then
    store_message("You've opened a new file so viewing changes is disabled until the file is saved")
    return
  end

  if vim.fn.bufname() == '' then
    store_message("The buffer does not contain a name. Aborted!")
    return
  end

  if vim.bo.buftype ~= '' then
    store_message("Not generating diff for special buffer!")
    ignore_current_buffer()
    return
  end

  vim.b.diffhl = {add = {}, del = {}, cha = {}}

  if arg == 3 then
    -- Diff mode implementation
    -- Similar to the Vimscript version but in Lua
  else
    -- Parse diff output
    -- Similar to the Vimscript version but in Lua
  end

  vim.fn.winrestview(_wsv)
  warning_msg()
end

-- Main functions
function changes.setup(config)
  changes.config = vim.tbl_extend('force', changes.config, config or {})
end

function changes.init()
  changes.state.msg = {}
  
  -- Check preconditions
  if not vim.o.diff then
    store_message("Diff support not available in your Vim version.")
    return false
  end

  if not vim.o.signs then
    store_message("Sign Support not available in your Vim.")
    return false
  end

  if vim.fn.executable("diff") == 0 then
    store_message("No diff executable found")
    return false
  end

  -- Initialize signs
  changes.state.old_signs = changes.state.signs
  changes.state.signs = init_sign_def()
  
  if changes.state.old_signs ~= changes.state.signs and next(changes.state.old_signs) ~= nil then
    define_signs(true)
  end

  set_sign_column()
  
  if not vim.b.sign_prefix then
    vim.b.sign_prefix = vim.fn.bufnr()
  end

  return true
end

function changes.enable(arg, file)
  unignore_current_buffer()
  local ok, err = pcall(function()
    local savevar = changes.config.max_filesize
    changes.config.max_filesize = 0
    if changes.init() then
      if arg then
        -- Unplace all signs
      end
      get_diff(arg, file or '')
    end
    changes.config.max_filesize = savevar
  end)
  
  if not ok then
    warning_msg()
    changes.cleanup()
  end
end

function changes.cleanup()
  -- Unplace all signs
  -- Clean up state
  vim.b.changes_view_enabled = false
end

function changes.toggle_view()
  if vim.b.changes_view_enabled then
    -- Unplace signs
    vim.b.changes_view_enabled = false
    print("Hiding changes since last save")
  else
    if changes.init() then
      get_diff(1, '')
      vim.b.changes_view_enabled = true
      print("Showing changes since last save")
    else
      warning_msg()
      changes.cleanup()
    end
  end
end

-- Set up autocommands
local function setup_autocmds()
  vim.cmd([[
    augroup Changes
      autocmd!
      autocmd TextChanged,InsertLeave,FilterReadPost * lua require('changes').update_view()
      autocmd ColorScheme,GUIEnter * lua require('changes').init()
      autocmd FocusGained * lua require('changes').update_view(1)
      autocmd InsertEnter * lua require('changes').insert_sign_on_enter()
      autocmd BufWritePost,BufWinEnter * lua require('changes').update_view(1)
      autocmd VimLeave * lua require('changes').delete_temp_files()
    augroup END
  ]])
end

function changes.update_view(force)
  -- Implementation similar to Vimscript version
end

function changes.insert_sign_on_enter()
  -- Implementation similar to Vimscript version
end

function changes.delete_temp_files()
  -- Implementation similar to Vimscript version
end

-- Export public functions
changes.store_message = store_message
changes.warning_msg = warning_msg
changes.current_buffer_is_ignored = current_buffer_is_ignored
changes.ignore_current_buffer = ignore_current_buffer
changes.unignore_current_buffer = unignore_current_buffer

return changes
