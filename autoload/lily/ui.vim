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

function! s:UpdateIssuesAsync_python(bufno, repo_path) " {{{
    call lily#async#Load()

    let bufno = a:bufno
    let repo_path = a:repo_path

python << PYEOF
class UpdateIssuesCommand(HubrAsyncCommand):
    ISSUE_KEYS = ['title','number','state','body',\
        'assignee', 'labels']

    def __init__(self, bufno, repo_path):
        super(UpdateIssuesCommand, self).__init__(\
            'lily#ui#UpdateIssues', bufno, repo_path)

    def run(self):
        raw = self.hubr().get_issues()
        return [self.keys(i, self.ISSUE_KEYS, self._trim) \
                    for i in raw]

    def _trim(self, key, val):
        if key == 'assignee':
            return self.keys(val, ['login'])
        if key == 'labels':
            return [self.keys(l, ['name','color']) for l in val]
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

function! s:UiSelect() " {{{
    let line = getline('.')
    let items = matchlist(line, '.*#\([0-9]*\)\?\].*')
    let number = items[1]
    if empty(number)
        return
    endif

    let issues = get(b:, 'lily_issues', {})
    if !has_key(issues, number)
        echo "No such issue: " . number
        return
    endif

    let issue = issues[number]
    call lily#ui#issue#Show(issue)

endfunction " }}}

function! lily#ui#UpdateIssues(bufno, repo_dir, issues) " {{{
    " update the UI
    let titles = map(copy(a:issues), "lily#ui#DescribeIssue(v:val)")
    call lily#async#replace(a:bufno, s:issues_line, titles)

    " go ahead and update the cache
    call lily#issues#Cache(a:repo_dir, a:issues)
    let b:lily_issues = {}
    for i in a:issues
        let b:lily_issues[i.number] = i
    endfor

    " position the cursor nicely
    call cursor(s:issues_line + 1, 0)
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

    " make fugitive happy
    let b:git_dir = ''
    call fugitive#detect(expand('%:p'))

    " prepare the buffer contents
    let title = "Lily: " . hubr#repo_name()
    let under = repeat('=', len(title))
    let c = [title, under, '']

    let opts = lily#_opt('ui_issues_opts', {'state':'open'})

    call add(c, '## Issues')
    call add(c, '')
    call add(c, '> Filter: ' . s:DescribeIssuesOpts(opts))
    call add(c, '')

    let bufno = bufnr('%')
    let path = hubr#repo_path()
    if lily#async#IsSupported()
        call add(c, '### (loading issues)')

        call s:UpdateIssuesAsync(bufno, path)
    else
        " Although, if they don't support async they might
        "  also not support hubr's json binding... It may
        "  be good to refactor hubr to handle that better
        let issues = lily#issues#Get(repo_dir, opts)
        call lily#ui#UpdateIssues(bufno, path, issues)
    endif

    call lily#ui#UpdateWindow(c)

    nnoremap <buffer> <silent> <cr> :call <SID>UiSelect()<cr>

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
