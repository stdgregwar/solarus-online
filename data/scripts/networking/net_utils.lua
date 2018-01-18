
local net_utils = {}

local buffers = {}

local function receive(socket,pat)
  return function()
    return socket:receive(pat)
  end
end

function net_utils.receive_line(socket)
  local buf = buffers[socket] or ''
  local n_bytes = 1
  local err
  for byte,err in receive(socket,n_bytes) do
    buf = buf .. byte
    local i = buf:find('\n')
    if i then
      local line = buf:sub(1,i)
      buffers[socket] = buf:sub(i+1,-1)
      return line,err
    end
  end
  buffers[socket] = buf
  return nil,err
end

return net_utils
