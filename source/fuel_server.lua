RegisterServerEvent('fuel:fuelHasBeenStealed')
AddEventHandler('fuel:fuelHasBeenStealed', function(storeId, plate, fuelCount)
    exports.vms_stores:sendAnnouncement(
        source,
        storeId,
        (Config.Strings.StealedFuel):format(plate, fuelCount),
        'monitoring',
        { fuelCount = fuelCount }
    )
end)
