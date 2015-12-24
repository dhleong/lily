"
" Core lily functions
"

"
" Utility
"

function! lily#ShouldAllowAutocomplete() " {{{
    if &ft == 'gitcommit'
        return 1
    endif

    return 0
endfunction " }}}

function! lily#_opt(opt_name, default) " {{{
    let fullName = 'lily#' . a:opt_name
    let bufferVal = get(b:, fullName, a:default)
    if bufferVal != a:default
        return bufferVal
    endif

    return get(g:, fullName, a:default)
endfunction " }}}

"
" Startup
"

function! lily#Enable() " {{{
    if exists('b:_lily_init')
        return
    endif

    let repo_dir = fugitive#repo().dir()
    if repo_dir ==# ''
        return
    endif

    if lily#ShouldAllowAutocomplete()
        if lily#_opt('complete_issues', 1)
            call lily#complete#EnableIssuesCompletion()
        endif
        if lily#_opt('complete_mentions', 1)
            call lily#complete#EnableMentionsCompletion()
        endif
    endif

    if lily#_opt('prefetch_issues', 1)
        call lily#issues#Prefetch(repo_dir)
    endif

    if lily#_opt('prefetch_mentions', 1)
        call lily#users#Prefetch(repo_dir)
    endif

    let b:_lily_init = 1
endfunction " }}}


" vim:ft=vim:fdm=marker
