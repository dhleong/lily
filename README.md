lily
====

More elegant Git(hub) interactions in Vim

## Features:

- Fancy issue omni-completion (type the name and tab 
    complete the number)
- @mention omni-completion
- Issue-viewing UI, with async loading of issues, comments
    - Async requires `+python` and `v:servername`
- [unite.vim](https://github.com/Shougo/unite.vim) action to open the UI

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

![lily-complete-demo](https://cloud.githubusercontent.com/assets/816150/12022022/d9516fae-ad59-11e5-993e-5773312fb1ff.gif)

## Ideas

Some ways to spice up your life with lily

### Search for a project to open with lily via Unite

```vim
" Prepare a list of dirs that hold your project dirs:
let g:ProjectParentPaths = [
    \'/Users/dhleong/git/',
]

" prepare the unite command:
let g:UniteProjects = join(map(copy(g:ProjectParentPaths), "'directory:' . v:val"))
execute 'nnoremap <silent> <leader>y :Unite ' . g:UniteProjects .
    \ ' -start-insert -sync -unique -hide-source-names ' .
    \ ' -default-action=lily<cr>'

```
