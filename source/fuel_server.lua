local ESX = exports['es_extended']:getSharedObject()

RegisterServerEvent('fuel:pay')
AddEventHandler('fuel:pay', function(price)
	local xPlayer = ESX.GetPlayerFromId(source)
	local amount = ESX.Math.Round(price)
	if price > 0 then
		xPlayer.removeMoney(amount)
	end
end)

RegisterServerEvent('fuel:fuelHasBeenStealed')
AddEventHandler('fuel:fuelHasBeenStealed', function(storeId, plate, fuelCount)
	exports.vms_stores:sendAnnouncement(source, storeId, (Config.Strings.StealedFuel):format(plate, fuelCount), 'monitoring')
end)
