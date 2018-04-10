
"
" Issue/@mention completion
"

let s:old_cursor_position = []
let s:cursor_moved = 0
let s:expected_prefix = ''

"
" Util
"

function! lily#complete#LineBeforeCursor() " {{{
    let line = getline('.')
    let cursor = col('.') 

    if cursor == col('$')
        return line
    endif

    " col is 1-indexed; line is 0-indexed
    let cursor = cursor - 1
    if cursor <= 0
        return ''
    endif

    " -1 for BEFORE the cursor (in insert mode)
    return line[0:cursor - 1]
endfunction " }}}

function! s:HasYCM()
    " NOTE: YCM doesn't play very nicely with us anymore for some reason
    return exists('#youcompleteme')
endfunction

function! s:OnBlankLine() " {{{
    " return pyeval('not vim.current.line or vim.current.line.isspace()')
    let line = getline('.')
    return len(line) == 0 || match(line, '^[ ]*$') == 0
endfunction " }}}

function! s:FindPrefix(...) " {{{
    let before_on_line = lily#complete#LineBeforeCursor()
    if a:0
        " NB: Sometimes the most-recent character
        "  is lost when we trigger this from within
        "  filter completion; that character is exactly
        "  a suffix on this line, so we'll be given it
        let before_on_line = before_on_line . a:1
    endif

    return matchstr(before_on_line, '[#@][[:alnum:]-]*$')
endfunction " }}}

"
" Start/stop
"

function! s:FinishComplete() " {{{
    let prefix = s:FindPrefix()
    if prefix !=# ''
        " not done yet!
        return
    endif

    augroup lily_end
        autocmd!
    augroup END
    augroup! lily_end

    if !empty(get(b:, '_lily_completeopt', ''))
        let opt = b:_lily_completeopt

        " restore
        exe 'setlocal completeopt=' . opt
    endif

    " restore YCM
    " call s:SetYCMEnabled(1)

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
    setlocal completeopt-=longest
    setlocal completeopt+=menu
    setlocal completeopt+=menuone
    setlocal completeopt+=noselect

    if a:0
        " call s:SetYCMEnabled(0)
        return a:1 . "\<C-X>\<C-O>\<C-P>"
    elseif s:OnBlankLine()
        call s:FinishComplete()
        return
    else
        let prefix = s:FindPrefix()
        if prefix ==# ''
            call s:FinishComplete()
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

        " call s:SetYCMEnabled(0)
        if len(prefix) == 1
            " with just the prefix, we simply use <c-p>
            " to clear to the prefix
            call feedkeys("\<C-X>\<C-O>\<C-P>", 'n')
        else
            " with more than just the prefix typed, we use
            " <c-n><c-p> to get back to what we originally
            " typed
            call feedkeys("\<C-X>\<C-O>\<C-N>\<C-P>", 'n')
        endif
    endif

endfunction " }}}

"
" Respond to cursor movement 
"

function! s:UpdateCursorMoved() " {{{
  let current_position = getpos('.')
  let s:cursor_moved = current_position != s:old_cursor_position
  let s:old_cursor_position = current_position
endfunction " }}}

function! s:OnTextChangedInsertMode() " {{{
    let s:expected_prefix = s:FindPrefix()

    call s:UpdateCursorMoved()
    call s:TriggerComplete()
endfunction " }}}

function! s:OnCursorMovedNormalMode() " {{{
    let s:expected_prefix = ''
endfunction " }}}

function! s:OnInsertEnter() " {{{
    let s:old_cursor_position = []
    let s:expected_prefix = s:FindPrefix()
endfunction " }}}

"
" The completion function
"

function lily#complete#func(findstart, base, ...) " {{{
    let repo_dir = lily#repo_dir()
    if !lily#ShouldAllowAutocomplete() || repo_dir ==# ''
        return a:findstart ? -1 : []
    endif

    if a:findstart
        let prefix = a:0 ? s:FindPrefix(a:1) : s:FindPrefix()
        let cursor = col('.')
        if cursor <= 2
            return 0
        endif
        let start = cursor - 1 - strlen(prefix)
        let b:bar = [cursor, strlen(prefix), getline('.'), start]
        return start
    endif

    let prefix = a:base
    if prefix ==# ''
        " Still nothing? Okay; return -2 means 'stay in
        "  completion mode'
        let b:bar = [-2]
        let b:foo = [-2]
        call s:FinishComplete()
        return -2
    endif

    let raw = copy(prefix)
    let type = prefix[0]
    let prefix = prefix[1:] " trim the # or @
    let b:foo = [raw, type, prefix, a:base]

    let items = []
    let matchField = ''
    let wordField = ''
    let menuField = ''
    try
        if type ==# '@'
            let items = lily#users#Get(repo_dir)
            let matchField = 'login'
            let wordField = 'login'
        elseif type ==# '#'
            " TODO: support cross-repo refs
            let items = lily#issues#Get(repo_dir)
            let matchField = 'title'
            let wordField = 'number'
            let menuField = 'title'
        endif
    catch
        echo 'Unable to load completions'
        return -3 " stop completion silently
    endtry

    if type(items) != type([])
        " no completions; possibly not a github repo
        return -3
    endif

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
    if s:HasYCM()
        return
    endif

    augroup lilycursormove
        autocmd!
        autocmd TextChangedI <buffer> call s:OnTextChangedInsertMode()
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

function! lily#complete#Enable()
    if get(b:, '_lily_completion', 0)
        " already enabled
        return
    endif

    if lily#_opt('complete_issues', 1)
        call lily#complete#EnableIssuesCompletion()
    endif
    if lily#_opt('complete_mentions', 1)
        call lily#complete#EnableMentionsCompletion()
    endif
endfunction

" vim:ft=vim:fdm=marker
