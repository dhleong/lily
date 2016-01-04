"
" Interactive UI core
"

let s:filter_keys_on_line = ['cc', 'dd']
let s:motion_mappings = ['c', 'd']
let s:default_opts = {'state':'open'}

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
    let opts = lily#_opt('ui_issues_opts', s:default_opts)

python << PYEOF
class UpdateIssuesCommand(HubrAsyncCommand):
    ISSUE_KEYS = ['title','number','state','body',\
        'assignee', 'user', 'labels']

    def __init__(self, bufno, repo_path, opts):
        super(UpdateIssuesCommand, self).__init__(\
            'lily#ui#UpdateIssues', bufno, repo_path)
        self.opts = opts

    def run(self):
        raw = self.hubr().get_issues(**opts)
        result = self._filter(raw)
        return (raw.next(), result)

    @lily_filter
    def _filter(self, issues):
        return [self.keys(i, self.ISSUE_KEYS, self._trim) \
                    for i in issues]        

    def _trim(self, key, val):
        if key in ['assignee', 'user']:
            return self.keys(val, ['login'])
        if key == 'labels':
            return [self.keys(l, ['name','color']) for l in val]
        return val

# main:
bufno = int(vim.eval('bufno'))
path = vim.eval('repo_path')
opts = vim.eval('opts')

UpdateIssuesCommand(bufno, path, opts).start()
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

function! lily#ui#DescribeIssue(issue) " {{{
    return ' [#' . a:issue.number . '](' . a:issue.title . ')'
endfunction " }}}

"
" Callback
"

function! s:StartFilter(mode)

    let cursor = getpos('.')

    " if index(s:filter_keys_on_line, a:mode) >= 0
    if cursor[1] != b:filter_line
        " just let them be
        setlocal nomodifiable
        setlocal readonly
        return a:mode
    endif

    setlocal modifiable
    setlocal noreadonly

    if a:mode ==# 'cc'
        call setline('.', lily#ui#filter#Prompt())
        call cursor(b:filter_line, cursor[2])
        call feedkeys('A', 'n')
    elseif a:mode ==# 'dd'
        call setline('.', lily#ui#filter#Prompt())
        call cursor(b:filter_line, cursor[2])
        
        " update immediately
        call s:UpdateFilter()
        return
    elseif a:mode ==# 'D' || a:mode ==# 'C'

        let cutStart = max([cursor[2] - 2, 
                    \ strlen(lily#ui#filter#Prompt()) - 1])
        let line = getline('.')[0:cutStart]
        call setline('.', line)
        call cursor(b:filter_line, cutStart)

        if a:mode == 'D'
            " update immediately
            call s:UpdateFilter()
            return
        else
            " go to insert mode
            call feedkeys('A', 'n')
        endif
    elseif index(s:motion_mappings, a:mode) == -1

        let prompt = lily#ui#filter#Prompt()
        let cursorPos = max([cursor[2], strlen(prompt)])
        call cursor(b:filter_line, cursorPos)
        call feedkeys(a:mode, 'n') 
    endif

    " prepare omnicompletion
    call lily#complete#Enable()
    setlocal omnifunc=lily#ui#filter#Complete

    augroup lily_filter
        autocmd!
        autocmd! InsertLeave <buffer> call <SID>UpdateFilter()
    augroup END

    return a:mode
endfunction

function! s:UpdateFilter()
    augroup lily_filter
        autocmd!
    augroup END
    augroup! lily_filter

    let line = getline(b:filter_line)
    let rawfilter = line[len(lily#ui#filter#Prompt()):]
    let filter = {}

    if rawfilter !~# "^[ \t]*$"
        let filter = lily#ui#filter#Parse(rawfilter)
    endif

    setlocal nomodifiable
    setlocal readonly

    let b:lily_ui_issues_opts = filter
    call lily#ui#Show()
endfunction

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

function! lily#ui#UpdateIssues(bufno, repo_dir, 
            \ next_link, issues) " {{{
    " update the UI
    let titles = map(copy(a:issues), "lily#ui#DescribeIssue(v:val)")
    if b:issues_line > b:issues_start
        call insert(titles, ' --- ', 0)
    endif
    call lily#async#ReplaceOne(a:bufno, b:issues_line, titles)

    let b:lily_issues = {}
    for i in a:issues
        let b:lily_issues[i.number] = i
    endfor

    if b:issues_line == b:issues_start
        " position the cursor nicely (if we didn't paginate)
        call cursor(b:issues_line + 1, 0)

        " go ahead and update the cache.
        " NB: In no case do we support completion past
        "  the first page of results. This could be nice,
        "  but would be expensive; we'd have to precache
        "  EVERY page to really be sure we found the issue
        "  (or not). 
        call lily#issues#Cache(a:repo_dir, a:issues)
    endif

    " paginate
    " (add 1 for the separator line)
    let b:issues_line = b:issues_line + len(a:issues) + 1
    call lily#ui#pages#OnPage('lily#ui#UpdateIssues',
                \ b:issues_line, a:next_link)
endfunction " }}}

"
" Public interface
"

function! lily#ui#Error(msg) " {{{
    let b:_lily_last_error = a:msg
    echo "lily:" . a:msg
endfunction " }}}

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

    if expand('%') !=# '' && expand('%') != '[Lily]'
        tabe
    endif

    " make fugitive happy
    let b:git_dir = ''
    call fugitive#detect(expand('%:p'))

    " prepare the buffer contents
    let title = "Lily: " . hubr#repo_name()
    let under = repeat('=', len(title))
    let c = [title, under, '']

    let opts = lily#_opt('ui_issues_opts', s:default_opts)

    call add(c, '## Issues')
    call add(c, '')
    call add(c, lily#ui#filter#Prompt(opts))
    let b:filter_line = len(c)
    call add(c, '')

    let b:issues_start = len(c)
    let b:issues_line = len(c)

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

    " add some mappings
    nnoremap <buffer> <silent> <cr> :call <SID>UiSelect()<cr>
    inoremap <buffer> <silent> <cr> <C-O>:stopinsert<cr>

    for m in s:motion_mappings
        exe 'nnoremap <buffer> <silent> <expr> ' .
                \ m . ' <SID>StartFilter("' . 
                \ m . '")'
    endfor

    for m in ['i', 'a', 'A', 'cc', 'dd', 'C', 'D']
        exe 'nnoremap <buffer> <silent> ' .
                \ m . ' :call <SID>StartFilter("' . 
                \ m . '")<cr>'
    endfor

    augroup lily_ui
        autocmd!

        " temporary hacks: for whatever reason, :bdelete
        "  in the preview window from :Gstatus, for example,
        "  is broken from within Lily: the window is cleared,
        "  but not closed. Hopefully we can figure out what's
        "  causing that, but this is a decent workaround for now
        autocmd BufDelete * 
                \ if &previewwindow |
                \   call feedkeys("\<C-W>z", 'n') | 
                \ endif
    augroup END

endfunction " }}}

" vim:ft=vim:fdm=marker
