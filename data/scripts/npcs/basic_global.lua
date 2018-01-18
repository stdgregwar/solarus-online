local bg = {}

function bg:new(ttable, name)
  local o = {timetable = ttable, currentmapid = "",id=name}
  setmetatable(o,self)
  return o
end

function bg:sim_until(date,map)
  local map_id,pos_id = self.timetable:get_current_ids(date)
  if map_id == map:get_id() then --npc should be on map
    local npc = map[self.id]
    if npc then
    else
      --spawn npc on map
      map:create_npc({
        
      })
    end
  end
  
end

function bg:sim_on_map(map)
end