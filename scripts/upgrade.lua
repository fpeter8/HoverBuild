local common = require("scripts.common")
local insert = require("scripts.insert")

--- Builds an upgraded entity, preserving any requests that could not be fulfilled.
--- @param player LuaPlayer
--- @param entity LuaEntity
--- @param prototype LuaEntityPrototype
--- @param quality LuaQualityPrototype
--- @return LuaEntity?
local function build(player, entity, prototype, quality)
  local proxy = insert.find_proxy(entity)
  local insert_plan = proxy and insert.copy_plan(proxy.insert_plan) or nil
  local removal_plan = proxy and insert.copy_plan(proxy.removal_plan) or nil

  local built = common.build(player, entity, prototype, quality)
  if not built or not built.valid then
    return nil
  end

  insert.restore_plans(built, insert_plan, removal_plan)
  insert.process_entity(player, built)

  return built
end

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

  if
    upgrade_prototype.name == entity.name
    and upgrade_quality.name == entity.quality.name
  then
    -- Only the item requests changed, so fulfill them without rebuilding the entity.
    local processed_requests = insert.process_entity(player, entity)
    insert.cancel_completed_upgrade(player, entity, processed_requests)
    return true
  end

  if not common.check_can_place_entity(player, entity, upgrade_prototype) then
    return false
  end

  --- @type LuaEntity?
  local underground_neighbour = entity.type == "underground-belt" and entity.underground_belt_neighbour or nil

  local upgraded = build(player, entity, upgrade_prototype, upgrade_quality)
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
    build(player, underground_neighbour, neighbour_upgrade_prototype, neighbour_upgrade_quality)
  end

  return true
end
