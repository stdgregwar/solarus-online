-- Ruppee bag
local item = ...

function item:on_created()

  self:set_savegame_variable("possession_rupee_bag")

end

function item:on_variant_changed(variant)

  self:get_game():set_max_money(999)

end

