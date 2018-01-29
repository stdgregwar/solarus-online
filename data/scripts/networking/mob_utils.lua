local utils = {}

local vector = require'scripts/Vector'
local actions = require'scripts/metas/actions'
local o_utils = require'scripts/libs/utils'

local hpi = 3.1415 / 2

local function angle_from_dir(dir)
  return dir*hpi; 
end

--TODO take circle into account
local function mov_type_map(type)
  if type == "target" or type == 'jump'then
    return type;
  else
    return "straight"
  end
end

--create mov if the desired type does not match 
function utils.mov_or_else(mov,type)
  local type = mov_type_map(type)
  if mov and sol.main.get_type(mov) == type then
    return mov;
  else
    --create new movement
    return sol.movement.create(type)
  end
end

local interp_time = 16*4 -- milliseconds
local tp_tolerance = 2 -- 2px teleport isn't that bad
local tp_threshold = 1200 -- 400px is certainly too big to keep up

function cancel_mov(ent)
  if ent.__mov_timer then
    ent.__mov_timer:stop()
  end
end

-- add intermediary movement to smoothely interpolate to next move
-- adding a target move to keep up with the new move without teleporting
-- the entity
function interpolate_movement(ent,old_pos,target_pos,new_mov)
  --TEST TODO verify which is better
  --return new_mov

  local oldx = vector(old_pos.x,old_pos.y)
  local newx = vector(target_pos.x,target_pos.y)

  local dist = (oldx-newx):len()

  if dist < tp_tolerance or dist > tp_threshold then
    -- if position haven't drifted that much
    -- just tp the entity to it's new position
    -- and apply the new deserialised movement
    -- same if the position is far away
    cancel_mov(ent)
    ent:set_position(newx.x,newx.y)
    return new_mov
  end

  local angle = new_mov:get_angle()

  local nspeed = vector.fromPolar(new_mov:get_speed(),new_mov:get_angle())

  -- compute q = x + t_interp * speed_nMov
  local t_interp = interp_time / 1000.0
  local q = newx + t_interp*nspeed

  --compute scalar speed of the transition move
  local tspeed = (q-oldx):len() / t_interp

  --make target movement that will preceed the other movement
  local tmov = sol.movement.create('target')
  tmov:set_ignore_obstacles(true)
  tmov:set_target(q.x,q.y)
  tmov:set_smooth(false)

  cancel_mov(ent)

  --start timer to switch to new movement
  ent.__mov_timer = sol.timer.start(ent,interp_time,function()
                                      --ensure we are at point q
                                      ent:set_position(q.x,q.y)
                                      --start the new_move
                                      new_mov:start(ent)
  end)

  return tmov
  --return new_mov
end

local straight_properties = {
  'angle',
  'speed'
}

local jump_properties = {
  'direction8',
  'distance',
  'speed'
}

local type_to_interp = {
  target = true,
  straight = true,
}

--unserialize entity movement
function utils.movement_from_net(self,tb,network)
  local old_mov = self:get_movement()
  local mov = utils.mov_or_else(old_mov,tb.type)
  if tb.type == 'target' then
    if tb.entity then
      local map = self:get_map()
      local ent = network.get_entity(tb.entity);
      mov:set_target(ent,tb.ox,tb.oy)
    else
      mov:set_target(tb.x,tb.y)
    end
  elseif tb.type == 'jump' then
    o_utils.apply_properties(mov,tb)
    mov:set_ignore_obstacles(true)
  else --move is a straight move
    mov:set_angle(tb.angle or 0)
  end
  mov:set_speed(tb.speed)
  if tb.max_dist then mov:set_max_distance(tb.max_dist) end
  local x,y = self:get_position()
  self.__pushed = tb.pushed


  local true_mov = mov
  if type_to_interp[mov_type_map(tb.type)] then
    true_mov = interpolate_movement(self,
                                    {x=x,y=y},
                                    tb.pos,
                                    mov)
  end
  if true_mov ~= old_mov then true_mov:start(self) end
end

local function serialize_movement(mob,mov)
  local type = sol.main.get_type(mov)
  local szs = {}
  function szs.straight_movement(mov)
    local max_dist
    if mov.get_max_distance then
      max_dist = mov:get_max_distance()
    end
    return {angle=mov:get_angle(),
            speed=mov:get_speed(),
            max_dist=max_dist}
  end

  szs.random_movement = szs.straight_movement
  function szs.target_movement(mov)
    local entname
    if mov.target_entity then
      entname = mov.target_entity.net_id
    end
    return {target_type=mov.target_type,
            x=mov.target_x,
            y=mov.target_y,
            ox=mov.offset_x,
            oy=mov.offset_y,
            speed=mov:get_speed(),
            entity=entname}
  end
  function szs.jump_movement(mov)
    return o_utils.object_to_properties(mov,jump_properties)
  end
  szs.path_finding_movement = szs.straight_movement
  szs.random_path_movement = szs.straight_movement
  --TODO : add circular movement
  local f = szs[type] or function() return {} end
  local tab = f(mov)

  --add type of movement and current position
  tab.type = type:sub(1,-10) --remove _movement
  local x,y,l = mob:get_position()
  tab.pos = {x=x,y=y,layer=l}
  --add main sprite direction :
  local sprite = mob:get_sprite()
  if sprite then
    tab.dir = sprite:get_direction()
  end
  tab.pushed = mob.__pushed
  return tab
end

--Allow to send data by network to fully mirror movement of a mob
function utils.make_mob_master_basics(mob,id,network,prefix)
  local send = network.send
  prefix = prefix or 'mob'

  --set animation changes callbacks
  --for name, sp in mob:get_sprites() do
  --function sp:on_animation_changed(anim)
  --send({type="hero_anim",anim=anim})
  --send_hero_pos()
  --end 
  --end

  -- make filter to avoid packet repeat because of move change
  local fast_send = network.make_anti_repeat_send(send)

  local mpname = prefix..'_move'

  --make a local movement filter to avoid sending target movement at each frames
  local last_mov = {type='straigt'}
  local last_time = network.server_time_s()
  local target_recover_s = 0.1
  local function mov_send(mov)
    local time = network.server_time_s()
    if last_mov.type == mov.type and
      mov.type == 'target' and
      mov.target_type == 'entity' and
    last_mov.target_type == 'entity' then
      if last_mov.entity ~= mov.entity or
      time-last_time > target_recover_s then
        last_mov = mov
        last_time = time
        send({type=mpname,id=id,move=mov})
      end
    else --regular movements or xy targets...
      last_mov = mov
      last_time = time
      fast_send({type=mpname,id=id,move=mov})
    end
  end

  --set movement changes
  mob:register_event('on_movement_changed', function(self,mov)
                       --print(mov)
                       mov_send(serialize_movement(mob,mov))
                       --send_mob_pos()
  end)
  

  --setup action replication for remotes controlled entities
  local maname = prefix..'_action'
  actions.make_net_action(mob,network,maname)
end

return utils
