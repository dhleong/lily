
function! lily#milestones#Get() " {{{

    let milestones = hubr#get_milestones()

    " TODO do we want to cache this?

    return milestones
endfunction " }}}

" vim:ft=vim:fdm=marker
