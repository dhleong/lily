"
" Issues fetching
"

let s:issues_cache = {}
let s:cache_timeout = 60 * 5 " in seconds

function! lily#issues#Prefetch(repo_dir) " {{{

    " TODO: prefetch
endfunction " }}}

function! lily#issues#Get(repo_dir, ...) " {{{
    " Get issues for the repo at repo_dir,
    "  preferably from cache

    let now = localtime()
    let cached = get(s:issues_cache, a:repo_dir, {'time':0})
    let delta = now - cached.time
    if delta < s:cache_timeout
        return cached.data
    endif

    " TODO: hubr doesn't let us specify the repo dir!
    " This probably does the right thing, though
    let issues = hubr#get_issues({'state':'open'})
    let s:issues_cache[a:repo_dir] = {
                \ 'time': now,
                \ 'data': copy(issues)
                \ }

    return issues

endfunction " }}}

" vim:ft=vim:fdm=marker
