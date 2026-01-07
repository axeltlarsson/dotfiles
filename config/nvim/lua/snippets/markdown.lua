local ls = require('luasnip')
local s = ls.snippet
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local d = ls.dynamic_node
local sn = ls.snippet_node
local fmt = require('luasnip.extras.fmt').fmt

return {
  -- Dynamic date snippet
  s('today', {
    f(function() return os.date('%F') end),
  }),

  -- Todo checkbox
  s('todo', {
    t('[ ] '), i(0),
  }),

  -- Wiki-style hyperlink
  s('h', {
    t('[['), i(1), t(']]'), i(0),
  }),

  -- New day template
  s('day', {
    t('# '), f(function() return os.date('%F %A') end), t({ '', '', '## TODO', '', '- [ ] <https://mail.google.com/mail/u/0/>', '- [ ] <https://github.com/notifications>', '- ' }), i(0),
  }),

  -- Dynamic box that resizes based on content
  s('box', {
    d(1, function(_, snip)
      local text = snip.env.LS_SELECT_RAW[1] or ''
      if text == '' then
        return sn(nil, {
          t('┌──┐'), t({ '', '│ ' }), i(1), t({ ' │', '└──┘' }), t({ '', '' }), i(0),
        })
      end
      local top = '┌' .. string.rep('─', #text + 2) .. '┐'
      local bot = '└' .. string.rep('─', #text + 2) .. '┘'
      return sn(nil, {
        t({ top, '│ ' .. text .. ' │', bot, '' }), i(0),
      })
    end),
  }),

  -- Sections
  s('sec', fmt('# {} #\n{}', { i(1, 'Section Name'), i(0) })),
  s('ssec', fmt('## {} ##\n{}', { i(1, 'Section Name'), i(0) })),
  s('sssec', fmt('### {} ###\n{}', { i(1, 'Section Name'), i(0) })),
  s('par', fmt('#### {} ####\n{}', { i(1, 'Paragraph Name'), i(0) })),
  s('spar', fmt('##### {} #####\n{}', { i(1, 'Paragraph Name'), i(0) })),

  -- Text formatting
  s('italic', { t('*'), i(1), t('*'), i(0) }),
  s('bold', { t('**'), i(1), t('**'), i(0) }),
  s('bolditalic', { t('***'), i(1), t('***'), i(0) }),

  -- Comment
  s('comment', { t('<!-- '), i(1), t(' -->'), i(0) }),

  -- Link
  s('link', fmt('[{}]({})\n{}', { i(1, 'Text'), i(2, 'https://www.url.com'), i(0) })),

  -- Image
  s('img', fmt('![{}]({}){}\n{}', { i(1, 'alt'), i(2, 'path'), i(3), i(0) })),

  -- Inline code
  s('ilc', { t('`'), i(1), t('`'), i(0) }),

  -- Code block
  s('cbl', { t('```'), i(1), t({ '', '' }), i(2), t({ '', '```', '' }), i(0) }),

  -- Reference link
  s('refl', fmt('[{}][{}]\n\n[{}]:{} "{}"\n{}', {
    i(1, 'Text'), i(2, 'id'), f(function(args) return args[1][1] end, { 2 }), i(3, 'https://www.url.com'), i(4), i(0)
  })),

  -- Footnote
  s('fnt', fmt('[^{}]\n\n[^{}]:{}\n{}', {
    i(1, 'Footnote'), f(function(args) return args[1][1] end, { 1 }), i(2, 'Text'), i(0)
  })),

  -- Details/disclosure
  s('detail', fmt([[
<details{}>
  {}{}
</details>
{}]], {
    i(1, ' open=""'),
    i(2, '<summary></summary>'),
    i(3),
    i(0),
  })),
}
