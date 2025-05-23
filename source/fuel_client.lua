local currentVehicle = nil
local currentStore = nil
local storeFuel = 0

local isNearPump = false
local isFueling = false
local currentFuel = 0.0
local fuelSynced = false
local inBlacklisted = false
local paidForFuel = false
local fuelCount = 0

AddEventHandler('vms_stores:enterStoreZone', function(storeId)
	paidForFuel = false
	currentStore = storeId
	storeFuel = 9999999
end)

RegisterNetEvent('vms_stores:fuelStoreUpdated', function(storeId, fuel)
	if currentStore == storeId and fuel then
		storeFuel = fuel
	end
end)

RegisterNetEvent('vms_stores:fuelStorePaid', function(storeId, fuel)
	paidForFuel = true
	fuelCount = 0
end)

AddEventHandler('vms_stores:exitStoreZone', function()
	if Config.AbilityStealFuel and fuelCount > 0 then
		TriggerServerEvent('fuel:fuelHasBeenStealed',
			currentStore,
			GetVehicleNumberPlateText(currentVehicle),
			fuelCount
		)
	end
	paidForFuel = false
	currentStore = nil
	fuelCount = 0
	storeFuel = 0
end)

function ManageFuelUsage(vehicle)
	if not DecorExistOn(vehicle, Config.FuelDecor) then
		SetFuel(vehicle, math.random(200, 800) / 10)
	elseif not fuelSynced then
		SetFuel(vehicle, GetFuel(vehicle))
		fuelSynced = true
	end

	if IsVehicleEngineOn(vehicle) then
		SetFuel(vehicle, GetVehicleFuelLevel(vehicle) - Config.FuelUsage[Round(GetVehicleCurrentRpm(vehicle), 1)] * (Config.Classes[GetVehicleClass(vehicle)] or 1.0) / 10)
	end
end

Citizen.CreateThread(function()
	DecorRegister(Config.FuelDecor, 1)
	for index = 1, #Config.Blacklist do
		if type(Config.Blacklist[index]) == 'string' then
			Config.Blacklist[GetHashKey(Config.Blacklist[index])] = true
		else
			Config.Blacklist[Config.Blacklist[index]] = true
		end
	end
	for index = #Config.Blacklist, 1, -1 do
		table.remove(Config.Blacklist, index)
	end

	while true do
		Citizen.Wait(1000)
		local ped = PlayerPedId()
		if IsPedInAnyVehicle(ped) then
			local vehicle = GetVehiclePedIsIn(ped)
			if Config.Blacklist[GetEntityModel(vehicle)] then
				inBlacklisted = true
			else
				inBlacklisted = false
			end
			if not inBlacklisted and GetPedInVehicleSeat(vehicle, -1) == ped then
				ManageFuelUsage(vehicle)
			end
		else
			fuelSynced = false
			inBlacklisted = false
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(250)
		local pumpObject, pumpDistance = FindNearestFuelPump()
		if pumpDistance < 4.0 then
			isNearPump = pumpObject
		else
			isNearPump = false
			Citizen.Wait(math.ceil(pumpDistance * 20))
		end
	end
end)

AddEventHandler('fuel:startFuelUpTick', function(pumpObject, ped, vehicle)
	currentVehicle = vehicle
	currentFuel = GetVehicleFuelLevel(vehicle)
	paidForFuel = true
	while isFueling do
		Citizen.Wait(500)
		local oldFuel = DecorGetFloat(vehicle, Config.FuelDecor)
		local fuelToAdd = math.floor(math.random(10, 20) / 10.0)
		if not pumpObject then
			if GetAmmoInPedWeapon(ped, 883325847) - fuelToAdd * 100 >= 0 then
				currentFuel = oldFuel + fuelToAdd
				SetPedAmmo(ped, 883325847, math.floor(GetAmmoInPedWeapon(ped, 883325847) - fuelToAdd * 100))
			else
				isFueling = false
			end
		else
			fuelCount = fuelCount + fuelToAdd
			currentFuel = oldFuel + (Config.AbilityStealFuel and fuelToAdd or fuelCount)
			local ranOutOfFuel = exports['vms_stores']:addFuelToCart(fuelToAdd)
			if ranOutOfFuel then
				isFueling = false
				break
			end
			if Config.AbilityStealFuel then
				SetFuel(vehicle, currentFuel)
			end
		end
		if currentFuel > 100.0 then
			currentFuel = 100.0
			isFueling = false
		end
	end
end)

AddEventHandler('fuel:refuelFromPump', function(pumpObject, ped, vehicle)
	TaskTurnPedToFaceEntity(ped, vehicle, 1000)
	Citizen.Wait(1000)
	SetCurrentPedWeapon(ped, -1569615261, true)
	LoadAnimDict("timetable@gardener@filling_can")
	TaskPlayAnim(ped, "timetable@gardener@filling_can", "gar_ig_5_filling_can", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
	TriggerEvent('fuel:startFuelUpTick', pumpObject, ped, vehicle)

	while isFueling do
		for _, controlIndex in pairs(Config.DisableKeys) do
			DisableControlAction(0, controlIndex)
		end
		local vehicleCoords = GetEntityCoords(vehicle)
		if pumpObject then
			local stringCoords = GetEntityCoords(pumpObject)
			DrawText3Ds(stringCoords.x, stringCoords.y, stringCoords.z + 1.2, Config.Strings.CancelFuelingPump)
			DrawText3Ds(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, Round(currentFuel, 1) .. "%")
		else
			DrawText3Ds(vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5, Config.Strings.CancelFuelingJerryCan .. "\nGas can: ~g~" .. Round(GetAmmoInPedWeapon(ped, 883325847) / 4500 * 100, 1) .. "% | Vehicle: " .. Round(currentFuel, 1) .. "%")
		end
		if not IsEntityPlayingAnim(ped, "timetable@gardener@filling_can", "gar_ig_5_filling_can", 3) then
			TaskPlayAnim(ped, "timetable@gardener@filling_can", "gar_ig_5_filling_can", 2.0, 8.0, -1, 50, 0, 0, 0, 0)
		end
		if IsControlJustReleased(0, 38) or DoesEntityExist(GetPedInVehicleSeat(vehicle, -1)) or (isNearPump and GetEntityHealth(pumpObject) <= 0) then
			isFueling = false
		end
		Citizen.Wait(0)
	end
	ClearPedTasks(ped)
	RemoveAnimDict("timetable@gardener@filling_can")
end)

if Config.ShowNearestGasStationOnly then
	Citizen.CreateThread(function()
		local currentGasBlip = 0
		while true do
			local coords = GetEntityCoords(PlayerPedId())
			local closest = 1000
			local closestCoords
			for _, gasStationCoords in pairs(Config.GasStations) do
				local dstcheck = GetDistanceBetweenCoords(coords, gasStationCoords)
				if dstcheck < closest then
					closest = dstcheck
					closestCoords = gasStationCoords
				end
			end
			if DoesBlipExist(currentGasBlip) then
				RemoveBlip(currentGasBlip)
			end
			currentGasBlip = CreateBlip(closestCoords)
			Citizen.Wait(10000)
		end
	end)
elseif Config.ShowAllGasStations then
	Citizen.CreateThread(function()
		for _, gasStationCoords in pairs(Config.GasStations) do
			CreateBlip(gasStationCoords)
		end
	end)
end
