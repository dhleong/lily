
let s:loaded = 0

let s:cwdir = expand("<sfile>:p:h")
let s:script_py = s:cwdir . '/async.py'

" Python functions {{{
function! lily#async#replace(bufno, lineno, lines) " {{{
    if !has('python')
        return
    endif

    " prepare vars so python can pick them up
    let bufno = a:bufno
    let lineno = a:lineno
    let lines = a:lines
    " let lines = split(a:line, '\r', 1)

py << PYEOF
import vim
bufno = int(vim.eval('bufno')) # NB int() is crucial
buf = vim.buffers[bufno]
if buf:
    lineno = int(vim.eval('lineno'))
    lineend = lineno + 1
    lines = vim.eval('lines')

    buf.options['readonly'] = False
    buf.options['modifiable'] = True
    buf[lineno:lineend] = lines
    buf.options['readonly'] = True
    buf.options['modifiable'] = False
PYEOF

endfunction " }}}
" }}}

function! lily#async#IsSupported() " {{{
    return lily#_opt('ui_async', 1) 
            \ && !empty(v:servername)
            \ && has('python')
endfunction " }}}

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
