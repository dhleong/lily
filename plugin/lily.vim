
if exists("g:loaded_lily") || &cp
  finish
endif
let g:loaded_lily = 1

" :Lily
command -nargs=0 Lily
    \ call lily#ui#Show()
