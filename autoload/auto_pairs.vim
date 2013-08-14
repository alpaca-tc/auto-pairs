function! auto_pairs#insert(key) "{{{
  if !b:autopairs_enabled
    return a:key
  end

  let line = getline('.')
  let pos = col('.') - 1
  let before = strpart(line, 0, pos)
  let after = strpart(line, pos)
  let next_chars = split(after, '\zs')
  let current_char = get(next_chars, 0, '')
  let next_char = get(next_chars, 1, '')
  let prev_chars = split(before, '\zs')
  let prev_char = get(prev_chars, -1, '')

  let eol = 0
  if col('$') -  col('.') <= 1
    let eol = 1
  end

  " Ignore auto close if prev character is \
  if prev_char == '\'
    return a:key
  end

  " The key is difference open-pair, then it means only for ) ] } by default
  if !has_key(b:AutoPairs, a:key)
    let b:autopairs_saved_pair = [a:key, getpos('.')]

    " Skip the character if current character is the same as input
    if current_char == a:key
      return "\<Right>"
    end

    if !g:auto_pairs#fly_mode
      " Skip the character if next character is space
      if current_char == ' ' && next_char == a:key
        return "\<Right>\<Right>"
      end

      " Skip the character if closed pair is next character
      if current_char == ''
        let next_lineno = line('.')+1
        let next_line = getline(nextnonblank(next_lineno))
        let next_char = matchstr(next_line, '\s*\zs.')
        if next_char == a:key
          return "\<ESC>e^a"
        endif
      endif
    endif

    " Fly Mode, and the key is closed-pairs, search closed-pair and jump
    if g:auto_pairs#fly_mode && has_key(b:AutoPairsClosedPairs, a:key)
      if search(a:key, 'W')
        return "\<Right>"
      endif
    endif

    " Insert directly if the key is not an open key
    return a:key
  end

  let open = a:key
  let close = b:AutoPairs[open]

  if current_char == close && open == close
    return "\<Right>"
  end

  " Ignore auto close ' if follows a word
  " MUST after closed check. 'hello|'
  if a:key == "'" && prev_char =~ '\v\w'
    return a:key
  end

  " support for ''' ``` and """
  if open == close
    " The key must be ' " `
    let pprev_char = line[col('.')-3]
    if pprev_char == open && prev_char == open
      " Double pair found
      return repeat(a:key, 4) . repeat("\<LEFT>", 3)
    end
  end

  let quotes_num = 0
  " Ignore comment line for vim file
  if &filetype == 'vim' && a:key == '"'
    if before =~ '^\s*$'
      return a:key
    end
    if before =~ '^\s*"'
      let quotes_num = -1
    end
  end

  " Keep quote number is odd.
  " Because quotes should be matched in the same line in most of situation
  if g:auto_pairs#smart_quotes && open == close
    " Remove \\ \" \'
    let cleaned_line = substitute(line, '\v(\\.)', '', 'g')
    let n = quotes_num
    let pos = 0
    while 1
      let pos = stridx(cleaned_line, open, pos)
      if pos == -1
        break
      end
      let n = n + 1
      let pos = pos + 1
    endwhile
    if n % 2 == 1
      return a:key
    endif
  endif

  return open.close."\<Left>"
endfunction"}}}

function! auto_pairs#delete() "{{{
  if !b:autopairs_enabled
    return "\<BS>"
  end

  let line = getline('.')
  let pos = col('.') - 1
  let current_char = get(split(strpart(line, pos), '\zs'), 0, '')
  let prev_chars = split(strpart(line, 0, pos), '\zs')
  let prev_char = get(prev_chars, -1, '')
  let pprev_char = get(prev_chars, -2, '')

  if pprev_char == '\'
    return "\<BS>"
  end

  " Delete last two spaces in parens, work with MapSpace
  if has_key(b:AutoPairs, pprev_char) && prev_char == ' ' && current_char == ' '
    return "\<BS>\<DEL>"
  endif

  " Delete Repeated Pair eg: '''|''' [[|]] {{|}}
  if has_key(b:AutoPairs, prev_char)
    let times = 0
    let p = -1
    while get(prev_chars, p, '') == prev_char
      let p = p - 1
      let times = times + 1
    endwhile

    let close = b:AutoPairs[prev_char]
    let left = repeat(prev_char, times)
    let right = repeat(close, times)

    let before = strpart(line, pos-times, times)
    let after  = strpart(line, pos, times)
    if left == before && right == after
      return repeat("\<BS>\<DEL>", times)
    end
  end


  if has_key(b:AutoPairs, prev_char) 
    let close = b:AutoPairs[prev_char]
    if match(line,'^\s*'.close, col('.')-1) != -1
      " Delete (|___)
      let space = matchstr(line, '^\s*', col('.')-1)
      return "\<BS>". repeat("\<DEL>", len(space)+1)
    elseif match(line, '^\s*$', col('.')-1) != -1
      " Delete (|__\n___)
      let nline = getline(line('.')+1)
      if nline =~ '^\s*'.close
        if &filetype == 'vim' && prev_char == '"'
          " Keep next line's comment
          return "\<BS>"
        end

        let space = matchstr(nline, '^\s*')
        return "\<BS>\<DEL>". repeat("\<DEL>", len(space)+1)
      end
    end
  end

  return "\<BS>"
endfunction"}}}

function! auto_pairs#jump() "{{{
  call search('["\]'')}]','W')
endfunction"}}}

" string_chunk cannot use standalone
let s:string_chunk = '\v%(\\\_.|[^\1]|[\r\n]){-}'
let s:ss_pattern = '\v''' . s:string_chunk . ''''
let s:ds_pattern = '\v"'  . s:string_chunk . '"'

function! s:regexp_quote(str) "{{{
  return substitute(a:str, '\v[\[\{\(\<\>\)\}\]]', '\\&', 'g')
endfunction"}}}

function! s:regexp_quote_in_square(str) "{{{
  return substitute(a:str, '\v[\[\]]', '\\&', 'g')
endfunction "}}}

" Search next open or close pair
function! s:format_chunk(open, close) "{{{
  let open = s:regexp_quote(a:open)
  let close = s:regexp_quote(a:close)
  let open2 = s:regexp_quote_in_square(a:open)
  let close2 = s:regexp_quote_in_square(a:close)
  if open == close
    return '\v'.open.s:string_chunk.close
  else
    return '\v%(' . s:ss_pattern . '|' . s:ds_pattern . '|' . '[^'.open2.close2.']|[\r\n]' . '){-}(['.open2.close2.'])'
  end
endfunction"}}}

" Fast wrap the word in brackets
function! auto_pairs#fast_wrap() "{{{
  let line = getline('.')
  let current_char = line[col('.')-1]
  let next_char = line[col('.')]
  let open_pair_pattern = '\v[({\[''"]'
  let at_end = col('.') >= col('$') - 1
  normal x
  " Skip blank
  if next_char =~ '\v\s' || at_end
    call search('\v\S', 'W')
    let line = getline('.')
    let next_char = line[col('.')-1]
  end

  if has_key(b:AutoPairs, next_char)
    let followed_open_pair = next_char
    let inputed_close_pair = current_char
    let followed_close_pair = b:AutoPairs[next_char]
    if followed_close_pair != followed_open_pair
      " TODO replace system searchpair to skip string and nested pair.
      " eg: (|){"hello}world"} will transform to ({"hello})world"}
      call searchpair('\V'.followed_open_pair, '', '\V'.followed_close_pair, 'W')
    else
      call search(s:format_chunk(followed_open_pair, followed_close_pair), 'We')
    end
    return "\<RIGHT>".inputed_close_pair."\<LEFT>"
  else
    normal he
    return "\<RIGHT>".current_char."\<LEFT>"
  end
endfunction"}}}

function! auto_pairs#map(key) "{{{
  " | is special key which separate map command from text
  let key = a:key
  if key == '|'
    let key = '<BAR>'
  end
  let escaped_key = substitute(key, "'", "''", 'g')
  " use expr will cause search() doesn't work
  execute 'inoremap <buffer> <silent> '.key." <C-R>=auto_pairs#insert('".escaped_key."')<CR>"
endfunction"}}}

function! auto_pairs#toggle() "{{{
  if b:autopairs_enabled
    let b:autopairs_enabled = 0
    echo 'AutoPairs Disabled.'
  else
    let b:autopairs_enabled = 1
    echo 'AutoPairs Enabled.'
  end
  return ''
endfunction"}}}

function! auto_pairs#return() "{{{
  if b:autopairs_enabled == 0
    return ''
  end
  let line = getline('.')
  let pline = getline(line('.')-1)
  let prev_char = pline[strlen(pline)-1]
  let cmd = ''
  let cur_char = line[col('.')-1]
  if has_key(b:AutoPairs, prev_char) && b:AutoPairs[prev_char] == cur_char
    if g:auto_pairs#center_line && winline() * 3 >= winheight(0) * 2
      " Use \<BS> instead of \<ESC>cl will cause the placeholder deleted
      " incorrect. because <C-O>zz won't leave Normal mode.
      " Use \<DEL> is a bit wierd. the character before cursor need to be deleted.
      let cmd = " \<C-O>zz\<ESC>cl"
    end

    " If equalprg has been set, then avoid call =
    " https://github.com/jiangmiao/auto-pairs/issues/24
    if &equalprg != ''
      return "\<ESC>O".cmd
    endif

    " conflict with javascript and coffee
    " javascript   need   indent new line
    " coffeescript forbid indent new line
    if &filetype == 'coffeescript' || &filetype == 'coffee'
      return "\<ESC>k==o".cmd
    else
      return "\<ESC>=ko".cmd
    endif
  end
  return ''
endfunction"}}}

function! auto_pairs#space() "{{{
  let line = getline('.')
  let prev_char = line[col('.')-2]
  let cmd = ''
  let cur_char =line[col('.')-1]
  if has_key(g:auto_pairs#parens, prev_char) && g:auto_pairs#parens[prev_char] == cur_char
    let cmd = "\<SPACE>\<LEFT>"
  endif
  return "\<SPACE>".cmd
endfunction"}}}

function! auto_pairs#back_insert() "{{{
  if exists('b:autopairs_saved_pair')
    let pair = b:autopairs_saved_pair[0]
    let pos  = b:autopairs_saved_pair[1]
    call setpos('.', pos)
    return pair
  endif
  return ''
endfunction"}}}

function! auto_pairs#init() "{{{
  let b:autopairs_loaded  = 1
  let b:autopairs_enabled = 1
  let b:AutoPairsClosedPairs = {}

  if !exists('b:AutoPairs')
    let b:AutoPairs = g:auto_pairs
  end

  " buffer level map pairs keys
  for [open, close] in items(b:AutoPairs)
    call auto_pairs#map(open)
    if open != close
      call auto_pairs#map(close)
    end
    let b:AutoPairsClosedPairs[close] = open
  endfor

  " Still use <buffer> level mapping for <BS> <SPACE>
  if g:auto_pairs#map_bs
    " Use <C-R> instead of <expr> for issue #14 sometimes press BS output strange words
    execute 'inoremap <buffer> <silent> <BS> <C-R>=auto_pairs#delete()<CR>'
    execute 'inoremap <buffer> <silent> <C-H> <C-R>=auto_pairs#delete()<CR>'
  end

  if g:auto_pairs#map_space
    " Try to respect abbreviations on a <SPACE>
    let do_abbrev = ""
    if v:version >= 703 && has("patch489")
      let do_abbrev = "<C-]>"
    endif
    execute 'inoremap <buffer> <silent> <SPACE> '.do_abbrev.'<C-R>=auto_pairs#space()<CR>'
  end

  if g:auto_pairs#shortcut_fast_wrap != ''
    execute 'inoremap <buffer> <silent> '.g:auto_pairs#shortcut_fast_wrap.' <C-R>=auto_pairs#fast_wrap()<CR>'
  end

  if g:auto_pairs#shortcut_back_insert != ''
    execute 'inoremap <buffer> <silent> '.g:auto_pairs#shortcut_back_insert.' <C-R>=auto_pairs#back_insert()<CR>'
  end

  if g:auto_pairs#shortcut_toggle != ''
    " use <expr> to ensure showing the status when toggle
    execute 'inoremap <buffer> <silent> <expr> '.g:auto_pairs#shortcut_toggle.' auto_pairs#toggle()'
    execute 'noremap <buffer> <silent> '.g:auto_pairs#shortcut_toggle.' :call auto_pairs#toggle()<CR>'
  end

  if g:auto_pairs#shortcut_jump != ''
    execute 'inoremap <buffer> <silent> ' . g:auto_pairs#shortcut_jump. ' <ESC>:call auto_pairs#jump()<CR>a'
    execute 'noremap <buffer> <silent> ' . g:auto_pairs#shortcut_jump. ' :call auto_pairs#jump()<CR>'
  end

endfunction"}}}

function! s:expand_map(map) "{{{
  let map = a:map
  let map = substitute(map, '\(<Plug>\w\+\)', '\=maparg(submatch(1), "i")', 'g')
  return map
endfunction"}}}

function! auto_pairs#try_init() "{{{
  if exists('b:autopairs_loaded')
    return
  end

  " for auto-pairs starts with 'a', so the priority is higher than supertab and vim-endwise
  "
  " vim-endwise doesn't support <Plug>auto_pairs#return
  " when use <Plug>auto_pairs#return will cause <Plug> isn't expanded
  "
  " supertab doesn't support <SID>auto_pairs#return
  " when use <SID>auto_pairs#return  will cause Duplicated <CR>
  "
  " and when load after vim-endwise will cause unexpected endwise inserted. 
  " so always load AutoPairs at last
  
  " Buffer level keys mapping
  " comptible with other plugin
  if g:auto_pairs#map_cr
    if v:version >= 703 && has('patch32')
      " VIM 7.3 supports advancer maparg which could get <expr> info
      " then auto-pairs could remap <CR> in any case.
      let info = maparg('<CR>', 'i', 0, 1)
      if empty(info)
        let old_cr = '<CR>'
        let is_expr = 0
      else
        let old_cr = info['rhs']
        let old_cr = s:expand_map(old_cr)
        let old_cr = substitute(old_cr, '<SID>', '<SNR>' . info['sid'] . '_', 'g')
        let is_expr = info['expr']
        let wrapper_name = '<SID>AutoPairsOldCRWrapper73'
      endif
    else
      " VIM version less than 7.3
      " the mapping's <expr> info is lost, so guess it is expr or not, it's
      " not accurate.
      let old_cr = maparg('<CR>', 'i')
      if old_cr == ''
        let old_cr = '<CR>'
        let is_expr = 0
      else
        let old_cr = s:expand_map(old_cr)
        " old_cr contain (, I guess the old cr is in expr mode
        let is_expr = old_cr  =~ '\V(' && toupper(old_cr) !~ '\V<C-R>'
        let wrapper_name = '<SID>AutoPairsOldCRWrapper'
      end
    end

    if old_cr !~ 'auto_pairs#return'
      if is_expr
        " remap <expr> to `name` to avoid mix expr and non-expr mode
        execute 'inoremap <buffer> <expr> <script> '. wrapper_name . ' ' . old_cr
        let old_cr = wrapper_name
      end
      " Always silent mapping

      execute 'inoremap <script><buffer><silent><CR> '.old_cr.'<SID>auto_pairs#return'
    end
  endif
  call auto_pairs#init()
endfunction"}}}
