"
" Issues fetching
"

function lily#issues#Get(repo_dir, ...) " {{{
    " Get issues for the repo at repo_dir,
    "  preferably from cache

    " TODO: actually implement
    return [
        \ {'number': 42, 'title': 'Answer to everything'},
        \ {'number': 9001, 'title': 'Over Nine Thousand'}
        \ ]

endfunction " }}}

" vim:ft=vim:fdm=marker
