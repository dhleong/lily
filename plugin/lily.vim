
if exists("g:loaded_lily") || &cp
  finish
endif
let g:loaded_lily = 1

" unite custom action
let my_lily = {
\ 'is_selectable' : 0,
\ }
function! my_lily.func(candidates)
    let pathDir = a:candidates.word . '/'

    " set path, etc.
    exe 'set path=' . pathDir . '**'
    exe 'lcd `=pathDir`' 
    call lily#ui#Show()
endfunction
call unite#custom#action('directory', 'lily', my_lily)
unlet my_lily

" :Lily
command -nargs=0 Lily
    \ call lily#ui#Show()
