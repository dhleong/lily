"
" On-demand loading. Let's use the autoload folder and not slow down vim's
" startup procedure.
augroup lilyStart
  autocmd!
  autocmd BufEnter <buffer> call lily#Enable()
augroup END

