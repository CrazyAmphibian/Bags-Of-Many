dofile_once( "mods/bags_of_many/files/scripts/utils/utils.lua" )

function get_player_entity()
	local players = EntityGetWithTag("player_unit")
	if #players == 0 then return end

	return players[1]
end

function has_bag_container( entity_id )
    local childs = EntityGetAllChildren(entity_id)
    if not childs then
        return false
    end
    for _, child in ipairs(childs) do
        if EntityGetName(child) == "bag_inventory_container" then
            return true
        end
    end
    return false
end

function is_inventory_open()
	local player = get_player_entity()
	if player then
		local inventory_gui_component = EntityGetFirstComponentIncludingDisabled(player, "InventoryGuiComponent")
		if inventory_gui_component then
			return ComponentGetValue2(inventory_gui_component, "mActive")
		end
	end
end

function is_wand(entity)
	local tags = EntityGetTags(entity)
    return string.find(tags, "wand") ~= nil
end

function is_item(entity)
	local tags = EntityGetTags(entity)
    return string.find(tags, "item_pickup") ~= nil
end

function is_bag(entity_id)
    if EntityGetName(entity_id) == nil then
        return false
    end
    return string.find(EntityGetName(entity_id), "bag_") ~= nil
end

function item_pickup_is_pickable_in_inventory(entity_id)
    local item_comp = EntityGetFirstComponentIncludingDisabled(entity_id, "ItemComponent")
    if item_comp then
        local ui_sprite = ComponentGetValue2(item_comp, "ui_sprite")
        return ui_sprite ~= ""
    end
    return false
end

function name_contains(entity_id, contains_string)
    if EntityGetName(entity_id) == nil then
        return false
    end
    return string.find(EntityGetName(entity_id), contains_string) ~= nil
end

function is_bag_not_full(bag, maximum)
    return #get_bag_inventory_items(bag) < maximum
end

function drop_item_from_parent(parent, item)
    local var_storages = EntityGetComponentIncludingDisabled(item, "VariableStorageComponent")
    for _, var_storage in ipairs(var_storages or {}) do
        print(tostring(ComponentGetValue2(var_storage, "name")))
        if ComponentGetValue2(var_storage, "name") == "item_pickup_frame" then
            EntityRemoveComponent(item, var_storage)
        end
    end
    EntityRemoveFromParent(item)
    local x, y = EntityGetTransform(parent)
    EntityApplyTransform(item, x, y)
    show_entity(item)
end

function drop_all_inventory(bag)
    local items = get_bag_inventory_items(bag)
    local x, y = EntityGetTransform(bag)
    for _, item in ipairs(items or {}) do
        EntityRemoveFromParent(item)
        EntityApplyTransform(item, x, y)
        show_entity(item)
    end
end

function get_pickable_items_in_radius(radius)
    local closest_entities = EntityGetInRadius(pos_x, pos_y, radius)
    local pickable_items = {}
    for i, entity in ipairs(closest_entities) do
        if is_item(entity) then
            table.insert(pickable_items, entity) 
        end
    end
    return pickable_items
end

function get_player_inventory()
    for i, child in ipairs(EntityGetAllChildren(EntityGetWithTag("player_unit")[1])) do
        if EntityGetName(child) == "inventory_quick" then
            return child
        end
    end
end

function add_entity_to_var_storage(bag, entity)
    if bag then
        local variable_storages = EntityGetComponentIncludingDisabled(bag, "VariableStorageComponent")
        for _, var_storage in ipairs(variable_storages or {}) do
            if var_storage then
                local initial_val = ComponentGetValue2(var_storage, "value_string")
                local t = string_table_to_table(initial_val)
                table.insert(t, tostring(entity))
                ComponentSetValue2(var_storage, "value_string", table_to_string_table(t))
            end
        end
    end
end

function remove_entity_from_var_storage(bag, entity)
    if bag then
        local variable_storages = EntityGetComponentIncludingDisabled(bag, "VariableStorageComponent")
        for _, var_storage in ipairs(variable_storages or {}) do
            if var_storage then
                local initial_val = ComponentGetValue2(var_storage, "value_string")
                local t = string_table_to_table(initial_val)
                local index = find_value_in_table(t, entity)
                t = remove_value_in_table(t, index)
                ComponentSetValue2(var_storage, "value_string", table_to_string_table(t))
            end
        end
    end
end

function add_item_to_inventory(inventory, path)
    local item = EntityLoad(path)
    if item then
        GamePickUpInventoryItem(inventory, item)
    else
        GamePrint("Error: Couldn't load the item ["..path.."]!")
    end
    return item
end

function add_entity_to_inventory_bag(bag, inventory, entity)
    local var_storages = EntityGetComponentIncludingDisabled(entity, "VariableStorageComponent")
    local item_has_item_pickup_frame = false
    for _, var_storage in ipairs(var_storages or {}) do
        print(tostring(ComponentGetValue2(var_storage, "name")))
        if ComponentGetValue2(var_storage, "name") == "item_pickup_frame" then
            item_has_item_pickup_frame = true
            ComponentSetValue2(var_storage, "value_int", GameGetFrameNum())
        end
    end
    if not item_has_item_pickup_frame then
        EntityAddComponent2(entity, "VariableStorageComponent", {
            name="item_pickup_frame",
            value_int=GameGetFrameNum(),
        })
    end
    EntityRemoveFromParent(entity)
    EntityAddChild(inventory, entity)
    hide_entity(entity)
end

function add_spells_to_inventory(active_item, inventory, player_id, entities)
    for _, entity in ipairs(entities) do
        local parent = EntityGetParent(entity)
        local root_entity = EntityGetRootEntity(entity)
        if root_entity ~= player_id and not is_bag(root_entity) then
            if not EntityHasTag(parent, "wand") and is_bag_not_full(active_item, get_bag_inventory_size(active_item)) then
                add_entity_to_inventory_bag(active_item, inventory, entity)
            end
        end
    end
end

function add_wands_to_inventory(active_item, inventory, player_id, entities)
    for _, entity in ipairs(entities) do
        local root_entity = EntityGetRootEntity(entity)
        if root_entity ~= player_id and not is_bag(root_entity) then
            if is_bag_not_full(active_item, get_bag_inventory_size(active_item)) then
                add_entity_to_inventory_bag(active_item, inventory, entity)
            end
        end
    end
end

function add_potions_to_inventory(active_item, inventory, player_id, entities)
    for _, entity in ipairs(entities) do
        local root_entity = EntityGetRootEntity(entity)
        if root_entity ~= player_id and not is_bag(root_entity) then
            if is_bag_not_full(active_item, get_bag_inventory_size(active_item)) then
                add_entity_to_inventory_bag(active_item, inventory, entity)
            end
        end
    end
end

function add_items_to_inventory(active_item, inventory, player_id, entities)
    for _, entity in ipairs(entities) do
        if not is_bag(entity) and entity ~= active_item and not EntityHasTag(entity ,"essence") and item_pickup_is_pickable_in_inventory(entity) then
            local root_entity = EntityGetRootEntity(entity)
            if root_entity ~= player_id and not is_bag(root_entity) then
                if is_bag_not_full(active_item, get_bag_inventory_size(active_item)) then
                    add_entity_to_inventory_bag(active_item, inventory, entity)
                end
            end
        end
    end
end

function add_bags_to_inventory(active_item, inventory, player_id, entities)
    for _, entity in ipairs(entities) do
        if is_bag(entity) and entity ~= active_item then
            local root_entity = EntityGetRootEntity(entity)
            if root_entity ~= player_id and (root_entity == entity or not is_bag(root_entity)) then
                if is_bag_not_full(active_item, get_bag_inventory_size(active_item)) then
                    add_entity_to_inventory_bag(active_item, inventory, entity)
                end
            end
        end
    end
end

function get_active_item()
    local player = EntityGetWithTag("player_unit")[1]
    if player then
        local activeItem = ComponentGetValue2(EntityGetFirstComponentIncludingDisabled(player, "Inventory2Component"), "mActualActiveItem")
        return activeItem > 0 and activeItem or nil
    end
end

function get_inventory( entity_id )
    for _, child in ipairs(EntityGetAllChildren(entity_id) or {}) do
        if EntityGetName(child) == "inventory_full" then
            return child
        end
    end
end

function get_bag_inventory_items( entity_id )
    local inventory = get_inventory(entity_id)
    local items = EntityGetAllChildren(inventory)
    if items then
        return items
    else
        return {}
    end
end

function get_bag_inventory_size( entity_id )
    local size = tonumber(ModSettingGet("BagsOfMany.".. EntityGetName(entity_id) .. "_size"))
    if not size then
        size = 0
    else
        return math.floor(size)
    end
end

function get_potion_content( entity_id )
    local suc_component = EntityGetFirstComponentIncludingDisabled(entity_id, "MaterialSuckerComponent")
    local inv_component = EntityGetFirstComponentIncludingDisabled(entity_id, "MaterialInventoryComponent")
    if suc_component ~= nil and inv_component ~= nil then
        local capacity = ComponentGetValue2(suc_component, "barrel_size")
        local counts = ComponentGetValue2(inv_component, "count_per_material_type")
        local total = 0
        for i = 1, #counts do
            total = total + counts[i]
        end
        local biggest_percent_mat
        if total > 0 then
            for i = 1, #counts do
                local material = {
                    name = CellFactory_GetUIName(i - 1),
                    amount = (capacity/10) * (counts[i]/total)
                }
                if i == 1 then
                    biggest_percent_mat = material
                elseif biggest_percent_mat.amount < material.amount then
                    biggest_percent_mat = material
                end
            end
        end
        return biggest_percent_mat
    end
end

function get_sprite_file( entity_id )
    -- Sprite for the spells and wands
    if EntityHasTag(entity_id, "card_action") or EntityHasTag(entity_id, "wand") then
        local item_component = EntityGetComponentIncludingDisabled(entity_id, "SpriteComponent")
        if item_component then
            return ComponentGetValue2(item_component[1], "image_file")
        end
    -- Sprite for the other items
    else
        local item_component = EntityGetComponentIncludingDisabled(entity_id, "ItemComponent")
        if item_component then
            return ComponentGetValue2(item_component[1], "ui_sprite")
        end
    end
end

function hide_entity( entity_id )
    local components = EntityGetAllComponents(entity_id)
    local children = EntityGetAllChildren(entity_id)
    for _, child in ipairs(children or {}) do
        hide_entity(child)
    end
    for _, component in ipairs(components or {}) do
        EntitySetComponentIsEnabled(entity_id, component, false)
    end
end

function show_entity( entity_id )
    local x, y = get_player_pos()
    local components = EntityGetAllComponents(entity_id)
    local components_sprite = EntityGetComponentIncludingDisabled(entity_id, "SpriteParticleEmitterComponent")
    for _, component_sprite in ipairs(components_sprite or {}) do
        if ComponentHasTag(component_sprite, "enabled_in_world") then
            EntitySetComponentIsEnabled(entity_id, component_sprite, true)
        end
    end
    for _, component in ipairs(components or {}) do
        if ComponentHasTag(component, "enabled_in_world") then
            local component_type = ComponentGetTypeName(component)
            if component_type == "SpriteComponent" then
                local file_name = ComponentGetValue2(component, "image_file")
                if file_name and not string.find(file_name, "unidentified.png") then
                    EntitySetComponentIsEnabled(entity_id, component, true)
                end
            else
                EntitySetComponentIsEnabled(entity_id, component, true)
            end
        end
    end
end