-- Initialize NPC behavior specific to this quest.
local mob = require'scripts/metas/mob'

local npc_meta = sol.main.get_metatable("npc")

mob.setup_meta(npc_meta)

function npc_meta:on_created()

  local name = self:get_name()
  if name == nil then
    return
  end

  print('NPC CREATED',name)

  if name:find("walking_npc") then
    self:random_walk()
  end
end

-- Make signs hooks for the hookshot.
function npc_meta:is_hookable()

  local sprite = self:get_sprite()
  if sprite == nil then
    return false
  end

  return sprite:get_animation_set() == "entities/sign"
end

-- Makes the NPC randomly walk with the given optional speed.
function npc_meta:random_walk(speed)

  print('RANDOM WALK')
  local movement = sol.movement.create("random_path")

  if speed ~= nil then
    movement:set_speed(speed)
  end

  movement:start(self)
end

return true
