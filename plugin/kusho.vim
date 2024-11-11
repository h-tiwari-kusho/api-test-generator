if exists('g:loaded_kusho') | finish | endif
let s:save_cpo = &cpo
set cpo&vim

hi def link KushoHeader      Number
hi def link KushoSubHeader   Identifier

" Initialize the plugin
lua require('kusho').setup()

" Main command
"command! Kusho lua require'kusho'.kusho()

" HTTP request parsing command (this is optional since we already defined it in Lua)
"command! ParseHttpRequest lua require'kusho.utils'.parse_current_request()

" HTTP request parsing command (this is optional since we already defined it in Lua)
"command! KushoProcessAPI lua require'kusho'.create_test_suite()

let &cpo = s:save_cpo
unlet s:save_cpo
let g:loaded_kusho = 1
