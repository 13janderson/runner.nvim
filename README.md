## Concept
Vim has its compiler features, see `help compiler`, which work great. On top of this, we have [vim-dispatch](https://github.com/tpope/vim-dispatch) which provides a nice tmux integration on top of this - amongst other things.
This plugin builds on top of the compiler workflow and vim-dispatch to add a layer of state of a file by file basis. We persist both the makeprg option and the errorformat option for each file locally and add a keymap, <leader>mk by default, which loads these options for a file and then calls out to vim-dispatch. 
The result of this is not having to constantly remember a particular command to run for a particular file, maybe its a unit test, maybe it's compilation step, etc. This should enable lower friction feedback loops within (Neo)vim.

# Install

Lazy:
```lua
return {
  '13janderson/runner.nvim',
  dependencies = {
    'tpope/vim-dispatch'
  },
  -- optionally override setup call
  -- if you want to change default keymap
  config = function()
    require 'state':setup({
      make = '<leader>mk'
    })
  end
}

```
