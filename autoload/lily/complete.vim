
"
" Issue/@mention completion
"

let s:old_cursor_position = []
let s:cursor_moved = 0
let s:moved_vertically_in_insert_mode = 0
let s:previous_num_chars_on_current_line = strlen( getline('.') )
let s:expected_prefix = ''

"
" Util
"

function! lily#complete#LineBeforeCursor() " {{{
    let cursor = col('.')
    let line = getline('.')

    if cursor < strlen(line)
        let cursor = cursor - 1
    endif

    if cursor <= 0
        return ''
    endif

    return line[0:cursor]
endfunction " }}}

function! s:OnBlankLine() " {{{
  return pyeval('not vim.current.line or vim.current.line.isspace()')
endfunction " }}}

function! s:FindPrefix() " {{{
    let before_on_line = lily#complete#LineBeforeCursor()
    return matchstr(before_on_line,'[#@][[:alnum:]-]*$')
endfunction " }}}

"
" Start/stop
"

function! s:FinishComplete() " {{{
    augroup lily_end
        autocmd!
    augroup END
    augroup! lily_end

    if !empty(get(b:, '_lily_completeopt', ''))
        let opt = b:_lily_completeopt

        " restore
        " FIXME: This is actually ignored by
        "  vim right now....
        exe 'setlocal completeopt=' . opt
    endif
endfunction " }}}

function! s:TriggerComplete(...) " {{{
    augroup lily_end
        autocmd!
        autocmd CompleteDone <buffer> call <SID>FinishComplete()
    augroup END

    if empty(get(b:, '_lily_completeopt', ''))
        let b:_lily_completeopt = &completeopt
    endif

    " we need menuone for issues completion to
    "  make sense; longest is not necessary for lily.
    "  These are inspired by YCM, and needed here
    "  in case YCM is not also installed
    setlocal completeopt-=longest
    setlocal completeopt-=menu
    setlocal completeopt+=menuone

    if a:0
        return a:1 . "\<C-X>\<C-O>\<C-P>"
    elseif s:OnBlankLine()
        return
    else
        let prefix = s:FindPrefix()
        if prefix ==# ''
            return
        elseif prefix !~# '^[#@]'
            " We only need to manually trigger
            " completion for issues or mentions
            " FIXME: We shouldn't need to trigger
            "  for @mentions... should we?
            return
        endif

        if !s:cursor_moved
            return
        endif

        let s:expected_prefix = prefix

        call feedkeys("\<C-X>\<C-O>\<C-P>", 'n')
    endif

endfunction " }}}

"
" Respond to cursor movement 
"

function! s:UpdateCursorMoved() " {{{
  let current_position = getpos('.')
  let s:cursor_moved = current_position != s:old_cursor_position

  let s:moved_vertically_in_insert_mode = s:old_cursor_position != [] &&
        \ current_position[ 1 ] != s:old_cursor_position[ 1 ]

  let s:old_cursor_position = current_position
endfunction " }}}

function! s:OnCursorMovedInsertMode() " {{{
    let s:expected_prefix = s:FindPrefix()

    call s:UpdateCursorMoved()
    call s:TriggerComplete()
endfunction " }}}

function! s:OnCursorMovedNormalMode() " {{{
    let s:expected_prefix = ''
endfunction " }}}

function! s:OnInsertEnter() " {{{
    let s:previous_num_chars_on_current_line = strlen( getline('.') )

    let s:old_cursor_position = []
    let s:expected_prefix = ''
endfunction " }}}

"
" The completion function
"

function lily#complete#func(findstart, base) " {{{
    let repo_dir = lily#repo_dir()
    if !lily#ShouldAllowAutocomplete() || repo_dir ==# ''
        return a:findstart ? -1 : []
    endif

    " HAX: Interplay with YouCompleteMe (I think) causes
    "  some weird double-calls, where our input so far
    "  is stripped. We save the last-seen prefix and use
    "  that in such cases
    let prefix = s:FindPrefix()
    if prefix ==# ''
        let prefix = s:expected_prefix
    endif
    if prefix ==# ''
        " Still nothing? Okay; return -2 means 'stay in
        "  completion mode'
        return -2
    endif

    if a:findstart
        " let cursor = col('.')
        " if cursor <= 1
        "     return 0
        " endif
        let start = col('.') - 1 - strlen(prefix)
        " let b:last = {'c': col('.'), 'pref': prefix, 's': start}
        return start
    endif

    let raw = copy(prefix)
    let type = prefix[0]
    let prefix = prefix[1:] " trim the # or @
    let b:foo = [raw, type, prefix]

    let items = []
    let matchField = ''
    let wordField = ''
    let menuField = ''
    try
        if type == '@'
            let items = lily#users#Get(repo_dir)
            let matchField = 'login'
            let wordField = 'login'
        elseif type == '#'
            " TODO: support cross-repo refs
            let items = lily#issues#Get(repo_dir)
            let matchField = 'title'
            let wordField = 'number'
            let menuField = 'title'
        endif
    catch 
        echo "Unable to load completions"
        return -3 " stop completion silently
    endtry


    let filtered = filter(copy(items),
                \ 'lily#match#do(v:val, prefix, matchField)')
    let words = map(filtered, "{
        \ 'word': type . get(v:val, wordField),
        \ 'menu': empty(menuField) ? '' : get(v:val, menuField),
        \ 'icase': 1
        \ }")

    return {'words': words, 'refresh': 'always'}
endfunction " }}}

"
" Startup
"

function! s:EnableCursorMovedAutocommands() " {{{
    augroup lilycursormove
        autocmd!
        autocmd CursorMovedI <buffer> call s:OnCursorMovedInsertMode()
        autocmd CursorMoved <buffer> call s:OnCursorMovedNormalMode()
    augroup END
endfunction " }}}

function! lily#complete#EnableBaseCompletion() " {{{
    " Basic, shared completion opts

    setlocal omnifunc=lily#complete#func

    call s:EnableCursorMovedAutocommands()
    augroup lily
        autocmd!
        autocmd InsertEnter <buffer> call s:OnInsertEnter()
    augroup END

    let b:_lily_completion = 1
endfunction " }}}

function! lily#complete#EnableIssuesCompletion() " {{{
    call lily#complete#EnableBaseCompletion()

    " bind semantic trigger
    inoremap <buffer> <expr> # <SID>TriggerComplete('#')

endfunction " }}}

function! lily#complete#EnableMentionsCompletion() " {{{
    call lily#complete#EnableBaseCompletion()

    " bind semantic trigger
    inoremap <buffer> <expr> @ <SID>TriggerComplete('@')

endfunction " }}}

" vim:ft=vim:fdm=marker
