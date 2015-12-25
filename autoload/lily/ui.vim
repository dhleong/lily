"
" Interactive UI core
"

"
" Internal utils
"

function! s:DescribeIssuesOpts(opts) " {{{
    let desc = []

    if empty(desc)
        return '(None)'
    else
        return join(desc, ' ')
    endif
endfunction " }}}

function! s:DescribeIssue(issue) " {{{
    return '[#' . a:issue.number . '](' . a:issue.title . ')'
endfunction " }}}

"
" Callback
"

function! lily#ui#UpdateIssues(issues)
endfunction

"
" Public interface
"

function! lily#ui#UpdateWindow(lines, ...) " {{{

    let opts = a:0 ? a:1 : {}

    " fill the buffer
    setlocal modifiable
    setlocal filetype=lily

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

endfunction " }}}

function! lily#ui#Show() " {{{
    let repo_dir = lily#repo_dir()
    if repo_dir ==# ''
        return
    endif

    if expand('%') !=# ''
        tabe
        call lily#ui#Show()
    endif

    " prepare the buffer contents
    let title = "Lily: " . hubr#repo_name()
    let under = repeat('=', len(title))
    let c = [title, under, '']

    let opts = lily#_opt('ui_issues_opts', {'state':'open'})
    let issues = lily#issues#Get(repo_dir, opts)

    call add(c, '## Issues')
    call add(c, '')
    call add(c, '> Filter: ' . s:DescribeIssuesOpts(opts))
    call add(c, '')

    for issue in issues
        call add(c, ' ' . s:DescribeIssue(issue))
    endfor

    call lily#ui#UpdateWindow(c)
endfunction " }}}

" vim:ft=vim:fdm=marker
