"
" Create an issue UI
"

"
" Public UI
"

function! lily#ui#issue#create#Show()
    call lily#ui#SplitWindow('issue', "New Issue")

    setlocal noreadonly
    setlocal modifiable

    norm! ggdG
    call append(0, "Title: ")
    let contents = [repeat('=', 64)]

    " " labels
    " if empty(issue.labels)
    "     call add(contents, '')
    " else
    "     call add(contents, '> ' . join(map(copy(issue.labels), 
    "                 \ "'['.v:val.name.']'"), ' '))
    "     call add(contents, '')
    " endif

    " body
    call add(contents, '')

    " insert the content
    call append(1, contents)
endfunction
