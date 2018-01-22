local utils = {}

function table.pack(...)
  return {n=select('#',...),...}
end

function utils.xy_from_dir(dir)
  if dir == 0 then
    return 1,0
  elseif dir == 1 then
    return 0,-1
  elseif dir == 2 then
    return -1,0
  elseif dir == 3 then
    return 0,1
  end
end

function deep_compare(a,b)
  local ta = type(a)
  if ta ~= type(b) then return false end
  if ta == 'table' then
    return table_compare(a,b)
  else
    return a == b;
  end
end

function table_compare(a,b)
  if not #a == #b then return false end
  for key,val in pairs(a) do
    if not deep_compare(val,b[key]) then
      return false
    end
  end
  return true
end

function merge_into_table(merged,to_merge)
  for k,v in pairs(to_merge) do
    merged[k] = merged[k] or v
  end
  return merged
end

function table_diff(previous,new)
  local previous = previous or {}
  local new = new or {}
  local diff = {new={},mod={},rem={}}
  --accumultate removed
  for k,v in pairs(previous)do
    if not new[k] then
      diff.rem[k] = v
    end
  end
  --accumulate new and modified
  for k,v in pairs(new) do
    if not previous[k] then
      diff.new[k] = v
    elseif not deep_compare(previous[k],v) then
      diff.mod[k] = v
    end
  end
  return diff
end


function utils.object_to_properties(obj,props_names)
  local props = {}
  for _,pname in ipairs(props_names) do
    local mname = 'get_' .. pname
    local getter = obj[mname]
    if getter then 
      local prop = obj[mname](obj)
      props[pname] = prop
    end
  end
  return props
end

------------------------------------------------------------------------
-- usually apply to solarus objects, restore properties trough setters
------------------------------------------------------------------------
function utils.apply_properties(obj,props)
  for pname,pval in pairs(props) do
    local sname = 'set_'.. pname
    local setter = obj[sname]
    safe(setter)(obj,pval)
  end
end

function utils.dir_from_xy(x,y)
  local angle = math.atan(y,x)
  return math.floor((angle/math.pi)*4)%8
end

function safe(f)  
  return f or function() end
end

return utils
