local stateful = require'scripts/metas/stateful'

local hero_meta = sol.main.get_metatable('hero')

stateful.setup_meta(hero_meta)

hero_meta.net_enabled = nil --we don't want maps to auto-declare the hero
