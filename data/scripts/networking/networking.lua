-------------------------------------------------------
-- this network 'class' is the entry point of
-- Solarus Online. It encapsulate the management of the
-- connection and packet sending/serializing.
-- any lua scripts can use network.send(table) to send
-- a table to the server.
--
-- Receiving message is done by adding an handler for a
-- particular message 'type'
-------------------------------------------------------

-- some usefull utilitary functions
require'scripts/libs/utils'

-- for net message serialization
local json = require'json'

-- network communication
local socket = require'socket'

-- to make unique names more easily
local sha2 = require'scripts/libs/sha2'

-- mobile objects handling primitives
local mob_utils = require'scripts/networking/mob_utils'

-- hero network utils
local hero_utils = require'scripts/networking/hero'

--make send and receive raising error by default
local function offline_send(data)
  print("Not connected : not sending")
end

local function offline_receive(pat)
   return {type="error", err = "Not connected"}
end


local network = {
  guid = 0,
  send = offline_send,
  receive = offline_receive
}

--utility function to make work around some solarus events
--that tends to trigger to much in a single frame
function network.make_anti_repeat_send(send)
  local last = nil
  return function(data)
    if not deep_compare(data,last) then
      last = data;
      send(data)
    end --don't resend identical message
  end
end

-- same as make_anti_repeat_send but with only one field
function network.make_anti_repeat_send_field(send,field)
  local last = nil
  return function(data)
    if not deep_compare(data[field],last) then
      last = data[field]
      send(data)
    end
  end
end

--gives the synced server time in milliseconds
-- TODO compensate ping
function network.server_time_ms()
  --TODO synchronise time more than once at the beginning
  return sol.main.get_elapsed_time() + network.time_offset;
end

--gives the server time in seconds
function network.server_time_s()
  return network.server_time_ms() / 1000
end

--Network stats updater, to be ran every second
function update_stats()
  --init stats if not done
  network.stats = network.stats or {msg_count = 0,ch_count_down=0,ch_count_up=0,kbs_up=0,kbs_down=0}
  local stats = network.stats
  
  --TODO Stat update mechanism should be updated, affined in the future
  stats.kbs_down = stats.ch_count_down / 1000.0
  stats.kbs_up = stats.ch_count_up / 1000.0
  
  --reset counters
  stats.ch_count_down = 0
  stats.ch_count_up = 0
  return true
end

update_stats() --setups stats


-------------------------------------------------------
----------------- Packet handlers ---------------------
local handlers = {
  heroes = {},
  mobs = {},
  states = {}
}

--Called whenever a network error append
function handlers:error(msg)
  print("Network error : " .. msg.err)
end

--Called when server respond with a guid for the current connection
function handlers:guid(msg)
  network.guid = msg.guid
  network.time_offset = msg.time - sol.main.get_elapsed_time()
  print("Responded id : " .. network.guid)
  --Connexion is achieved. Call the continuation
  network.co_prog("Connection established!",100)
  --wait a second and call connection termination
  sol.timer.start(200,function() network.co_end() end)
end

--Alter hero arrives on map, custom entity needs to be emited
function handlers:hero_arrival(msg)
    print("Hero " .. msg.name .. " (" .. msg.guid .. " arrived")
    local alter = self.map:create_custom_entity{
      name=msg.guid,
      layer=msg.layer,
      x=msg.x,
      y=msg.y,
      width=16,
      height=16,
      direction=msg.dir,
      model="alter_hero"
    }
    alter:set_displayed_name(msg.name)
    alter.net_id = msg.guid
    alter.speed = msg.speed
    self.heroes[msg.guid] = alter
end

--Alter hero leaves map, destroy it's local entity
function handlers:hero_removal(msg)
  print("Hero " .. msg.guid .. " is gone")
  if self.map:has_entity(msg.guid) then
    self.map:get_entity(msg.guid):remove()
  end
  self.heroes[msg.guid] = nil
end

--Alter hero position changed
function handlers:hero_pos(msg)
  local ent = self.heroes[msg.guid]
  ent:set_position(msg.x,msg.y,msg.layer)
end

--Alter hero animation changed
function handlers:hero_anim(msg)
  local ent = self.heroes[msg.guid]
  ent:set_animation(msg.anim)
  ent:set_direction(msg.dir or ent:get_direction())
end

--Alter hero move changed
function handlers:hero_move(msg)
  local ent = self.heroes[msg.id]
  if not ent then return end
  ent:movement_from_net(msg.move)
  local pos = msg.move.pos
  ent:set_position(pos.x,pos.y,pos.layer)
end

--Alter hero
function handlers:mob_move(msg)
  local ent = self.mobs[msg.id]
  if not ent then return end
  ent:movement_from_net(msg.move,network)
  --local pos = msg.move.pos
  --ent:set_position(pos.x,pos.y,pos.layer)
end

function handlers:hero_action(msg)
  local hero = self.heroes[msg.id]
  if not hero then return end
  hero:action(msg.action,unpack(params or {}))
end

--a mob from the current map will be simulated by a remote worker
function handlers:remote_mob(msg)
  local mob = self.mobs[msg.mob_id];
  if mob then
    print("Mob .. " .. msg.mob_id:sub(8) .. "(...) is remote controlled")
    mob:on_remote_prom(msg.state)
    local name = msg.mob_id:sub(0,8) .. "... [rem]"
    mob:set_displayed_name(name)
  else
    print("Could not find mob " .. msg.mob_id .. " in the current map")
  end
end

--a mob from the current map will be converted to master
function handlers:master_mob(msg)
  local mob = self.mobs[msg.mob_id];
  if mob then
    print("Mob .. " .. msg.mob_id .. " is master")
    mob:on_master_prom(msg.state) --forward optionnal state, TODO : test this later
    local name = msg.mob_id:sub(0,8) .. "... [mas]"
    mob:set_displayed_name(name)
  else
    print("Could not find mob " .. msg.mob_id .. " in the current map")
  end
end

-- a mob is remotelly attacked
function handlers:mob_attacked(msg)
  local mob = self.mobs[msg.mob_id];
  if mob then
    local attacker = network.get_entity(msg.hero_id)
    mob:remote_attack(attacker,msg.attack,msg.sprite)
  end
end

-- a mob is to be waken-up
function handlers:mob_activated(msg)
  local mob = self.mobs[msg.mob_id]
  if mob then
    mob:set_enabled()
  end
end

-- a mob is attacked
function handlers:mob_death(msg)
  local mob = self.mobs[msg.mob_id]
  if mob then
    mob:die()
  end
end

function handlers:mob_state(msg)
  local id = msg.mob_id
  local mob = self.mobs[msg.mob_id] or self.states[msg.mob_id]
  if mob then
    mob:update_state(msg.state)
  end
end

function handlers:map_master(msg)
  -- TODO prepare map master
  if msg.map_id == network.current_map:get_id() then
    local map = network.current_map
    map:on_master_prom(msg.state)
  end
end

function handlers:map_slave(msg)
  -- TODO prepare map slave
  if msg.map_id == network.current_map:get_id() then
    local map = network.current_map
    map:on_slave_prom(msg.state)
  end
end

function handlers:map_state(msg)
  if msg.map_id == network.current_map:get_id() then
    local map = network.current_map
    map:update_state(msg.state,msg.new,msg.modified,msg.removed)
  end
end

function handlers:get_mob_state_qa(msg)
  network.querry_answer(msg.qn,msg)
end

function handlers:map_action(msg)
  network.current_map:action(msg.action,unpack(msg.params or {}))
end

function delayed_call(delay,f,...)
  local args = {...}
  sol.timer.start(delay,function() f(unpack(args)) end)
end

-- TODO : for debug purposes
network.simulate_laggy = false

--Called whenever a msg arrives from the server, its purpose is to dispatch message based
--on message type, doing nothing when type is not handled.
local function handler(msg)
  if msg.type ~= "error" then
    local f = handlers[msg.type]
    if f == nil then
      print("Missing handler for a .. " .. msg.type .. " message")
      f = function() end
    end
    if network.simulate_laggy then
      delayed_call(200,f,handlers,msg)
    else
      f(handlers,msg)
    end
  end
end

--=========================================
--================ Mobs ===================

local function hash_id(entity)
  local breed = entity.get_breed and entity:get_breed() or sol.main.get_type(entity)
  local sx,sy,sl = entity:get_position()
  local concat = breed .. sx .. sy .. sl --uid is the concatenation of breed and starting pos
  return sha2.h256(concat):sub(0,8) -- TODO : verify if trunkation leads to too much colisions
end

function network.set_net_id(entity)
  local name = entity:get_name() or hash_id(entity) --get entity name if provided by map
  entity.net_id = name;
  return name
end

--Called by each mob when the map is done loading, declares mobs to the servers and wait
--for a response telling if the mob is to be locally simulated or will be remote controlled
function network.has_mob(entity)
  local map_id = entity:get_map():get_id()
  local name = network.set_net_id(entity) --get entity name if provided by map
  print('Asking for mob',name)
  network.send{type='has_mob',mob_id=name,map_id=map_id}
  handlers.mobs[name] = entity;
end

--Called by each mob when they are removed, probably because player changed map
function network.has_not_mob(entity)
  local net_id = entity.net_id
  if not net_id then return end
  local map_id = entity:get_map():get_id()
  print("Revoking mob " .. net_id)
  network.send{type="has_not_mob",mob_id=net_id,map_id=map_id}
  handlers.mobs[entity.net_id] = nil
end

--------------------------------------------------
------------- Map Change handling ----------------

function network.on_game_started(game)
  game:set_value('guid',network.guid);
  --on map change notify server our new position and map
  hero_utils.setup_hero_repl_callback(game,game:get_hero(),network)
  game:register_event("on_map_changed", function(game,map)
    print("Map changed to " .. map:get_id())
    handlers.heroes = {} -- Empty alter_heroes list

    --add hero guid as name TODO put true name


    --save current map
    network.current_map = map

    local hero = map:get_hero()

    hero.displayed_name = game:get_value('player_name')
    hero.net_id = network.guid
    name_displayer:add_named_entity(hero);

    local x,y,layer = hero:get_position()
    local dir = hero:get_direction()
    local speed = hero:get_walking_speed()
    network.send({type = "hero_arrival",
          map_id=map:get_id(),
          x=x,y=y,layer=layer,dir=dir,speed=speed})
    handlers.map = map;
    mob_utils.make_mob_master_basics(hero,network.guid,network,"hero")

    --modify get_entity function
    function network.get_entity(net_id)
      if net_id == network.guid then return map:get_hero() end
      return map:get_entity(net_id)
              or handlers.heroes[net_id]
              or handlers.mobs[net_id]
    end

    --notify server that we have the ennemies
    map:init_net_enabled_entities()
  end) -- end register map changed
end

function network.register_state(state)
  handlers.states[state.net_id] = state
end

local net_states = {}

--add a state to send list
function network.send_state(packet,id)
  net_states[id] = packet
end

--send all state packets registered for this frame
function network.send_state_changes()
  for _,p in pairs(net_states) do
    network.send(p)
  end
  net_states = {}
end

-----------------------------------------------
-- QUERRIES
-----------------------------------------------
local n_querry = 0
local querries = {}

function network.querry(packet,handler)
  n_querry = n_querry+1
  packet.qn = n_querry
  network.send(packet)
  querries[packet.qn] = handler
end

function network.querry_answer(qn,msg)
  local querryhandler = querries[qn]
  if querryhandler then
    querryhandler(msg)
    querries[qn] = nil --remove used handler
  else
    print('missing querryhandler for querry',qn)
  end
end

function network.get_mob_state(mob_id,continuation)
  local function querry_handler(msg)
    continuation(msg.state)
  end
  network.querry({type='get_mob_state',mob_id=mob_id},querry_handler);
end

function network.get_server_header(host,port,save,continuation)
  print('trying to connect to',host,port)
  local sock = socket.tcp()
  sock:settimeout(0.3)
  local res,err = sock:connect(host,port)
  if not res then
    continuation({description='offline',err=err})
    return
  end
  local handlers = {}
  function handlers:server_header(msg,server)
    server:close()
    continuation(msg.header)
  end
  local server = network.make_server(sock,handlers)
  local guid = save:get_value('guid')
  server:send({type='get_header',guid=guid})
end

-- blacklist some packet to avoid polluting the logs
local log_blacklist = {
  hero_move = true,
  mob_move = true,
  ends = true
}

function network.make_send(socket)
  return function(data)
    local str = json.encode(data)
    if not log_blacklist[data.type] then print("Sending " .. str) end
    network.stats.ch_count_up = network.stats.ch_count_up + #str + 1
    socket:send(str..'\n')
  end
end

function network.make_receive(socket)
  return function(pat)
    pat = pat or "*l"
    local data, err = socket:receive(pat)
    if data then
      --print("Received " .. data)
      network.stats.ch_count_down = network.stats.ch_count_down + #data
      local msg = json.decode(data)
      if not log_blacklist[msg.type] then print(data) end
      return msg -- TODO produce error answers on bad json format
    end
    if err then --TODO find a way for error handling
      --return {type="error", err = err}
    end
  end
end

function network.make_server(socket,handlers)
  --set socket as 'non-blocking'
  socket:settimeout(0)
  local send = network.make_send(socket)
  local receive = network.make_receive(socket)
  local server = {socket=socket}
  function server:send(data)
    send(data)
  end
  function handlers:send(data)
    send(data)
  end
  local function handle(msg)
    if msg.type ~= "error" then
      local f = handlers[msg.type]
      if f == nil then
        print("Missing handler for a .. " .. msg.type .. " message")
        f = function() end
      end
      if network.simulate_laggy then
        delayed_call(200,f,handlers,msg)
      else
        f(handlers,msg,server)
      end
    end
  end
  --Launch 'async' receive of network messages
  --receive network messages in a "non-blocking" way
  --this permit to include message handling as a part of the game loop
  server.timer = sol.timer.start(sol.main,10,
                                 function()
                                   for d in receive do
                                     handle(d)
                                   end
                                return true
  end)
  function server:close()
    print('server closed')
    self.timer:stop()
    self.socket:close()
  end
  return server,send
end

-----------------------------------------------
------------- Connect to server ---------------
function network.connect(host,port,save,finished_callback,op_progress_callback)
  network.host = host
  network.port = port

  local progress = safe(op_progress_callback)  

  network.co_prog = progress
  network.co_end = safe(finished_callback)

  local server = socket.connect(host,port)
  if server == nil then
    print("Server connection failed... continuing offline")
    handlers:guid({guid = "offline",time=0})
    return
  end

  local handled_server,send = network.make_server(server,handlers);
  network.server = handled_server
  network.send = send

  -- start the state update sender process
  sol.timer.start(30,function()
                    network.send_state_changes()
    return true
  end)

  --start stat updater routine
  sol.timer.start(1000,update_stats)


  progress("Sending handshake",50)
  --Begin login dialog with the server
  print("Sending handshake to server")
  local name = save:get_value('player_name')
  local guid = save:get_value('guid')
  -- TODO use guid to retrieve server side save
  send({type="hello",name=name})
  
  -- Add server close callback to the engine
  function sol.main:on_finished()
    print("Disconnecting server")
    handled_server:close()
  end
end

return network
