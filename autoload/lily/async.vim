
let s:loaded = 0

let s:cwdir = expand("<sfile>:p:h")
let s:script_py = s:cwdir . '/async.py'

" Python functions {{{
function! lily#async#ReplaceOne(bufno, lineno, lines) " {{{
    " Convenience alias

    call lily#async#Replace(a:bufno, a:lineno,
                \ a:lineno + 1, a:lines)
endfunction " }}}

function! lily#async#Replace(bufno, lineStart, lineEnd, lines) " {{{
    if !has('python')
        return
    endif

    " prepare vars so python can pick them up
    let bufno = a:bufno
    let lineStart = a:lineStart
    let lineEnd = a:lineEnd
    let lines = a:lines

py << PYEOF
import vim
bufno = int(vim.eval('bufno')) # NB int() is crucial
buf = vim.buffers[bufno]
if buf:
    line_start = int(vim.eval('lineStart'))
    line_end = int(vim.eval('lineEnd'))
    lines = vim.eval('lines')

    buf.options['readonly'] = False
    buf.options['modifiable'] = True
    buf[line_start:line_end] = lines
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
