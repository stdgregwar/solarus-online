-- Minimaly modify movement api to allow to easy and light reproduction on
-- other clients

local target = sol.main.get_metatable("target_movement")

--retain old set_target
local set_target = target.set_target

--memorize targeted point/entity for movement info retrieval
function target:set_target(a,b,c)
  if type(a) == "number" then
    self.target_type = "point"
    self.target_entity = nil
    self.target_x = a
    self.target_y = b
  else
    self.target_type = "entity"
    self.offset_x = b or 0
    self.offset_y = c or 0
    self.target_entity = a
  end
  
  set_target(self,a,b,c) 
end

function target:get_targetxy()
  if self.target_type == 'point' then
    return self.target_x,self.target_y
  else
    local x,y = self.target_entity:get_position()
    return x+self.offset_x,y+self.offset_y
  end
end

-- save old start
local target_start = target.start

--put hero as default followed entity
function target:start(obj,callback)
  if obj and obj.get_map then
    self.target_entity = self.target_entity or obj:get_map():get_hero()
    self.target_type = 'entity'
  end
  target_start(self,obj,callback)
end
