
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

    if &ft == 'gitcommit'
        if get(g:, 'lily_complete_issues', 1)
            call lily#complete#EnableIssuesCompletion()
        endif
    endif

    let b:_lily_init = 1
endfunction " }}}


" vim:ft=vim:fdm=marker
