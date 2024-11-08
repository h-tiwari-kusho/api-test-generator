if exists('g:loaded_kusho') | finish | endif

let s:save_cpo = &cpo
set cpo&vim

hi def link KushoHeader      Number
hi def link KushoSubHeader   Identifier

command! Kusho lua require'kusho'.kusho()

let &cpo = s:save_cpo
unlet s:save_cpo

let g:loaded_kusho= 1

