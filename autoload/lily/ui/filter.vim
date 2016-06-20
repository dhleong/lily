"
" Issue search filtering
"

let s:filter_prompt = '> Filter: '

function! s:CompleteState(base) " {{{
    " NB: just let the FilterOn stuff handle filtering
    return [
        \ {'word': 'open',
        \  'menu': 'Open issues'},
        \ {'word': 'closed',
        \  'menu': 'Closed issues'},
        \ {'word': 'all',
        \  'menu': 'Closed AND Open issues'},
        \ ]
endfunction " }}}

function! s:CompleteMilestone(base) " {{{
    " TODO handle spaces in milestone names
    let milestones = lily#milestones#Get()
    return map(copy(milestones), "{'word': v:val.title, 'menu': v:val.description}")
endfunction " }}}

function! s:FilterUser(user) " {{{
    if a:user[0] == '@'
        return a:user[1:]
    else
        return a:user
    endif
endfunction " }}}

function! s:FilterMilestone(milestone) " {{{
    " TODO handle spaces in milestone names
    return a:milestone
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
    \ 'milestone': {'key': 'milestone',
            \ 'complete': function('s:CompleteMilestone'),
            \ 'filter': function('s:FilterMilestone')},
    \ 'mentions': {'key': 'mentioned',
            \ 'filter': function('s:FilterUser')},
    \ 'state': {'key': 'state',
            \ 'complete': function('s:CompleteState'),
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
    \ {'word': 'milestone',
    \  'menu': 'Milestone name the issue is attached to'},
    \ {'word': 'mentions',
    \  'menu': 'User @mentioned in the issue'},
    \ {'word': 'state',
    \  'menu': 'Issue state: open/closed/all'},
\ ]

function! s:FindStart()
    let before_on_line = lily#complete#LineBeforeCursor()

    let pos = match(before_on_line, '\c\([[:alnum:]-]*:\)*[[:alnum:]-]*$')
    let b:lastStartPos = pos
    return pos
endfunction

function! s:FilterOn(completions, base) " {{{
    let base = a:base
    if len(base) == 0
        " all of them
        return copy(a:completions)
    else
        let blen = len(base) - 1
        return filter(copy(a:completions), 'v:val.word[0:blen] == base')
    endif
endfunction " }}}

function! s:CompleteFilterPart(base) " {{{
    let base = a:base
    let sepPos = stridx(base, ":")
    if sepPos != -1
        " completing the value for a filter part
        let partName = strpart(base, 0, sepPos)
        let arg = strpart(base, sepPos + 1)
        let b:lastPartName = partName
        let b:lastArg = arg
        let filter = get(s:filter_parts, partName, {})
        if has_key(filter, "complete")
            let filtered = s:FilterOn(filter.complete(arg), arg)
            return map(filtered, '{"word": partName . ":" . v:val.word, "menu": v:val.menu}')
        endif
        return []
    endif

    " completing a filter part name
    return s:FilterOn(s:filter_completions, base)
endfunction " }}}

"
" Public interface
"

function! lily#ui#filter#Complete(findstart, base)
    let b:complete = [a:findstart, a:base]
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
