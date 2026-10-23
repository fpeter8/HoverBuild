local construct = require("scripts.construct")
local deconstruct = require("scripts.deconstruct")
local insert = require("scripts.insert")
local repair = require("scripts.repair")
local upgrade = require("scripts.upgrade")

--- @type Set<string>
local ignored_entities = prototypes.mod_data["moc-ignored-entities"].data

--- @param entity LuaEntity
local function should_ignore_entity(entity)
  local useful_name = ""
  if entity.type == "entity-ghost" then
    useful_name = entity.ghost_name
  else
    useful_name = entity.name
  end
  return ignored_entities[useful_name] or false
end

--- @param player LuaPlayer
--- @param entity LuaEntity
local function try_execute(player, entity)
  if not storage.mouseover_active[player.index] then
    return
  end

  if should_ignore_entity(entity) then
    return
  end

  if not player.can_reach_entity(entity) then
    storage.recheck_on_move[player.index] = true
    return
  end

  -- Fulfill any pending item requests before deciding whether an action can be executed,
  -- so that insertion also works while holding a blueprint or upgrade planner.
  local processed_requests = insert.process_entity(player, entity)
  insert.cancel_completed_upgrade(player, entity, processed_requests)

  local cursor_stack = player.cursor_stack
  if not cursor_stack then
    return
  end

  local is_empty = not cursor_stack.valid_for_read
  local is_repair_tool = not is_empty and cursor_stack.type == "repair-tool"

  local upgrade_prototype, upgrade_quality = entity.get_upgrade_target()
  local entity_name, entity_quality = entity.name, entity.quality
  if upgrade_prototype then
    --- @cast upgrade_quality -?
    entity_name = upgrade_prototype.name
    entity_quality = upgrade_quality
  elseif entity.type == "entity-ghost" then
    entity_name = entity.ghost_name
  end
  local matches_selected = not is_empty
    and cursor_stack.prototype.place_result
    and cursor_stack.prototype.place_result.name == entity_name
    and cursor_stack.quality == entity_quality

  local should_execute = matches_selected or is_empty or is_repair_tool

  if not should_execute then
    return
  end

  if construct(player, entity) then
    return
  end

  if is_repair_tool and repair.start(player, entity) then
    return
  end

  if upgrade(player, entity) then
    return
  end

  deconstruct.start(player, entity)
end

--- @param e EventData.on_player_changed_position
local function on_player_changed_position(e)
  if not storage.recheck_on_move[e.player_index] then
    return
  end
  storage.recheck_on_move[e.player_index] = nil

  if not storage.mouseover_active[e.player_index] then
    return
  end

  local player = game.get_player(e.player_index)
  if not player then
    return
  end

  local selected = player.selected
  if not selected then
    return
  end

  try_execute(player, selected)
end

--- @param e EventData.on_selected_entity_changed
local function on_selected_entity_changed(e)
  deconstruct.cancel(e.player_index)
  repair.cancel(e.player_index)
  storage.recheck_on_move[e.player_index] = nil

  local player = game.get_player(e.player_index)
  --- @cast player -?

  local selected = player.selected
  if not selected then
    return
  end

  try_execute(player, selected)
end

--- @param e EventData.on_blueprint_settings_pasted
local function on_blueprint_settings_pasted(e)
  if not e.player_index or not e.entity.valid then
    return
  end

  local player = game.get_player(e.player_index)
  if not player or player.selected ~= e.entity then
    return
  end

  try_execute(player, e.entity)
end

--- @param e EventData.on_entity_settings_pasted
local function on_entity_settings_pasted(e)
  if not e.destination.valid then
    return
  end

  local player = game.get_player(e.player_index)
  if not player or player.selected ~= e.destination then
    return
  end

  try_execute(player, e.destination)
end

--- @param e EventData.on_marked_for_upgrade
local function on_marked_for_upgrade(e)
  if not e.player_index or not e.entity.valid then
    return
  end

  local player = game.get_player(e.player_index)
  if not player or player.selected ~= e.entity then
    return
  end

  try_execute(player, e.entity)
end

local function init()
  if not storage.recheck_on_move then
    --- @type Set<PlayerIndex>
    storage.recheck_on_move = {}
  end
end

--- @class orchestrator_handler : event_handler
local orchestrator_handler = {}

orchestrator_handler.on_init = init
orchestrator_handler.on_configuration_changed = init

orchestrator_handler.events = {
  [defines.events.on_player_changed_position] = on_player_changed_position,
  [defines.events.on_selected_entity_changed] = on_selected_entity_changed,
  [defines.events.on_blueprint_settings_pasted] = on_blueprint_settings_pasted,
  [defines.events.on_entity_settings_pasted] = on_entity_settings_pasted,
  [defines.events.on_marked_for_upgrade] = on_marked_for_upgrade,
}

return orchestrator_handler
