
if exists("g:loaded_lily") || &cp
  finish
endif
let g:loaded_lily = 1

" unite custom action
if exists("*unite#custom#action")
    let my_lily = {
    \ 'is_selectable' : 0,
    \ }
    function! my_lily.func(candidates)
        let pathDir = a:candidates.action__path . '/'

        " set path, etc.
        exe 'setlocal path=' . pathDir . '**'
        exe 'lcd `=pathDir`' 
        call lily#ui#Show()
    endfunction
    call unite#custom#action('directory', 'lily', my_lily)
    unlet my_lily
endif

" :Lily
command -nargs=0 Lily call lily#ui#Show()
