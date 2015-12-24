lily
====

More elegant Git(hub) interactions in Vim

## Features:

- Fancy issue omni-completion (type the name and tab 
    complete the number)
- @mention omni-completion

## Dependencies:

- [vim-fugitive](https://github.com/tpope/vim-fugitive)
- [hubr](https://github.com/dhleong/hubr)

## Setup

The easiest way is with [Plug](https://github.com/junegunn/vim-plug).
You'll also need to install and set up the dependencies.

```vim
Plug 'tpope/vim-fugitive'
Plug 'dhleong/hubr'
Plug 'dhleong/lily'
```

Completion works best if you also use [YouCompleteMe](https://github.com/Valloric/YouCompleteMe)

## Demos

Issue completion by name:

![lily-issues-complete](https://cloud.githubusercontent.com/assets/816150/11995935/609850b2-aa27-11e5-87f2-1a8a026c1f62.gif)

