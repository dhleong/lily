"
" Issue-viewing UI
"

function lily#ui#issue#Refresh() " {{{
    let issue = get(b:, 'issue', {})
    if empty(issue)
        echo "No issue to refresh"
        return
    endif

    let body = substitute(issue.body, "\n", '', 'g')

    set noreadonly

    norm! ggdG
    call append(0, issue.title)
    call append(1, repeat('=', len(issue.title)))
    " TODO: labels
    call append(3, split(body, '\r'))

    set readonly
    set nomodified
endfunction " }}}

function lily#ui#issue#Show(issue) " {{{
    let orient = lily#_opt('issue_orient', 'vertical')
    if orient == 'vertical'
        let method = 'belowright'
        let mod = ' vertical '
        let dimen = 64
    else
        let method = 'botright'
        let mod = ' '
        let dimen = 10
    endif

    let name = '[' . a:issue.title . ']'
    let method = lily#_opt('issue_split', method)
    let dimen = lily#_opt('issue_size', dimen)
    let cmd = method . mod . ' ' . dimen .
                \ ' sview ' . name
    silent! noautocmd exec "keepalt " . cmd

    " set some flags
    setlocal noswapfile
    setlocal nobuflisted
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal filetype=lily

    " set some mappings
    nnoremap <buffer> <silent> q :q<cr>

    " set some content
    let b:issue = a:issue
    call lily#ui#issue#Refresh()
endfunction " }}}
