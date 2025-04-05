local config = lib.require('config')
local stevo_lib = exports['stevo_lib']:import()
lib.locale()


local zones = {}
local isSellingEnabled = false


function police_dispatch()
	local data = exports['cd_dispatch']:GetPlayerInfo()
	TriggerServerEvent('cd_dispatch:AddNotification', {
	    job_table = { 'police' }, 
	    coords = data.coords,
	    title = '10-284 - Drug Selling',
	    message = 'A '..data.sex..' selling drugs at '..data.street, 
	    flash = 0,
	    unique_id = data.unique_id,
	    sound = 1,
	    blip = {
	        sprite = 140, 
	        scale = 0.8, 
	        colour = 2,
	        flashes = false, 
	        text = '911 - Drug Selling',
	        time = 5,
	        radius = 0,
	    }
	})
end

function does_have_burner_phone()
	local has_burner = false
	local count = exports.ox_inventory:Search('count', "burner_phone")
	if count >= 1 then
		has_burner = true
	end

	if not has_burner then
		isSellingEnabled = false
		exports['okokNotify']:Alert('Trap phone missing...', '', 3000, 'error', true)
	end

	return has_burner
end

function does_have_drugs()
	local has_drugs = false
	for item, itemInfo in pairs(config.drugs) do
		local count = exports.ox_inventory:Search('count', item)
		if count >= 1 then
			has_drugs = true
		end
	end

	if not has_drugs then
		isSellingEnabled = false
		exports['okokNotify']:Alert('Don\'t have enough drugs to sell...', '', 3000, 'info', true)
	end

	return has_drugs
end


function prepare_buyer_offer()
    local buyer_offer = nil


    for item, itemInfo in pairs(config.drugs) do
        if buyer_offer ~= nil then
            break
        end

        local base_price = itemInfo.base_price
        local max_sale = itemInfo.max_sale
        local count = exports.ox_inventory:Search('count', item)

        if count >= 1 then
            if count > max_sale then 
                count = max_sale 
            end

            local offer_amount = base_price * count

            buyer_offer = {
                count = count,
                item = item,
                amount = offer_amount,
				rep = itemInfo.rep_sale
            }
        end
    end
    return buyer_offer
end


function can_ped_buy(closestPed)
	if IsEntityDead(closestPed) then return false end 
	if IsEntityPositionFrozen(closestPed) then return false end 
	if GetPedType(closestPed) == 28 then return false end 
	if IsPedInAnyVehicle(closestPed, true) then return false end
	if IsPedInAnyVehicle(PlayerPedId(), true) then return false end
    local cooldown = Entity(closestPed).state.stevo_drugcooldown

    if cooldown ~= true then
        return true
    else
        return false
    end
end


function reputation_menu()
	local current_reputation, gang_name = lib.callback.await('zayed_drugsell:getReputation', false)
	local current_replevel = config.reps[1] 
    local next_level = nil

	if current_reputation and gang_name then
    	for i, rep in ipairs(config.reps) do
    	    if current_reputation >= rep.min_reputation then
    	        current_replevel = rep
    	        next_level = config.reps[i + 1]
    	    else
    	        break
    	    end
    	end

		local current_min_reputation = current_replevel.min_reputation
    	local reputation_progress = current_reputation/10

		lib.registerContext({
			id = 'reputation_menu',
			title = gang_name,
			options = {
			  {
				title = current_replevel.label.. "" .. current_reputation .. "xp",
				description = current_replevel.description,
				colorScheme = 'red',
				progress = math.floor(reputation_progress),
			  },
			}
		})
		lib.showContext('reputation_menu')
	else
		exports['okokNotify']:Alert('You are not in a gang!', '', 3000, 'error', true)
	end
end
RegisterCommand(config.rep_command, reputation_menu)


function sale_anim(buyer_ped, player)

	local bag_model = lib.requestModel(joaat('prop_meth_bag_01'))
	local cash_model = lib.requestModel(joaat('prop_anim_cash_note'))
	local anim_dict = lib.requestAnimDict('mp_common')
	local anim_dict_2 = lib.requestAnimDict('weapons@holster_fat_2h')

	local bag = CreateObject(bag_model, 0, 0, 0, true, false, false)
	local cash = CreateObject(cash_model, 0, 0, 0, true, false, false)
	AttachEntityToEntity(bag, player, 90, 0.07, 0.01, -0.01, 136.33, 50.23, -50.26, true, true, false, true, 1, true)
	AttachEntityToEntity(cash, buyer_ped, GetPedBoneIndex(buyer_ped, 28422), 0.07, 0, -0.01, 18.12, 7.21, -12.44, true, true, false, true, 1, true)
	TaskPlayAnim(player, anim_dict, 'givetake1_a', 8.0, 8.0, -1, 32, 0.0, false, false, false)
	TaskPlayAnim(buyer_ped, anim_dict, 'givetake1_a', 8.0, 8.0, -1, 32, 0.0, false, false, false)

	Wait(1500)
	AttachEntityToEntity(bag, buyer_ped, GetPedBoneIndex(buyer_ped, 28422), 0.07, 0.01, -0.01, 136.33, 50.23, -50.26, true, true, false, true, 1, true)
	AttachEntityToEntity(cash, player, 90, 0.07, 0, -0.01, 18.12, 7.21, -12.44, true, true, false, true, 1, true)
	TaskPlayAnim(player, anim_dict_2, 'holster', 5.0, 1.5, 3000, 32, 0.0, false, false, false)
	TaskPlayAnim(buyer_ped, anim_dict_2, 'holster', 5.0, 1.5, 3000, 32, 0.0, false, false, false)
	Wait(500)

	DeleteEntity(bag)
	DeleteEntity(cash)
	Wait(100)
	PlayPedAmbientSpeechNative(buyer_ped, 'GENERIC_THANKS', 'SPEECH_PARAMS_STANDARD')
	TaskWanderStandard(buyer_ped, 10.0, 10)
	RemovePedElegantly(buyer_ped)
end


function attempt_sell(entity)
    exports.ox_target:disableTargeting(true)
	local buyer_ped = entity

	local cooldown = Entity(buyer_ped).state.stevo_drugcooldown
    if cooldown == true then
    exports.ox_target:disableTargeting(false)		
    return end

	ClearPedTasks(buyer_ped)

	math.randomseed(GetGameTimer())

	local chance = math.random(config.sellChance.min, config.sellChance.max)

	if chance <= config.sellChance.chance then
		TaskSetBlockingOfNonTemporaryEvents(buyer_ped, true)
		TaskTurnPedToFaceEntity(buyer_ped, cache.ped, -1)
		TaskTurnPedToFaceEntity(cache.ped, buyer_ped, -1)

		Wait(500)
		
		PlayPedAmbientSpeechNative(buyer_ped, "GENERIC_HI", "SPEECH_PARAMS_FORCE_NORMAL")

		local data = prepare_buyer_offer()

		sale_anim(buyer_ped, PlayerPedId())
		
		local attempted_sale, level_up, current_reputation, msg = lib.callback.await('zayed_drugsell:sale', false, data)

		if config.police.require and attempted_sale == 'nopol' then 
			stevo_lib.Notify(locale('no_police'), 'error', 5000)
			return
		end
			
		stevo_lib.Notify(locale('sale_amount')..data.count..(locale('sale_price'))..attempted_sale, 'success', 5000)

		exports.ox_target:disableTargeting(false)
		Wait(config.npc_delete_timer)
		DeleteEntity(buyer_ped)
		Wait(100)
		if isSellingEnabled and does_have_drugs() and does_have_burner_phone() then
			SpawnNPCforDrugSell() -- SPAWN NEXT PED FOR DEAL
		end
	else
		if config.police.callpoliceondeny then 
			police_dispatch() 
		end

		PlayPedAmbientSpeechNative(buyer_ped, "GENERIC_FRIGHTENED_HIGH", "SPEECH_PARAMS_FORCE_SHOUTED")
		TaskSmartFleePed(buyer_ped, PlayerPedId(), 10000.0, -1)
		exports.ox_target:disableTargeting(false)	
		stevo_lib.Notify(locale('failed_sale'), 'error', 5000)

		Wait(config.npc_delete_timer)
		DeleteEntity(buyer_ped)
		Wait(100)
		if isSellingEnabled and does_have_drugs() and does_have_burner_phone() then
			SpawnNPCforDrugSell() -- SPAWN NEXT PED FOR DEAL
		end
	end
end


CreateThread(function()
	if config.interaction.type == 'target' then
		local options = {
			options = {
				{
					name = 'zayed_drugsell:sell',
					icon = config.interaction.targeticon,
					label = config.interaction.targetlabel,
					distance = config.interaction.targetdistance,
					action = attempt_sell,
					canInteract = function(entity)
						return does_have_drugs() and can_ped_buy(entity)
					end
				},
			},
			distance = 5,
			rotation = vec3(0.0,0.0,0.0)
		}
		stevo_lib.target.addGlobalPed('drugselling_global', options)
	end
	if config.interaction.type == '3dtext' then
		local function drawPedText(coords)
			local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z+1)
		
			if onScreen then
				SetTextScale(0.4, 0.4)
				SetTextFont(4)
				SetTextProportional(1)
				SetTextColour(255, 255, 255, 255)
				SetTextOutline()
				SetTextEntry("STRING")
				SetTextCentre(true)
				AddTextComponentString(config.interaction.text)
				DrawText(_x, _y)
			end
		end
	
		local function getClosestPed(coords, maxDistance)
			local peds = GetGamePool('CPed')
			local closestPed, closestCoords
			maxDistance = maxDistance or 2.0
		
			for i = 1, #peds do
				local ped = peds[i]
		
				if not IsPedAPlayer(ped) then
					local pedCoords = GetEntityCoords(ped)
					local distance = #(coords - pedCoords)
		
					if distance < maxDistance then
						maxDistance = distance
						closestPed = ped
						closestCoords = pedCoords
					end
				end
			end
			return closestPed, closestCoords
		end

		Citizen.CreateThread(function()
			while true do
				local closestPed, closestPedCoords = getClosestPed(GetEntityCoords(cache.ped), 2)
				if closestPed ~= nil and can_ped_buy(closestPed) and does_have_drugs() then

					while closestPed ~= nil and can_ped_buy(closestPed) do
						drawPedText(closestPedCoords)
						if IsControlJustPressed(1, 38) then 
							attempt_sell(closestPed)
						end
						Citizen.Wait(0) 
						closestPed, closestPedCoords = getClosestPed(GetEntityCoords(cache.ped), 2)
					end
				else
					Citizen.Wait(1000)
				end
			end
		end)
	end
end)


function SpawnNPCforDrugSell()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local spawnDistance = 50.0
    
    -- Calculate spawn location
    local spawnX = playerCoords.x + math.random(-spawnDistance, spawnDistance)
    local spawnY = playerCoords.y + math.random(-spawnDistance, spawnDistance)
    local spawnZ = playerCoords.z
    
    -- Ensure NPC spawns on ground properly
    local _, groundZ = GetGroundZFor_3dCoord(spawnX, spawnY, spawnZ + 100.0, true)
    
    -- Define NPC model
    local npcModel = config.pedModels[math.random(#config.pedModels)]
    RequestModel(GetHashKey(npcModel))
    while not HasModelLoaded(GetHashKey(npcModel)) do
        Wait(100)
    end
    
    -- Create NPC at the calculated location
    local npcPed = CreatePed(4, GetHashKey(npcModel), spawnX, spawnY, groundZ, 0.0, true, true)
    
    -- Make NPC visible to all players
    SetEntityAsMissionEntity(npcPed, true, true)
    SetNetworkIdExistsOnAllMachines(NetworkGetNetworkIdFromEntity(npcPed), true)
    
    -- Ensure NPC doesn't fall through the map
    SetEntityCoordsNoOffset(npcPed, spawnX, spawnY, groundZ, false, false, false)
    PlaceObjectOnGroundProperly(npcPed)
    FreezeEntityPosition(npcPed, false)
    
    -- Make NPC walk towards the player
    TaskGoToEntity(npcPed, playerPed, -1, 2.0, 1.5, 0, 0)
	exports['okokNotify']:Alert('Buyer coming up...', '', 3000, 'info', true)
end

RegisterCommand("trap", function()
	if not isSellingEnabled and does_have_drugs() and does_have_burner_phone() then
		TaskStartScenarioInPlace(PlayerPedId(), "WORLD_HUMAN_STAND_MOBILE", 0, true)
		Wait(math.random(5000, 10000))
		ClearPedTasks(PlayerPedId()) 
		SpawnNPCforDrugSell()
		isSellingEnabled = true
	elseif isSellingEnabled then
		exports['okokNotify']:Alert('Stopped Trappin...', '', 3000, 'info', true)
		isSellingEnabled = false
	end
end, false)



--- ZONES THREAD DONOT TOUCH AT ALL, MANAGE EVERYTHING FROM CONFIG

Citizen.CreateThread(function()
    local blip_radius = {}
    local blip_marker = {}

    for k,v in pairs(config.Zones) do
        -- create zones depend of type

        if v['zone']['type'] == 'poly' then
            zones[k] = lib.zones.poly({
                points = v['zone']['coords'],
                thickness = v['zone']['thickness'],
                debug = v['zone']['debug'],
                inside = v['zone']['action'].inside,
                onEnter = v['zone']['action'].onEnter,
                onExit = v['zone']['action'].onExit
            })
        elseif v['zone']['type'] == 'box' then
            zones[k] = lib.zones.box({
                coords = v['zone']['coords'][1],
                size = v['zone']['size'],
                rotation = v['zone']['rotation'],
                debug = v['zone']['debug'],
                inside = v['zone']['action'].inside,
                onEnter = v['zone']['action'].onEnter,
                onExit = v['zone']['action'].onExit
            })
        elseif v['zone']['type'] == 'sphere' then
            zones[k] = lib.zones.sphere({
                coords = v['zone']['coords'][1],
                radius = v['zone']['radius'],
                debug = v['zone']['debug'],
                inside = v['zone']['action'].inside,
                onEnter = v['zone']['action'].onEnter,
                onExit = v['zone']['action'].onExit
            })
        end

        -- create radius blip if enabled
        if v['blip']['blip_radius']['enabled'] then
            blip_radius[k] = AddBlipForRadius(v['blip']['blip_radius']['coords']['X'], v['blip']['blip_radius']['coords']['Y'], v['blip']['blip_radius']['coords']['Z'], v['blip']['blip_radius']['radius'])
            SetBlipHighDetail(blip_radius[k], true)
            SetBlipColour(blip_radius[k], v['blip']['blip_radius']['color'])
            SetBlipAlpha(blip_radius[k], v['blip']['blip_radius']['alpha'])
            SetBlipAsShortRange(blip_radius[k], true)
        end
        -- create blip if enabled
        if v['blip']['blip_marker']['enabled'] then
            blip_marker[k] = AddBlipForCoord(v['blip']['blip_marker']['coords']['X'], v['blip']['blip_marker']['coords']['Y'], v['blip']['blip_marker']['coords']['Z'])
            SetBlipSprite(blip_marker[k], v['blip']['blip_marker']['sprite'])
            SetBlipDisplay(blip_marker[k], v['blip']['blip_marker']['display'])
            SetBlipScale(blip_marker[k], v['blip']['blip_marker']['scale'])
            SetBlipColour(blip_marker[k], v['blip']['blip_marker']['color'])
            SetBlipAsShortRange(blip_marker[k], true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(v['blip']['blip_marker']['text'])
            EndTextCommandSetBlipName(blip_marker[k])
        end
    end
end)