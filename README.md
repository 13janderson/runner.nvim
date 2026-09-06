## Concept
Vim has compiler features, see `:help compiler`, which work great.
This plugin adds file-by-file state on top of that workflow. It persists both the `makeprg` option and the `errorformat` option for each file locally, then adds a keymap, `<leader>mk` by default, which loads those options and runs `makeprg` in a dedicated Neovim terminal buffer.
The terminal opens in a horizontal split at the bottom without stealing focus from your current window. Background runs (`Make!` or the uppercase keymaps) open it only after the command exits. When a command finishes, its output is parsed with the buffer's `errorformat`, added to the quickfix list, and both panes are shown side by side.
The result of this is not having to constantly remember a particular command to run for a particular file, maybe its a unit test, maybe it's compilation step, etc. This should enable lower friction feedback loops within (Neo)vim.

`<C-r>` (normal mode) opens a Telescope picker over your shell history (fish, zsh, and bash formats are supported). Picking a command persists it as `makeprg` for the current file and runs it immediately. Without [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) installed, a `vim.ui.select` fallback is used.

# Install
Lazy:
```lua
return {
  '13janderson/runner.nvim',
  -- optionally override setup call
  -- if you want to change default keymap
  config = function()
    require 'state':setup({
      make = '<leader>mk'
    })
  end
}

```

`runner.nvim` provides `:Make[!] [arguments]`. `:Make` opens the terminal immediately; `:Make!` waits to open it until the command has finished. Both commands use the current buffer's `makeprg`.
