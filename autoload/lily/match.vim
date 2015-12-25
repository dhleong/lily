"
" Matching functions
"

" TODO: fuzzy match?

function! lily#match#simple(item, input, item_field) " {{{
    " Simple, case-insensitive match

    let haystack = get(a:item, a:item_field, '')
    return match(haystack, '\c' . a:input) >= 0
endfunction " }}}

function! lily#match#do(item, input, item_field) " {{{
    " Delegates to whatever matcher the user wants

    return lily#match#simple(a:item, a:input, a:item_field)
endfunction " }}}

" vim:ft=vim:fdm=marker
