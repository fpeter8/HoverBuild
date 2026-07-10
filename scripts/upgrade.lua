local common = require("scripts.common")

--- @param player LuaPlayer
--- @param entity LuaEntity
--- @return boolean succeeded
return function(player, entity)
  if not entity.valid then
    return false
  end

  if not player.mod_settings["moc-enable-upgrading"].value then
    return false
  end

  if not entity.to_be_upgraded() then
    return false
  end

  local upgrade_prototype, upgrade_quality = entity.get_upgrade_target()
  if not upgrade_prototype then
    return false
  end
  --- @cast upgrade_quality -?

  if not common.check_can_place_entity(player, entity, upgrade_prototype) then
    return false
  end

  --- @type LuaEntity?
  local underground_neighbour = entity.type == "underground-belt" and entity.underground_belt_neighbour or nil

  local upgraded = common.build(player, entity, upgrade_prototype, upgrade_quality)
  if not upgraded then
    return false
  end

  if not underground_neighbour or not underground_neighbour.valid then
    -- Still return true because the selected entity was upgraded.
    return true
  end

  local neighbour_upgrade_prototype, neighbour_upgrade_quality = underground_neighbour.get_upgrade_target()
  if neighbour_upgrade_prototype then
    --- @cast neighbour_upgrade_quality -?
    -- Upgrading underground neighbours doesn't obey the usual build distance restrictions, so no need to check it here.
    common.build(player, underground_neighbour, neighbour_upgrade_prototype, neighbour_upgrade_quality)
  end

  return true
end
