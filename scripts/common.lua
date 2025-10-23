--- @param box1 BoundingBox
--- @param box2 BoundingBox
local function bounding_boxes_equal(box1, box2)
  return box1.left_top.x == box2.left_top.x
    and box1.left_top.y == box2.left_top.y
    and box1.right_bottom.x == box2.right_bottom.x
    and box1.right_bottom.y == box2.right_bottom.y
end

--- @class common
local common = {}

--- Builds an entity over the top of an existing entity.
--- @param player LuaPlayer
--- @param entity LuaEntity
--- @param new_prototype LuaEntityPrototype
--- @param new_quality LuaQualityPrototype
--- @return LuaEntity?
function common.build(player, entity, new_prototype, new_quality)
  local item, consume_count = common.get_item(player, new_prototype, new_quality)
  if not item then
    return nil
  end

  local bounding_box = entity.bounding_box
  local surface = entity.surface
  local position = entity.position
  local direction = entity.direction
  local quality = entity.quality
  local force = entity.force

  local new_entity = surface.create_entity({
    name = new_prototype.name,
    position = entity.position,
    direction = entity.direction,
    quality = new_quality,
    force = entity.force,
    fast_replace = true,
    player = player,
    character = player.character,
    raise_built = true,
    create_build_effect_smoke = true,
    spawn_decorations = true,
    move_stuck_players = true,
    item = item,
    register_plant = true,
    --- Undergound belt
    type = entity.type == "underground-belt" and entity.belt_to_ground_type or nil,
  })
  if not new_entity or not new_entity.valid then
    -- Some mods will immediately replace the entity with a different one. Let's see if we can detect this.
    for _, replaced_entity in
      pairs(surface.find_entities_filtered({
        direction = direction,
        position = position,
        quality = quality.name,
        force = force,
      }))
    do
      if
        replaced_entity.type ~= "entity-ghost"
        and replaced_entity.type ~= "tile-ghost"
        and bounding_boxes_equal(replaced_entity.bounding_box, bounding_box)
      then
        new_entity = replaced_entity
        break
      else
        return
      end
    end
  end

  item.count = item.count - consume_count

  local stats = force.get_entity_build_count_statistics(surface)
  stats.on_flow(new_entity, 1)

  player.play_sound({
    path = "entity-build/" .. new_entity.name,
    position = new_entity.position,
  })

  return new_entity
end

--- @param player LuaPlayer
--- @param entity LuaEntity
--- @param new_prototype LuaEntityPrototype
--- @return boolean
function common.check_can_place_entity(player, entity, new_prototype)
  if
    not player.can_place_entity({
      name = new_prototype.name,
      position = entity.position,
      direction = entity.direction,
    })
  then
    storage.recheck_on_move[player.index] = true
    return false
  end
  return true
end

--- Returns the first LuaItemStack that can build the given entity and quality.
--- @param player LuaPlayer
--- @param prototype LuaEntityPrototype
--- @param quality LuaQualityPrototype
--- @return LuaItemStack?, uint?
function common.get_item(player, prototype, quality)
  local cursor_stack = player.cursor_stack
  local inventory = player.get_main_inventory()
  for _, item_to_place in pairs(prototype.items_to_place_this or {}) do
    if
      cursor_stack
      and cursor_stack.valid_for_read
      and cursor_stack.name == item_to_place.name
      and cursor_stack.quality == quality
      and cursor_stack.count >= item_to_place.count
    then
      return cursor_stack, item_to_place.count
    end
    if inventory then
      local item = inventory.find_item_stack({ name = item_to_place.name, quality = quality.name })
      if item and item.count >= item_to_place.count then
        return item, item_to_place.count
      end
    end
  end
end

return common
