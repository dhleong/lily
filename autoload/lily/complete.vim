
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

function! s:OnBlankLine() " {{{
  return pyeval('not vim.current.line or vim.current.line.isspace()')
endfunction " }}}

function! s:FindPrefix() " {{{
    let before_on_line = getline('.')[0:col('.')+1]
    return matchstr(before_on_line,'[#@][[:alnum:]-]*$')
endfunction " }}}

"
" Start/stop
"

function! s:FinishComplete() " {{{
    augroup lily_end
        autocmd!
    augroup END

    let opt = b:_lily_completeopt

    " restore
    exe 'set completeopt=' . opt
endfunction " }}}

function! s:TriggerComplete(...) " {{{
    augroup lily_end
        autocmd!
        autocmd CompleteDone <buffer> call <SID>FinishComplete()
    augroup END

    let b:_lily_completeopt = &completeopt
    set completeopt-=longest

    if a:0
        return a:1 . "\<C-X>\<C-O>\<C-P>"
    elseif s:OnBlankLine()
        return
    else
        let prefix = s:FindPrefix()
        if prefix ==# ''
            return
        elseif prefix !~# '^#'
            " We only need to manually trigger
            " completion for issues
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

function! lily#complete#func(findstart, base) " {{{
    let repo_dir = fugitive#repo().dir()
    if &ft != 'gitcommit' || repo_dir ==# ''
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
        return col('.') - 1 - strlen(prefix)
    endif

    let raw = copy(prefix)
    let type = prefix[0]
    let prefix = prefix[1:] " trim the # or @
    let b:foo = [raw, type, prefix]

    let items = []
    let matchField = ''
    let wordField = ''
    if type == '@'
        " TODO: @mentions?
        return []
    elseif type == '#'
        " TODO: support cross-repo refs
        let items = lily#issues#Get(repo_dir)
        let matchField = 'title'
        let wordField = 'number'
    endif

    let filtered = filter(copy(items),
                \ 'lily#match#do(v:val, prefix, matchField)')
    let words = map(filtered, "{
        \ 'word': type . get(v:val, wordField),
        \ 'menu': get(v:val, matchField),
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
        autocmd CursorMovedI * call s:OnCursorMovedInsertMode()
        autocmd CursorMoved * call s:OnCursorMovedNormalMode()
    augroup END
endfunction " }}}

function! lily#complete#EnableIssuesCompletion() " {{{
    setlocal omnifunc=lily#complete#func

    " bind semantic triggers
    inoremap <buffer> <expr> # <SID>TriggerComplete('#')

    call s:EnableCursorMovedAutocommands()
    augroup lily
        autocmd InsertEnter * call s:OnInsertEnter()
    augroup END
endfunction " }}}

" vim:ft=vim:fdm=marker
