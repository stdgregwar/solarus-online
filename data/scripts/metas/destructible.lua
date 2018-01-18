local mob = require'scripts/metas/mob'

local des_meta = sol.main.get_metatable('destructible')

des_meta.displayed_name = 'destructible'

function des_meta:destroyed()
  return self:get_sprite():get_animation() == 'destroy' or not self:exists()
end
