" Insert or delete brackets, parens, quotes in pairs.
" Maintainer:	JiangMiao <jiangfriend@gmail.com>
" Contributor: camthompson, alpaca-tc
" Last Change:  2013-08-14
" Version: 1.3.3
" Homepage: http://www.vim.org/scripts/script.php?script_id=3599
" Repository: https://github.com/jiangmiao/auto-pairs
" License: MIT

if exists('g:auto_pairs_loaded') || &cp
  finish
end
let g:auto_pairs_loaded = 1

if !exists('g:auto_pairs')
  let g:auto_pairs = {'(':')', '[':']', '{':'}',"'":"'",'"':'"', '`':'`'}
end

if !exists('g:auto_pairs#parens')
  let g:auto_pairs#parens = {'(':')', '[':']', '{':'}'}
end

if !exists('g:auto_pairs#map_bs')
  let g:auto_pairs#map_bs = 1
end

if !exists('g:auto_pairs#map_cr')
  let g:auto_pairs#map_cr = 1
end

if !exists('g:auto_pairs#map_space')
  let g:auto_pairs#map_space = 1
end

if !exists('g:auto_pairs#center_line')
  let g:auto_pairs#center_line = 1
end

if !exists('g:auto_pairs#shortcut_toggle')
  let g:auto_pairs#shortcut_toggle = '<M-p>'
end

if !exists('g:auto_pairs#shortcut_fast_wrap')
  let g:auto_pairs#shortcut_fast_wrap = '<M-e>'
end

if !exists('g:auto_pairs#shortcut_jump')
  let g:auto_pairs#shortcut_jump = '<M-n>'
endif

" Fly mode will for closed pair to jump to closed pair instead of insert.
" also support auto_pairs#back_insert to insert pairs where jumped.
if !exists('g:auto_pairs#fly_mode')
  let g:auto_pairs#fly_mode = 0
endif

" Work with Fly Mode, insert pair where jumped
if !exists('g:auto_pairs#shortcut_back_insert')
  let g:auto_pairs#shortcut_back_insert = '<M-b>'
endif

if !exists('g:auto_pairs#smart_quotes')
  let g:auto_pairs#smart_quotes = 1
endif

" Will auto generated {']' => '[', ..., '}' => '{'}in initialize.
let g:auto_pairs#closed_pairs = {}

au BufEnter * :call auto_pairs#try_init()
" Always silent the command
" inoremap <silent> auto_pairs#return <C-R>=auto_pairs#return()<CR>
" imap <script> <Plug>auto_pairs#return auto_pairs#return
