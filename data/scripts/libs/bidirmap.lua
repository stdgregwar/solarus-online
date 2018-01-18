--------------------------------------------
--- Bidirectional Map ----------------------
-- Only works with unique key-pair couples -
--------------------------------------------

local bdmap = {}

--add pair in both direction when assignment is made
--TODO look for old values to update pairs
function bdmap:__newindex(k,v)
  rawset(self,k,v)
  rawset(self,v,k)
end

function bdmap.new()
  return setmetatable({},bdmap)
end

return bdmap
