"
" Interactive UI core
"

let s:issues_line = 7

" Python functions {{{
" Requiring python is gross, but it's the only way to append to
"  a buffer that isn't visible, and that is surely required
function! s:append(bufno, line) " {{{
    if !has('python')
        return
    endif

    " prepare vars so python can pick them up
    let bufno = a:bufno
    let lines = split(a:line, '\r', 1)

py << PYEOF
import vim
bufno = int(vim.eval('bufno')) # NB int() is crucial
buf = vim.buffers[bufno]
if buf:
    lines = vim.eval('lines')
    oldEnd = len(buf)

    buf.options['readonly'] = False
    buf.options['modifiable'] = True
    buf.append(lines)
    buf.options['readonly'] = True
    buf.options['modifiable'] = False
PYEOF

endfunction " }}}

function! s:replace(bufno, lineno, lines) " {{{
    if !has('python')
        return
    endif

    " prepare vars so python can pick them up
    let bufno = a:bufno
    let lineno = a:lineno
    let lines = a:lines
    " let lines = split(a:line, '\r', 1)

py << PYEOF
GLO = {}
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


"
" Internal utils
"

function! s:SupportsAsync() " {{{
    return lily#_opt('ui_async', 1) && !empty(v:servername)
endfunction " }}}

function! s:DescribeIssuesOpts(opts) " {{{
    let desc = []

    if empty(desc)
        return '(None)'
    else
        return join(desc, ' ')
    endif
endfunction " }}}

function! lily#ui#DescribeIssue(issue) " {{{
    return ' [#' . a:issue.number . '](' . a:issue.title . ')'
endfunction " }}}

"
" Callback
"

function! lily#ui#UpdateIssues(bufno, issues) " {{{
    let titles = map(copy(a:issues), "lily#ui#DescribeIssue(v:val)")
    call s:replace(a:bufno, s:issues_line, titles)
endfunction " }}}

"
" Public interface
"

function! lily#ui#UpdateWindow(lines, ...) " {{{

    let opts = a:0 ? a:1 : {}

    " fill the buffer
    setlocal modifiable

    let title = get(opts, 'title', '[Lily]')
    exe "silent file " . title

    silent 1,$delete _
    call append(0, a:lines)

    " update flags
    setlocal nomodifiable
    setlocal nomodified
    setlocal readonly
    setlocal noswapfile
    setlocal nobuflisted
    setlocal buftype=nofile
    setlocal bufhidden=wipe

    setlocal filetype=lily
endfunction " }}}

function! lily#ui#Show() " {{{
    let repo_dir = lily#repo_dir()
    if repo_dir ==# ''
        return
    endif

    if expand('%') !=# ''
        tabe
    endif

    " prepare the buffer contents
    let title = "Lily: " . hubr#repo_name()
    let under = repeat('=', len(title))
    let c = [title, under, '']

    let opts = lily#_opt('ui_issues_opts', {'state':'open'})

    call add(c, '## Issues')
    call add(c, '')
    call add(c, '> Filter: ' . s:DescribeIssuesOpts(opts))
    call add(c, '')

    if s:SupportsAsync()
        call add(c, '### (loading issues)')
        let bufno = bufnr('%')

        " TODO: refactor and support neovim async
        exe 'py update_issues_async(' . bufno . ', "' . hubr#repo_path() . '")'
    else
        " Although, if they don't support async they might
        "  also not support hubr's json binding... It may
        "  be good to refactor hubr to handle that better
        let issues = lily#issues#Get(repo_dir, opts)
        for issue in issues
            call add(c, ' ' . s:DescribeIssue(issue))
        endfor
    endif

    call lily#ui#UpdateWindow(c)

endfunction " }}}

" Async processing python fun {{{
python << PYEOF
import threading
from subprocess import call
import json as JSON

GLO = {}

def async_callback(fun, *args):
    """Call a vim callback function remotely"""
    instance = vim.eval('v:servername')
    exe = vim.eval('exepath(v:progpath)')
    
    expr = fun + '('
    expr += ','.join([ JSON.dumps(a, separators=(',',':')) for a in args ])
    expr += ') | redraw!'

    call([exe, '--servername', instance, \
        '--remote-expr', expr])

def _keys(item, keys):
    return {k: item[k] for k in keys}

def _do_update_issues(bufno, repo_dir):
    # issues = hubr(repo_dir).get_issues()
    hubr = Hubr.from_config(repo_dir + '.hubrrc')
    issues = hubr.get_issues()
    # issues = [{"title":"foo"}]
    async_callback('lily#ui#UpdateIssues', \
        bufno, \
        [_keys(i, ["title", "number"]) for i in issues])

def update_issues_async(bufno, repo_dir):
    threading.Thread(target=_do_update_issues, \
        args=[bufno, repo_dir]).start()
PYEOF
" }}}

" vim:ft=vim:fdm=marker
