
let s:loaded = 0

let s:cwdir = expand("<sfile>:p:h")
let s:script_py = s:cwdir . '/async.py'

function! lily#async#Load() " {{{
    if s:loaded
        return
    endif

    if has('python')
      execute 'pyfile ' . fnameescape(s:script_py)
    elseif has('python3')
      execute 'py3file ' . fnameescape(s:script_py)
    endif

    let s:loaded = 1
endfunction " }}}
