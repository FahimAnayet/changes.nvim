local changes = require('changes')

-- Set up default configuration
changes.setup()

-- Define commands
vim.cmd([[command! -nargs=? -complete=file EnableChanges lua require('changes').enable(1, <q-args>)]])
vim.cmd([[command! DisableChanges lua require('changes').cleanup()]])
vim.cmd([[command! ToggleChangeView lua require('changes').toggle_view()]])

-- Set up autocommands
if changes.config.autocmd then
  vim.cmd([[
    augroup ChangesPlugin
      au!
      au VimEnter * lua require('changes').init()
    augroup END
  ]])
end

-- Set up mappings
if vim.fn.empty(vim.fn.maparg('[h')) ~= 0 then
  vim.keymap.set('n', '[h', function() return require('changes').move_to_next_change(false, vim.v.count1) end, {expr = true, silent = true})
end

if vim.fn.empty(vim.fn.maparg(']h')) ~= 0 then
  vim.keymap.set('n', ']h', function() return require('changes').move_to_next_change(true, vim.v.count1) end, {expr = true, silent = true})
end

-- Text-object: A hunk
if vim.fn.empty(vim.fn.maparg('ah', 'x')) ~= 0 then
  vim.keymap.set('x', 'ah', function() return require('changes').current_hunk() end, {expr = true, silent = true})
end

if vim.fn.empty(vim.fn.maparg('ah', 'o')) ~= 0 then
  vim.keymap.set('o', 'ah', ':norm Vah<CR>', {silent = true})
end
