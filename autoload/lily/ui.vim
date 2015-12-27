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

function! s:UpdateIssuesAsync_python(bufno, repo_path) " {{{
    call lily#async#Load()

    let bufno = a:bufno
    let repo_path = a:repo_path

python << PYEOF

def _keys(item, keys, fn=lambda k,v:v):
    if item is None:
        return None

    return {k: fn(k, item[k]) for k in keys if item[k] is not None}

class UpdateIssuesCommand(BufAsyncCommand):
    ISSUE_KEYS = ['title','number','state','body',\
        'assignee', 'labels']

    def __init__(self, bufno, repo_path):
        super(UpdateIssuesCommand, self).__init__(\
            'lily#ui#UpdateIssues', bufno)
        self.repo_path = repo_path

    def run(self):
        hubr = Hubr.from_config(self.repo_path + '.hubrrc')
        raw = hubr.get_issues()
        trimmed = [_keys(i, self.ISSUE_KEYS, self._trim) for i in raw]
        return (self.repo_path, trimmed)

    def _trim(self, key, val):
        if key == 'assignee':
            return _keys(val, ['login'])
        if key == 'labels':
            return [_keys(l, ['name','color']) for l in val]
        return val

# main:
bufno = int(vim.eval('bufno'))
path = vim.eval('repo_path')

UpdateIssuesCommand(bufno, path).start()
PYEOF
endfunction " }}}
" }}}


"
" Internal utils
"

function! s:SupportsAsync() " {{{
    return lily#_opt('ui_async', 1) 
            \ && !empty(v:servername)
            \ && has('python')
endfunction " }}}

function! s:UpdateIssuesAsync(bufno, repo_path) " {{{
    " TODO: support nvim async, possibly ruby?
    if has('python')
        call s:UpdateIssuesAsync_python(a:bufno, a:repo_path)
    endif
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

function! lily#ui#UpdateIssues(bufno, repo_dir, issues) " {{{
    " update the UI
    let titles = map(copy(a:issues), "lily#ui#DescribeIssue(v:val)")
    call s:replace(a:bufno, s:issues_line, titles)

    " go ahead and update the cache
    call lily#issues#Cache(a:repo_dir, a:issues)
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

        call s:UpdateIssuesAsync(bufno, hubr#repo_path())
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

    " temporary hacks: for whatever reason, :bdelete
    "  in the preview window from :Gstatus, for example,
    "  is broken from within Lily: the window is cleared,
    "  but not closed. Hopefully we can figure out what's
    "  causing that, but this is a decent workaround for now
    augroup lily_ui
        autocmd!
        autocmd BufDelete * 
                \ if &previewwindow |
                \   call feedkeys("\<C-W>z", 'n') | 
                \ endif
    augroup END

endfunction " }}}

" vim:ft=vim:fdm=marker
