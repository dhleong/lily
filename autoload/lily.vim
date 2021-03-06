"
" Core lily functions
"

"
" Utility
"

function! lily#repo_dir() " {{{
    return fugitive#repo().dir()
endfunction " }}}

function! lily#ShouldAllowAutocomplete() " {{{
    if &ft == 'gitcommit' || &ft == 'lily'
        return 1
    endif

    return 0
endfunction " }}}

function! lily#_opt(opt_name, default) " {{{
    let fullName = 'lily_' . a:opt_name
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

    let repo_dir = lily#repo_dir()
    if repo_dir ==# ''
        return
    endif

    if lily#ShouldAllowAutocomplete()
        call lily#complete#Enable()
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
