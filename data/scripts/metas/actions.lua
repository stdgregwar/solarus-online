local actions = {}

function actions.setup_meta(meta)
  function meta:action_dispatcher(action_name,...)
    assert(type(action_name)=='string')
    local action = self['action_'..action_name] or function()end
    action(self,...)
  end
  meta.action = meta.action_dispatcher
end

function actions.make_net_action(obj,network,packet_name)
  function obj:action(action_name,...)
    --first call local action dispatcher
    self:action_dispatcher(action_name,...)
    --make action packet and send
    network.send({type=packet_name,action=action_name,id=obj.net_id,params={...}})
  end
end

return actions
