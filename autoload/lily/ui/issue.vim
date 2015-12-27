"
" Issue-viewing UI
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
    let contents = [repeat('=', len(issue.title)), '']

    " labels
    if !empty(issue.labels)
        call add(contents, '> ' . join(map(copy(issue.labels), 
                    \ "'['.v:val.name.']'"), ' '))
        call add(contents, '')
    endif

    " body
    call extend(contents, split(body, '\r'))

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
