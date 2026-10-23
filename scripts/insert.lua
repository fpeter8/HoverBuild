local common = require("scripts.common")

--- @class insertion
local insertion = {}

--- Deep-copies an insert plan so that it survives the destruction of the entity or proxy that it came from.
--- @param plan BlueprintInsertPlan[]?
--- @return BlueprintInsertPlan[]?
function insertion.copy_plan(plan)
  if not plan then
    return nil
  end

  local copy = {}
  for i, entry in ipairs(plan) do
    local items = entry.items or {}
    local positions
    if items.in_inventory then
      positions = {}
      for j, position in ipairs(items.in_inventory) do
        positions[j] = {
          inventory = position.inventory,
          stack = position.stack,
          count = position.count or 1,
        }
      end
    end
    copy[i] = {
      id = { name = entry.id.name, quality = entry.id.quality },
      items = {
        in_inventory = positions,
        grid_count = items.grid_count,
      },
    }
  end
  return copy
end

--- Returns the item request proxy targeting this entity, if any.
--- @param entity LuaEntity
--- @return LuaEntity?
function insertion.find_proxy(entity)
  local proxy = entity.item_request_proxy
  if proxy and proxy.valid then
    return proxy
  end

  for _, candidate in
    pairs(entity.surface.find_entities_filtered({
      name = "item-request-proxy",
      position = entity.position,
      force = entity.force,
    }))
  do
    if candidate.proxy_target == entity then
      return candidate
    end
  end
end

--- @param entity LuaEntity
--- @param insert_plan BlueprintInsertPlan[]?
--- @param removal_plan BlueprintInsertPlan[]?
--- @return LuaEntity?
local function create_proxy(entity, insert_plan, removal_plan)
  return entity.surface.create_entity({
    name = "item-request-proxy",
    position = entity.position,
    force = entity.force,
    target = entity,
    modules = insert_plan,
    removal_plan = removal_plan,
  })
end

--- @param player LuaPlayer
--- @param prototype LuaItemPrototype
--- @return boolean
local function is_category_enabled(player, prototype)
  if prototype.type == "module" then
    return player.mod_settings["moc-insert-modules"].value
  elseif prototype.type == "ammo" then
    return player.mod_settings["moc-insert-ammo"].value
  elseif (prototype.fuel_value or 0) > 0 then
    return player.mod_settings["moc-insert-fuel"].value
  end
  return false
end

--- Moves requested items from the player's inventory into the entity's inventories.
--- @param player LuaPlayer
--- @param entity LuaEntity
--- @param plan BlueprintInsertPlan[]
--- @return uint inserted
local function fill_insert_plan(player, entity, plan)
  local inserted = 0

  for i = #plan, 1, -1 do
    local entry = plan[i]
    local positions = entry.items and entry.items.in_inventory
    local prototype = prototypes.item[entry.id.name]
    local quality = prototypes.quality[entry.id.quality or "normal"]

    if positions and prototype and quality and is_category_enabled(player, prototype) then
      for j = #positions, 1, -1 do
        local position = positions[j]
        local inventory = entity.get_inventory(position.inventory)
        local destination = inventory and inventory[position.stack + 1]

        if destination and destination.valid then
          local remaining = position.count or 1

          for source in common.iter_items(player, entry.id.name, quality) do
            if remaining == 0 then
              break
            end

            local source_count = source.count
            local amount = math.min(remaining, source_count)
            destination.transfer_stack(source, amount)

            local moved = source_count - (source.valid_for_read and source.count or 0)
            remaining = remaining - moved
            inserted = inserted + moved

            if moved == 0 then
              break
            end
          end

          position.count = remaining
          if remaining == 0 then
            table.remove(positions, j)
          end
        end
      end

      if #positions == 0 and (entry.items.grid_count or 0) == 0 then
        table.remove(plan, i)
      end
    end
  end

  return inserted
end

--- Moves up to the given count from a stack into an inventory, preserving any rich item data.
--- @param inventory LuaInventory
--- @param source LuaItemStack
--- @param count uint
--- @return uint moved
local function transfer_to_inventory(inventory, source, count)
  local moved = 0

  for i = 1, #inventory do
    if moved >= count or not source.valid_for_read then
      break
    end

    local destination = inventory[i]
    if destination and destination.valid then
      local source_count = source.count
      destination.transfer_stack(source, math.min(count - moved, source_count))
      moved = moved + source_count - (source.valid_for_read and source.count or 0)
    end
  end

  return moved
end

--- Moves requested items from the entity's inventories into the player's main inventory.
--- @param player LuaPlayer
--- @param entity LuaEntity
--- @param plan BlueprintInsertPlan[]
--- @return uint removed
local function process_removal_plan(player, entity, plan)
  local removed = 0
  local inventory = player.get_main_inventory()

  if not inventory then
    return removed
  end

  for i = #plan, 1, -1 do
    local entry = plan[i]
    local positions = entry.items and entry.items.in_inventory
    local prototype = prototypes.item[entry.id.name]
    local quality = prototypes.quality[entry.id.quality or "normal"]

    if positions and prototype and quality and is_category_enabled(player, prototype) then
      for j = #positions, 1, -1 do
        local position = positions[j]
        local entity_inventory = entity.get_inventory(position.inventory)
        local source = entity_inventory and entity_inventory[position.stack + 1]

        if
          source
          and source.valid_for_read
          and source.name == entry.id.name
          and source.quality == quality
        then
          local remaining = position.count or 1
          local amount_removed = transfer_to_inventory(
            inventory,
            source,
            math.min(remaining, source.count)
          )

          if amount_removed == 0 then
            break
          end

          remaining = remaining - amount_removed
          removed = removed + amount_removed
          position.count = remaining

          if remaining == 0 then
            table.remove(positions, j)
          end
        end
      end

      if #positions == 0 and (entry.items.grid_count or 0) == 0 then
        table.remove(plan, i)
      end
    end
  end

  return removed
end

--- @param player LuaPlayer
--- @param entity LuaEntity
--- @param proxy LuaEntity
--- @return boolean
local function process_proxy(player, entity, proxy)
  local insert_plan = proxy.insert_plan
  local removal_plan = proxy.removal_plan

  -- Remove old items first so that their slots are free for the requested items.
  local removed = process_removal_plan(player, entity, removal_plan)
  local inserted = fill_insert_plan(player, entity, insert_plan)

  if proxy.valid then
    proxy.removal_plan = removal_plan
  end
  if proxy.valid then
    proxy.insert_plan = insert_plan
  end

  if
    proxy.valid
    and (inserted > 0 or removed > 0)
    and #insert_plan == 0
    and #removal_plan == 0
  then
    proxy.destroy()
  end

  return inserted > 0 or removed > 0
end

--- @param entity LuaEntity
--- @return boolean
function insertion.has_pending_requests(entity)
  local proxy = insertion.find_proxy(entity)
  if not proxy then
    return false
  end
  return #proxy.insert_plan > 0 or #proxy.removal_plan > 0
end

--- Fills pending insert and removal requests on an existing entity.
--- @param player LuaPlayer
--- @param entity LuaEntity
--- @return boolean
function insertion.process_entity(player, entity)
  if
    not entity.valid
    or entity.type == "entity-ghost"
    or entity.type == "tile-ghost"
  then
    return false
  end

  local proxy = insertion.find_proxy(entity)
  if not proxy then
    return false
  end

  return process_proxy(player, entity, proxy)
end

--- Cancels a same-prototype upgrade once all of its item requests have been fulfilled.
--- @param player LuaPlayer
--- @param entity LuaEntity
--- @param processed boolean Whether any item requests were fulfilled for this entity.
function insertion.cancel_completed_upgrade(player, entity, processed)
  if
    not processed
    or not entity.valid
    or not player.mod_settings["moc-enable-upgrading"].value
    or not entity.to_be_upgraded()
  then
    return
  end

  local prototype, quality = entity.get_upgrade_target()
  if
    not prototype
    or not quality
    or prototype.name ~= entity.name
    or quality.name ~= entity.quality.name
  then
    return
  end

  if not insertion.has_pending_requests(entity) then
    entity.cancel_upgrade(entity.force, player)
  end
end

--- Fills the item requests of a ghost that was just built.
--- @param player LuaPlayer
--- @param entity LuaEntity
--- @param plan BlueprintInsertPlan[]?
--- @return boolean
function insertion.process_built_entity(player, entity, plan)
  if not plan or #plan == 0 then
    return false
  end

  local proxy = insertion.find_proxy(entity)
  if proxy then
    -- Prefer the requests that the game itself transferred; only use the saved plan if there are none.
    if #proxy.insert_plan == 0 then
      proxy.insert_plan = plan
    end
  else
    proxy = create_proxy(entity, plan)
  end

  if not proxy or not proxy.valid then
    return false
  end

  return process_proxy(player, entity, proxy)
end

--- Preserves insert and removal requests across an entity replacement.
--- @param entity LuaEntity
--- @param insert_plan BlueprintInsertPlan[]?
--- @param removal_plan BlueprintInsertPlan[]?
function insertion.restore_plans(entity, insert_plan, removal_plan)
  local has_insert = insert_plan and #insert_plan > 0
  local has_removal = removal_plan and #removal_plan > 0

  if not has_insert and not has_removal then
    return
  end

  local proxy = insertion.find_proxy(entity)
  if not proxy then
    create_proxy(entity, insert_plan, removal_plan)
    return
  end

  if has_insert and #proxy.insert_plan == 0 and proxy.valid then
    proxy.insert_plan = insert_plan
  end
  if has_removal and #proxy.removal_plan == 0 and proxy.valid then
    proxy.removal_plan = removal_plan
  end
end

return insertion
