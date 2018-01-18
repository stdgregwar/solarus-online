require'scripts/libs/utils'
local network = require'scripts/networking/networking'
local mutils = require'scripts/networking/mob_utils'
local mob_meta = require'scripts/metas/mob'
local bdmap = require'scripts/libs/bidirmap'
local mk = require'scripts/libs/multikey'

local enemy_meta = sol.main.get_metatable'enemy'

mob_meta.setup_meta(enemy_meta)

-- save old life functions
enemy_meta.__set_life = enemy_meta.set_life
enemy_meta.__remove_life = enemy_meta.remove_life
enemy_meta.__add_life = enemy_meta.add_life
enemy_meta.__get_life = enemy_meta.get_life

------------------------------------------------
-- replace all life-related primitives by
-- server-synced ones, this allow to transmit life
-- across network and fully sync mob life cycles
-------------------------------------------------
function enemy_meta:set_life(life)
  self.state.life = life
  if self.state.life <= 0 then
    --TODO : trigger enemy death
    --self:die()
  end
end

function enemy_meta:add_life(life)
  self:set_life(self:get_life() + life)
end

function enemy_meta:remove_life(life)
  self:add_life(-life)
end

function enemy_meta:get_life()
  return self.state.life
end

function enemy_meta:alive()
  return self.state.life and self.state.life > 0
end

local old_hurt = enemy_meta.hurt

--------------------------------------------------
-- the new hurt function prevent the engine from
-- counting life of the enemies
-- and allow remote clients to hurt the mobs
--------------------------------------------------
function enemy_meta:hurt(life_points)
  -- TODO substract life
  self:remove_life(life_points)
  old_hurt(self,0)
end

---------------------------------------------------
-- for the hurt events that are fully managed by
-- the engine, we hack the life loss by reporting
-- the life delta on the mob synced state and
-- restoring the MAX_LIVE constant into the engine
-- life count
---------------------------------------------------
function enemy_meta:on_hurt(attack)
  local damage = mob_meta.MAX_LIVE - self:__get_life() --compute damage taken
  self:__set_life(mob_meta.MAX_LIVE) -- make the enemy immortal for the engine
  self:remove_life(damage)
end

local attacks = {'sword','thrown_item','explosion','arrow','hookshot','boomerang','fire'}

-----------------------------------------------------
-- set attack consequence to be custom on all sprites
-----------------------------------------------------
function enemy_meta:all_sprites_to_custom_conseq()
  self:save_sprites_conseqs()
  for _,a in ipairs(attacks) do
    self:set_attack_consequence(a,'custom')
  end
end

------------------------------------------------------------------------
-- save all sprites consequences in case mob is promoted master later
------------------------------------------------------------------------
function enemy_meta:save_sprites_conseqs()
  local cons = {}
  for _,s in ipairs(self.__sprite_map) do
    for _,a in ipairs(attacks) do
      table.insert(cons,{sprite=s,attack=a,cons=self:get_attack_consequence_sprite(s,a)})
    end
  end
  self.__sprites_conseqs = cons
end

------------------------------------------------------
-- restore previously saved sprites consequences
------------------------------------------------------
function enemy_meta:restore_sprites_conseqs()
  local cons = self.__sprites_conseqs or {}
  for _,p in ipairs(cons) do
    self:set_attack_consequence_sprite(p.sprite,p.attack,p.cons)
  end
end

--ensure sprite translation state is well defined
function enemy_meta:__ensure_sprite_vars()
  self.__sprite_map = self.__sprite_map or bdmap.new()
  self.__sprite_count = self.__sprite_count or 0
end

enemy_meta.respawn_time = 10;

-------------------------------------------------------------------
-- tells if the mob should respawn given the state from the server
-------------------------------------------------------------------
function enemy_meta:should_respawn()
  return self.state.death_time + self.respawn_time < network.server_time_s()
end

------------------------------------------------------------
-- makes the master mob respawn, restarting its simulation
------------------------------------------------------------
function enemy_meta:master_respawn()
  self:set_life(self.max_life)
  self:set_enabled(true)
  network.send({type='mob_activated',mob_id=self.net_id})
  safe(self.on_mob_restarted)(self)
end

local old_enabled = enemy_meta.set_enabled
function enemy_meta:set_enabled(en)
  local was_en = self:is_enabled()
  old_enabled(self,en)
  if (en == nil or (en ~= nil and en)) and not was_en then
    for _,s in self:get_sprites() do
      s:fade_in(5)
    end
  end
end

----------------------------------------------------------
-- makes the enemy disabled by default, waiting for the
-- server to promote the mod, maybe starting it
----------------------------------------------------------
enemy_meta:register_event('on_created',function(self)
                            self:set_enabled(false) --disable mob by default
end)

function enemy_meta:pushed()
  return self.__pushed;
end

------------------------------------------------------
--Called when client is selected to simulate the enemy
------------------------------------------------------
function enemy_meta:on_master_prom(op_state) --replace mob:on_master_prom
  --put basic callbacks to reflect movement and actions over net
  mutils.make_mob_master_basics(self,self.net_id,network)
  -- setup network-synchronised state
  self:setup_net_state(op_state)

  --restore sprite conseqs (in case mob was remote before)
  self:restore_sprites_conseqs()
  safe(self.on_mob_master_setup)(self)

  --test wheter enemy should respawn or something
  if self:alive() then --mob is already alive
    --mob is still alive
    --send active mob message
    self:set_enabled()
    --network.send({type='mob_activated',mob_id=self.net_id})
    safe(self.on_mob_restarted)(self)
  else -- mob should respawn in a while
    self:set_life(0)
    self:start_respawn_timer()
  end

  function self:on_restarted()
    self.__pushed = nil
    if not self:alive() then
      self:master_die()
    end
    safe(self.on_mob_restarted)(self)
  end

  function self:on_custom_attack_received(attack,sprite)
    safe(self.on_mob_custom_attack_received)(self,
                                             attack,
                                             sprite,
                                             self:get_map():get_hero())
  end
end

---------------------------------------------------------------
--Called when mob needs to be prepared for remote control
---------------------------------------------------------------
function enemy_meta:on_remote_prom(op_state) --replace mob:on_remote_prom
  self:all_sprites_to_custom_conseq()

  self.state = op_state or self.state or {} --remote mob replace it's state

  if self:alive() then -- if server state say mob is alive : activate
    self:set_enabled()
  end

  --send all attacks received trough network
  function self:on_custom_attack_received(attack,sprite)
    local sprite_num = self.__sprite_map[sprite]
    if sprite_num then
      network.send({type='mob_attacked',
                    sprite=sprite_num,
                    attack=attack,
                    mob_id=self.net_id,
                    hero_id=network.guid})
    end
  end
end
-----------------------------------------------------------
-- make the master mob die and send the event over network
-----------------------------------------------------------
function enemy_meta:master_die()
  --send the good new over the network
  network.send({type='mob_death',mob_id=self.net_id})
  self:die()
  --register death time
  self.state.death_time = network.server_time_s()
  --start respawn timer
  self:start_respawn_timer()
end

----------------------------------------------------------
-- plays the enemy dying animation and disable the entity
----------------------------------------------------------
function enemy_meta:die()
  self:immobilize()
  
  local map = self:get_map()
  local x,y,z = self:get_position()
  local death = map:create_custom_entity{
    direction=0,
    layer=z,x=x,y=y,
    width=16,height=16,
    model='animation'
  }

  death:play('enemies/enemy_killed','killed')
  sol.audio.play_sound('enemy_killed')
  sol.timer.start(self,125,function()
                    self:set_enabled(false)
                    self:get_movement():stop()
        safe(self.on_dying)(self)
  end)
end

-------------------------------------------------
-- start the respawn timer, allowing to let the
-- entity sleep when the mob is temporarly dead
-------------------------------------------------
function enemy_meta:start_respawn_timer()
  local function respawn()
    if self:should_respawn() then
      self:master_respawn()
      return false
    end
    return true
  end
  if respawn() then
    sol.timer.start(self:get_map(),1000,respawn)
  end
end

----------------------------------------------------
-- push the enemy pretty much like the engine does
----------------------------------------------------
function enemy_meta:push_back(pusher, max_dist)
  local max_dist = max_dist or 26
  local x, y = self:get_position()
  local angle = self:get_angle(pusher) + math.pi
  local old_mov = self:get_movement()
  local function restore_mov()
    self.__pushed = false
    self:get_movement():stop()
    if old_mov then old_mov:start(self) end
    safe(self.on_restarted)(self)
  end
  local movement = sol.movement.create("straight")
  movement:set_speed(128)
  movement:set_angle(angle)
  movement:set_max_distance(max_dist)
  movement:set_smooth(true)
  self.__pushed = true
  movement:start(self,restore_mov)
  function movement:on_obstacle_reached()
    restore_mov()
  end
end

---------------------------------------------------------
-- make a certain amount of regular dommage to the enemy
-- pushing it if this is enabled
---------------------------------------------------------
function enemy_meta:take_normal_damage(entity,attack,life_points)
  if self:is_pushed_back_when_hurt() then
    self:push_back(entity);
  end
  self:hurt(life_points)
end

--save old create sprite routine
local old_create_sprite = enemy_meta.create_sprite

--------------------------------------------------------
-- replace create_sprite with a version that store
-- a sprite id in a bidirectionalmap, to allow to discriminate
-- sprites over the network
--------------------------------------------------------
function enemy_meta:create_sprite(sprite_sheet)
  self:__ensure_sprite_vars()
  self.__sprite_count = self.__sprite_count + 1
  local sprite = old_create_sprite(self,sprite_sheet)
  self.__sprite_map[self.__sprite_count]  = sprite
  return sprite
end


