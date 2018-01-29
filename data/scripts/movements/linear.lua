local vector = require'scripts/Vector'

local linear = {}

linear.__index = linear

function linear.create(target,time)
  return setmetatable({
      target=target,
      time=time,
  },linear)
end

function linear:set_target(target)
  self.target = target
end

function linear:update()
  local time = sol.main.get_elapsed_time() / 1000
  local factor = (time-self.start_time)/self.time
  factor = factor > 1 and 1 or factor
  local pos = self.start*(1-factor)+self.target*factor
  self.entity:set_position(pos.x,pos.y)
  if factor >= 1 then
    safe(self.on_finished)(self)
    return false
  end
  return true
end

local refresh = 16

function linear:start(entity)
  self.entity = entity
  local x,y = entity:get_position()
  self.start = vector(x,y)
  self.start_time = sol.main.get_elapsed_time() / 1000
  sol.timer.start(
    refresh,
    function()
      return self:update()
    end
  )
end

return linear
