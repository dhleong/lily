"
" Issue search filtering
"

let s:filter_prompt = '> Filter: '

function! s:FilterUser(user) " {{{
    if a:user[0] == '@'
        return a:user[1:]
    else
        return a:user
    endif
endfunction " }}}

function! s:FilterState(state) " {{{
    let lower = tolower(a:state[0])
    if lower == 'a'
        return 'all'
    elseif lower == 'c'
        return 'closed'
    elseif lower == 'o'
        return 'open'
    else
        return ''
    endif
endfunction " }}}

" Filter part definitions {{{
let s:filter_parts = {
    \ 'author': {'key': 'author',
            \ 'filter': function('s:FilterUser')},
    \ 'assignee': {'key': 'assignee',
            \ 'filter': function('s:FilterUser')},
    \ 'mentions': {'key': 'mentioned',
            \ 'filter': function('s:FilterUser')},
    \ 'state': {'key': 'state',
            \ 'filter': function('s:FilterState')}
    \}

let s:key_to_filter = {}
for [filter_name, filter] in items(s:filter_parts)
    let s:key_to_filter[filter.key] = filter_name
endfor
" }}}

"
" Filter part completion
"

let s:filter_completions = [
    \ {'word': 'assignee',
    \  'menu': 'User assigned to the issue'},
    \ {'word': 'author',
    \  'menu': 'User who created the issue'},
    \ {'word': 'mentions',
    \  'menu': 'User @mentioned in the issue'},
    \ {'word': 'state',
    \  'menu': 'Issue state: open/closed/all'},
\ ]

function! s:FindStart()
    let before_on_line = lily#complete#LineBeforeCursor()

    return match(before_on_line,'\c[[:alnum:]-]*$')
endfunction

function! s:CompleteFilterPart(base)
    let base = a:base
    let blen = len(base) - 1
    let b:lastBase = base
    return filter(copy(s:filter_completions), 'v:val.word[0:blen] == base')
endfunction

"
" Public interface
"

function! lily#ui#filter#Complete(findstart, base)
    if a:findstart
        let baseResult = lily#complete#func(1, '')
        if baseResult >= 0
            " we're using issue/mentions completion
            let b:_lily_filter_comp = 0
            return baseResult
        endif

        let b:_lily_filter_comp = 1
        return s:FindStart()
    endif

    if get(b:, '_lily_filter_comp', 0)
        " filter part completion!
        return s:CompleteFilterPart(a:base)
    else
        " delegate back to issues/mentions
        " (see the NBs in there for explanation)
        return lily#complete#func(0, a:base, a:base)
    endif
endfunction

function! lily#ui#filter#Parse(raw) " {{{
    let raw = substitute(a:raw, ':[ ]*', ':', 'g')
    let parts = split(raw, ' ')

    let parsed = {}

    for part in parts
        let split = split(part, ':')
        let label = get(split, 0, '_')
        let parser = get(s:filter_parts, label, {})
        if !empty(parser) && len(split) == 2
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
endfunction " }}}

function! lily#ui#filter#Dumps(filter) " {{{
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
endfunction " }}}

function! lily#ui#filter#Prompt(...)
    if a:0
        return s:filter_prompt . lily#ui#filter#Dumps(a:1)
    else
        return s:filter_prompt
    endif
endfunction

" vim:ft=vim:fdm=marker
