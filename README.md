# Shamelessly Stole from [Here](https://github.com/chrisbra/changesPlugin)

## Installation

### Using lazy.nvim

```lua
{
  'your-username/changes.nvim',
  config = function()
    require('changes').setup({
      -- Configuration options
      autocmd = true,
      vcs_check = false,
      vcs_system = '', -- 'git', 'hg', or '' for auto-detect
      sign_text_utf8 = true,
      use_icons = true,
      linehi_diff = false,
    })
  end,
  event = { 'BufReadPost', 'BufNewFile' },
}
```

### Using packer.nvim

```lua
use {
  'your-username/changes.nvim',
  config = function()
    require('changes').setup()
  end
}
```

## Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `autocmd` | `true` | Auto-update signs using TextChanged events |
| `vcs_check` | `false` | Check against VCS (git/hg) instead of saved file |
| `vcs_system` | `''` | VCS system to use ('git', 'hg', or '' for auto-detect) |
| `diff_preview` | `false` | Show diff in preview window |
| `respect_signcolumn` | `false` | Use SignColumn highlighting |
| `sign_text_utf8` | `true` | Use UTF-8 symbols for signs |
| `linehi_diff` | `false` | Highlight entire changed lines |
| `use_icons` | `true` | Use fancy Unicode icons |
| `add_sign` | `'+'` | Sign for added lines |
| `delete_sign` | `'-'` | Sign for deleted lines |
| `modified_sign` | `'*'` | Sign for modified lines |
| `utf8_add_sign` | `'➕'` | UTF-8 sign for added lines |
| `utf8_delete_sign` | `'➖'` | UTF-8 sign for deleted lines |
| `utf8_modified_sign` | `'★'` | UTF-8 sign for modified lines |

## Commands

| Command | Description |
|---------|-------------|
| `:ChangesEnable` | Enable changes tracking for current buffer |
| `:ChangesDisable` | Disable changes tracking for current buffer |
| `:ChangesToggle` | Toggle changes tracking for current buffer |
| `:ChangesShow` | Show all changes in quickfix window |
| `:ChangesDiff` | Open diff view in split window |

## Key Mappings

| Key | Mode | Action |
|-----|------|--------|
| `]h` | Normal | Jump to next change |
| `[h` | Normal | Jump to previous change |

## API Functions

```lua
local changes = require('changes')

-- Enable/disable for specific buffer
changes.enable(bufnr)   -- Enable for buffer (default: current)
changes.disable(bufnr)  -- Disable for buffer (default: current)
changes.toggle(bufnr)   -- Toggle for buffer (default: current)

-- Navigation
changes.next_change()   -- Jump to next change
changes.prev_change()   -- Jump to previous change

-- Views
changes.show_changes_qf()  -- Show changes in quickfix
changes.show_diff()        -- Show diff in split
```

## Features

- ✅ Visual indicators for added, modified, and deleted lines
- ✅ Git/Mercurial integration
- ✅ Automatic sign updates on text changes
- ✅ Jump between changes with `]h` and `[h`
- ✅ Quickfix integration
- ✅ Diff view in split window
- ✅ Customizable signs and colors
- ✅ UTF-8 and icon support
- ✅ Per-buffer enable/disable
- ✅ Async updates (using vim.schedule)

## Differences from Original Plugin

### Improvements:
- **Modern Lua API**: Uses Neovim's Lua API instead of VimScript
- **Better Performance**: Leverages Neovim's async capabilities
- **Cleaner Code**: More maintainable and extensible codebase
- **Better Git Integration**: Uses `vim.system()` for better subprocess handling
- **Namespace Support**: Uses proper namespaces for signs and highlights

### Removed Features:
- Some legacy Vim compatibility features
- Complex fold operations (can be added back if needed)
- Advanced diff highlighting modes

## Extending the Plugin

The plugin is designed to be extensible. You can:

1. **Add new VCS systems**: Extend the `get_vcs_content()` function
2. **Custom sign types**: Add new sign definitions
3. **Advanced diff algorithms**: Replace the diff calculation logic
4. **Additional views**: Add new ways to display changes

## Example Advanced Configuration

```lua
require('changes').setup({
  autocmd = true,
  vcs_check = true,
  vcs_system = 'git',
  sign_text_utf8 = false,  -- Use simple ASCII signs
  use_icons = false,
  linehi_diff = true,      -- Highlight entire lines
  
  -- Custom signs
  add_sign = '▎',
  delete_sign = '▎',
  modified_sign = '▎',
})

-- Custom keybindings
vim.keymap.set('n', '<leader>ce', '<cmd>ChangesEnable<cr>')
vim.keymap.set('n', '<leader>cd', '<cmd>ChangesDisable<cr>')
vim.keymap.set('n', '<leader>ct', '<cmd>ChangesToggle<cr>')
vim.keymap.set('n', '<leader>cs', '<cmd>ChangesShow<cr>')
vim.keymap.set('n', '<leader>cv', '<cmd>ChangesDiff<cr>')
```

This modern Lua implementation provides all the core functionality of the original changesPlugin.

> ### <span style='color: red;'>This will never update in future.</span>
