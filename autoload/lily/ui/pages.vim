"
" Pagination support
"

" lines from the end at which we trigger pagination
let s:paginate_size = 5

" Python {{{
function! s:LoadNextPage_python(callback_fn, next_link) " {{{
    let bufno = bufnr('%')
    let repo_path = hubr#repo_path()
    let callback = a:callback_fn
    let next_link = a:next_link

python << PYEOF
class NextPageCommand(HubrAsyncCommand):

    def __init__(self, bufno, repo_path, \
            callback, next_link):
        super(NextPageCommand, self).__init__(\
            callback, bufno, repo_path)
        self.next_link = next_link

    def run(self):
        raw = self.hubr().follow(self.next_link)
        result = self._filter(raw.json())
        return (raw.next(), result)

    def _filter(self, json):
        if LILY_FILTERS.has_key(self.callbackFn):
            fn = LILY_FILTERS[self.callbackFn]
            return fn(json)
        return json

# main:
bufno = int(vim.eval('bufno'))
path = vim.eval('repo_path')
callback = vim.eval('callback')
next_link = vim.eval('next_link')

NextPageCommand(bufno, path, callback, next_link).start()
PYEOF
endfunction " }}}
" }}}

"
" Util
"

function! s:CancelPagination() " {{{
    unlet b:pages_next_link
    unlet b:pages_callback
    augroup lily_paginate
        autocmd!
    augroup END
    augroup! lily_paginate
endfunction " }}}

function! s:OnCursorMoved()
    let next = get(b:, 'pages_next_link', 0)
    let callback = get(b:, 'pages_callback', 0)
    if empty(next) || empty(callback)
        call s:CancelPagination()
        return
    endif

    let pos = getpos('.')
    let cursorLine = pos[1]

    if cursorLine >= line('$') - s:paginate_size
        call s:LoadNextPage_python(callback, next)
    endif
endfunction

"
" Public Interface
"

function! lily#ui#pages#OnPage(callback_fn, start_line, next_link)
    let b:pages_next_link = a:next_link
    let b:pages_callback = a:callback_fn
    if empty(a:next_link)
        " nothing to do
        call s:CancelPagination()
    elseif lily#async#IsSupported()
        " add a pagination autocmd
        augroup lily_paginate
            autocmd CursorMoved <buffer> call <SID>OnCursorMoved()
        augroup END
    else
        " TODO: append this somehow
        " call extend(comments, ['', 
        "     \ '### Load more (press enter here) ###'])
    endif
endfunction
