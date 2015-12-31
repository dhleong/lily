"
" Issue search filtering
"

function! s:FilterUser(user) " {{{
    if a:user[0] == '@'
        return a:user[1:]
    else
        return a:user
    endif
endfunction " }}}

let s:filter_parts = {
    \ 'author': {'key': 'author',
            \ 'filter': function('s:FilterUser')},
    \ 'assignee': {'key': 'assignee',
            \ 'filter': function('s:FilterUser')},
    \ 'mentions': {'key': 'mentioned',
            \ 'filter': function('s:FilterUser')}
    \}

let s:key_to_filter = {}
for [filter_name, filter] in items(s:filter_parts)
    let s:key_to_filter[filter.key] = filter_name
endfor

"
" Public interface
"

function! lily#ui#filter#Parse(raw)
    let raw = substitute(a:raw, ':[ ]*', ':', 'g')
    let parts = split(raw, ' ')

    let parsed = {}

    for part in parts
        let split = split(part, ':')
        let parser = get(s:filter_parts, split[0], '')
        if !empty(parser)
            let key = parser.key
            let val = split[1]
            if has_key(parser, 'filter')
                let val = parser.filter(val)
            endif

            if !empty(val)
                let parsed[key] = val
            endif
        endif
    endfor

    return parsed
endfunction

function! lily#ui#filter#Dumps(filter)
    let parts = []

    for [k, v] in items(a:filter)
        let name = s:key_to_filter[k]
        call add(parts, name . ':' . v)
    endfor

    if empty(parts)
        return '(None)'
    else
        return join(parts, ' ')
    endif
endfunction

" vim:ft=vim:fdm=marker
