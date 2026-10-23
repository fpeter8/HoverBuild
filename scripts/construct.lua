local common = require("scripts.common")
local insert = require("scripts.insert")

--- @param player LuaPlayer
--- @param entity LuaEntity
--- @return boolean
return function(player, entity)
  if not entity.valid then
    return false
  end

  if not player.mod_settings["moc-enable-construction"].value then
    return false
  end

  if entity.type ~= "entity-ghost" then
    return false
  end

  local entity_prototype = entity.ghost_prototype --[[@as LuaEntityPrototype]]

  if not common.check_can_place_entity(player, entity, entity_prototype) then
    return false
  end

  -- The ghost is destroyed by construction, so its requests need to be saved first.
  local insert_plan = insert.copy_plan(entity.insert_plan)

  local new_entity = common.build(player, entity, entity_prototype, entity.quality)
  if not new_entity or not new_entity.valid then
    return false
  end

  insert.process_built_entity(player, new_entity, insert_plan)

  return true
end
