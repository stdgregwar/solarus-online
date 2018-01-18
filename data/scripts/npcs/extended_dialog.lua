local ed = {}

function ed.get_extended_dialog(id,npc_count)
  local ext = {}
  npc_count = npc_count or 2

  function ext:next()
  end

  return ext
end

return ed