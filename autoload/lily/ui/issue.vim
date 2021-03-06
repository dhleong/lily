"
" Issue-viewing UI
"

let b:comments_line = 0
let b:comments_start = 0

" Python functions {{{
function! s:LoadCommentsAsync_python(bufno, repo_path) " {{{
    call lily#async#Load()

    let bufno = a:bufno
    let repo_path = a:repo_path

python << PYEOF

def _keys(item, keys, fn=lambda k,v:v):
    if item is None:
        return None

    return {k: fn(k, item[k]) for k in keys if item[k] is not None}

class LoadCommentsCommand(HubrAsyncCommand):
    COMMENT_KEYS = ['body', 'user', 'updated_at']

    def __init__(self, bufno, repo_path):
        super(LoadCommentsCommand, self).__init__(\
            'lily#ui#issue#LoadComments', bufno, repo_path)
        self.issue = vim.bindeval('b:issue')

    def run(self):
        raw = self.hubr().get_comments(self.issue['number'])
        result = self._filter(raw)
        return (raw.next(), result)

    @lily_filter
    def _filter(self, comments):
        return [self.keys(i, self.COMMENT_KEYS, self._trim) \
                    for i in comments]

    def _trim(self, key, val):
        if key == 'user':
            return self.keys(val, ['login'])
        return val

# main:
bufno = int(vim.eval('bufno'))
path = vim.eval('repo_path')

LoadCommentsCommand(bufno, path).start()
PYEOF
endfunction " }}}
" }}}

"
" Util
"

function s:CalculateForeground(color) " {{{
    " credit: http://stackoverflow.com/a/1855903
    let r = str2nr(a:color[0:1], 16)
    let g = str2nr(a:color[2:3], 16)
    let b = str2nr(a:color[4:5], 16)

    " calculate 'perceptive luminence'; the human
    "  eye favors green color
    let l = (0.299 * r + 0.587 * g + 0.114 * b) / 255

    if l >= 0.5
        " bright colors, dark font
        return "000000"
    else
        " dark colors, bright font
        return "FFFFFF"
    endif
endfunction " }}}

function s:LoadCommentsAsync(bufno, repo_path)  " {{{
    " TODO: support nvim async, possibly ruby?
    if has('python')
        call s:LoadCommentsAsync_python(a:bufno, a:repo_path)
    endif
endfunction " }}}

function! lily#ui#issue#DescribeComment(comment) " {{{
    return extend(['### @' . a:comment.user.login,
                 \ '>   at ' . a:comment.updated_at],
                 \ split(a:comment.body, '\r'))
endfunction " }}}

"
" Callback
"

function! lily#ui#issue#LoadComments(bufno, repo_dir, 
            \ next_link, comments) " {{{

    " update the UI
    let rawcomments = map(copy(a:comments), 
                \ "lily#ui#issue#DescribeComment(v:val)")
    let comments = []

    if empty(rawcomments)
        call add(comments, '### (No Comments)')
    else
        if b:comments_line == b:comments_start
            " position the cursor nicely
            call cursor(b:comments_line + 1, 0)

            " insert the header
            call extend(comments, ['## Comments', ''])
        endif

        for desc in rawcomments
            call add(comments, '')
            call extend(comments, desc)
        endfor

    endif

    " update UI
    call lily#async#ReplaceOne(a:bufno, b:comments_line, comments)

    " paginate
    b:comments_line = b:comments_line + len(comments)
    call lily#ui#pages#OnPage(b:comments_line, a:next_link)
endfunction " }}}

"
" Public interface
"

function lily#ui#issue#Refresh() " {{{
    let issue = get(b:, 'issue', {})
    if empty(issue)
        echo "No issue to refresh"
        return
    endif

    let body = substitute(issue.body, "\n", '', 'g')

    setlocal noreadonly
    setlocal modifiable

    norm! ggdG
    call append(0, issue.title)
    let contents = [repeat('=', len(issue.title))]
    call add(contents, '> from: @' . issue.user.login)

    " labels
    if empty(issue.labels)
        call add(contents, '')
    else
        call add(contents, '> ' . join(map(copy(issue.labels), 
                    \ "'['.v:val.name.']'"), ' '))
        call add(contents, '')
    endif

    " body
    call extend(contents, split(body, '\r'))

    " load comments (possibly async)
    let bufno = bufnr('%')
    let path = hubr#repo_path()
    if lily#async#IsSupported()
        " load comments async
        call extend(contents, ['', '### (loading comments)'])
        let b:comments_line = len(contents)
        let b:comments_start = b:comments_line
        call s:LoadCommentsAsync(bufno, path)

    elseif lily#_opt('auto_load_comments', 1)
        " TODO: load comments now
    else
        " TODO: add a row for loading comments
    endif

    " insert the content
    call append(1, contents)

    " update syntax for labels
    for l in issue.labels
        let matchName = 'label' . substitute(l.name, '[ -]', '', 'g')
        exe 'syn match ' . matchName .
                \ " '\\[" . l.name . "\\]'"

        let fgColor = s:CalculateForeground(l.color)
        exe 'hi ' . matchName . 
                \ ' guibg=#' . l.color 
                \ ' guifg=#' . fgColor
    endfor

    setlocal readonly
    setlocal nomodifiable
    setlocal nomodified
endfunction " }}}

function lily#ui#issue#Show(issue) " {{{
    call lily#ui#SplitWindow('issue', a:issue.title)

    " set some content
    let b:issue = a:issue
    call lily#ui#issue#Refresh()
endfunction " }}}

" vim:ft=vim:fdm=marker
