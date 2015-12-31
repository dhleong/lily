"
" Users fetching
"

let s:users_cache = {}
let s:cache_timeout = 60 * 5 " in seconds

function! lily#users#Prefetch(repo_dir) " {{{

    " TODO: prefetch
endfunction " }}}

function! lily#users#Get(repo_dir, ...) " {{{
    " Get @mention-able users for the repo at 
    "  repo_dir, preferably from cache

    let now = localtime()
    let cached = get(s:users_cache, a:repo_dir, {'time':0})
    let delta = now - cached.time
    if delta < s:cache_timeout
        return cached.data
    endif

    " TODO: hubr doesn't let us specify the repo dir!
    " This probably does the right thing, though
    let users = hubr#get_collaborators()
    let s:users_cache[a:repo_dir] = {
                \ 'time': now,
                \ 'data': copy(users)
                \ }

    return users

endfunction " }}}

" vim:ft=vim:fdm=marker
