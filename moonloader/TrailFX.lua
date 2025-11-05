require 'moonloader'
require 'sampfuncs'

sampev = require "samp.events"
local keys = require "vkeys"

local dbOffset
local dbCars
local SmokeHistory
local CarTimeout
local IsActive
local Ver = "0.0.3-dev.0611"
local IsSmokeEnabled

script_name("TrailFX")
script_author("d7.KrEoL")
script_version(Ver)
script_url("https://vk.com/d7kreol")
script_description("Adding smoke trail effects to any plane")

function main()

	print("Waiting for SAMPFUNCS to load")
	
	while not isSampLoaded() do wait(3000) end
	while not isSampAvailable() do wait(3000) end
	
	print("TrailFX ver:", Ver)
	InitVars()
	InitDB()
	
	sampRegisterChatCommand("trailfx", TrailFXCommand)
	OnUpdate()
end

--------------------------------------------------Inits
function InitVars()
	CarTimeout = 30
	dbOffset = { modelID, x1, y1, z1, x2, y2, z2 }
	dbCars = {vehID, timeUpdate, isPlaying, offsetID, fxType, particle = {}}
	SmokeHistory = {time, particle}
	IsActive = false
	IsSmokeEnabled = true
	print("Vars initialized!")
end
function InitDB()
	print("Updating database")

	--	Allowed particle names:
	--		Long trails:
	--			trail_red_long, trail_green_long, trail_blue_long, 
	--			trail_sky_long, trail_black_long, trail_purp_long
	--		Short trails:
	--			trail_red_short, trail_green_short, trail_blue_short,
	--			trail_sky_short, trail_black_short, trail_purp_short

	-- Hydra
	table.insert(dbOffset, { particleName1 = "trail_purp_short", particleName2 = "trail_purp_long", modelID = 520, x1 = -5.21, y1 = -1.7, z1 = -0.35, x2 = 5.21, y2 = -1.7, z2 = -0.35 })
	-- Rustler
	table.insert(dbOffset, { particleName1 = "trail_sky_long", particleName2 = "trail_sky_long", modelID = 476, x1 = 5.5, y1 = 1, z1 = -0.6, x2 = -5.5, y2 = 1, z2 = -0.6 })
	-- Stuntplane
	table.insert(dbOffset, { particleName1 = "trail_white_long", particleName2 = "trail_blue_long", modelID = 513, x1 = 3, y1 = -0.2, z1 = -1.5, x2 = -3, y2 = -0.2, z2 = -1.5 })
	table.insert(SmokeHistory, {time = os.clock(), particle = 0})

	dbCars = OptimizeTable(dbCars)
	SmokeHistory = OptimizeTable(SmokeHistory)
	dbOffset = OptimizeTable(dbOffset)
	
	print("Loaded ", #dbOffset, " supported vehicles and models")
	print("Database initialized!")
end
-------------------------------------------------Commands
function TrailFXCommand(args)
	if args == nil or #args < 1 then
		EffectSwitch()
	elseif #args < 2 then
		local id = tonumber(args)
		if (id == nil) then 
			print("Syntax: /trailfx [*(optional)player id]")
			return;
		end
		if not sampIsPlayerConnected(id) then
			print("Player ", id, "is not connected")
			return;
		end
		local result, ped = sampGetCharHandleBySampPlayerId(id)
		if not result then
			print("Cannot get player's ped for", id)
			return;
		end
		local vehID = storeCarCharIsInNoSave(ped)
		if not vehID then 
			print("Player is not in vehicle:", id)
			return;
		end
		local index = dbFindCarIndex(vehID)
		local modelID = getCarModel(vehID)
		local offset = GetPlaneOffsetType(modelID)
		if index == nil and offset ~= nil then
			print("Adding trail to a vehicle:", vehID)
			dbAddCar(vehID, offset, 1)
		elseif index ~= nil then
			print("Removing vehicle's trail", vehID)
			dbDelCar(index)
		end
	else
	end
end
-------------------------------------------------Updates
function EffectSwitch()
	IsActive = not(IsActive)
	if IsActive == false then 
		print("[TrailFX]: Script disabled", 0xFF3CB371)
		dbClearCars()
	else
		print("[TrailFX]: Script enabled", 0xFF3CB371)
		lua_thread.create(OnUpdateHistory)
	end
end
function OnUpdate()
	lua_thread.create(OnUpdateHistory)
	local optimizationTimer = os.clock()
	while true do
		wait(50)
		if IsActive then
			UpdateByChar()
			OnUpdateDBCars()
			dbFindInactiveCars()
		end
		if os.clock() - optimizationTimer > 60 then
			dbCars = OptimizeTable(dbCars)
			SmokeHistory = OptimizeTable(SmokeHistory)
		end
		OnUpdateKeys()
	end
end
function UpdateByChar()
	if not isCharInAnyPlane(playerPed) then return end
	local playerVeh = storeCarCharIsInNoSave(playerPed)
	if playerVeh == nil then return end
	local pPos = {X, Y, Z}
	pPos.X, pPos.Y, pPos.Z = getCharCoordinates(playerPed)
	UpdateVehicle(playerVeh, pPos)
end

function OnUpdateDBCars()
	for i = 1, #dbCars do
		dbUpdateCarEffect(i)
	end
end

function OnUpdateHistory()
	local localTime
	while IsSmokeEnabled do
		localTime = os.clock()
		for i = 1, #SmokeHistory do
			if localTime - SmokeHistory[i].time > 5 then
				HistoryDeleteEffect(i)
			end
			HistoryPlayEffect(i)
		end
		wait(30)
	end
	HistoryClearEffects()
end

function OnUpdateKeys()
	if isKeyJustPressed(keys.VK_G) then
		TrailFXCommand()
	end
end


----------------------------------------------Events
function OnExitScript(quitGame)
	ClearAll()
end

function onScriptTerminate(s, quitGame)
	if s == this then ClearAll() end
end

function ClearAll()
	dbClearCars()
	HistoryClearEffects()
end

function sampev.onVehicleStreamIn(vehid, data)
	local idx = IsVehSupportsFX(data.type)
	local pPos = {X, Y, Z}
	pPos.X, pPos.Y, pPos.Z = getCharCoordinates(playerPed)
	if not(idx == nil) then
		UpdateVehicle(vehid, pPos)
	end
end

function sampev.onVehicleStreamOut(vehicleId)
	local dbVehId = dbFindCarIndex(vehicleid)
	if dbVehId ~= nil then
		dbDeleteEffect()
	end
end

----------------------------------------------Smoke history
function HistoryAddEffect(vehicleid, particleName, offsetValue) 
	if not doesVehicleExist(vehicleid) then return false end
	local x, y, z = getOffsetFromCarInWorldCoords(vehicleid, offsetValue.x, offsetValue.y, offsetValue.z)
	local particle = createFxSystem(particleName, x, y, z, 1)
	if (particle == nil) then
		return false;
	end
	table.insert(SmokeHistory, {time = os.clock(), particle = particle})
	return true;
end
function HistoryDeleteEffect(effectid)
	if SmokeHistory == nil then return false end
	if #SmokeHistory <= effectid then return false end
	if SmokeHistory[i] == nil then return false end
	stopFxSystem(SmokeHistory[i].particle1)
	stopFxSystem(SmokeHistory[i].particle2)
	killFxSystem(SmokeHistory[i].particle1)
	killFxSystem(SmokeHistory[i].particle2)
	SmokeHistory[i] = nil
end
function HistoryClearEffects()
	for i = 1, i < #SmokeHistory do
		HistoryDeleteEffect(i)
	end
end
function HistoryPlayEffect(effectid)
	if #SmokeHistory <= effectid then return false end
	if SmokeHistory[i] == nil then return false end
	playFxSystem(SmokeHistory[effectid].particle[0])
	playFxSystem(SmokeHistory[effectid].particle[1])
end
---------------------------------------------Vehicles
function UpdateVehicle(v, pPos)
	if not doesVehicleExist(v) then return end
	local PosX,PosY,PosZ = getCarCoordinates(v)
	local dist = getDistanceBetweenCoords3d(pPos.X, pPos.Y, pPos.Z, PosX, PosY, PosZ)
	local vehmodel = getCarModel(v)
	local planeOffset = GetPlaneOffsetType(vehmodel)
	if dist < 200 and not(planeOffset == nil) then
		local dbVehID = dbFindCarIndex(v)
		local vSpd = getCarSpeed(v)

		if dbVehID == nil or dbCars[dbVehID] == nil then
			dbVehID = dbAddCar(v, planeOffset, 1)
		elseif IsSmokeEnabled and 
			vSpd > 10 then
				dbUpdateCarEffect(dbVehID)
		else 
			dbStopEffect(dbVehID)
		end
	end
end

function GetPlaneOffsetType(modelID)
	if modelID == 520 then return 1
	elseif modelID == 476 then return 2
	elseif modelID == 513 then return 3
	end
	return nil
end
----------------------------------------------Car Database Tools

function dbAddCar(VehID, OffsetID, FXType)
	local dbVehID = dbFindCarIndex(VehID)
	if dbVehID == nil then
		table.insert(dbCars, {vehID = VehID, timeUpdate = os.clock(), isPlaying = false, offsetID = OffsetID, fxType = FXType, particle = {}})
		if dbCars[#dbCars].vehID == VehID then 
			return #dbCars
		else 
			return nil
		end
	else
		return dbVehID
	end
end
function dbUpdateCarEffect(dbVehID)
	if dbCars == nil then return end
	if dbCars[dbVehID] == nil then return end
	if dbCars[dbVehID].particle == nil  then
		dbCreateEffect(dbVehID)
	elseif dbCars[dbVehID].particle[1] == nil or dbCars[dbVehID].particle[2] == nil then
		dbCreateEffect(dbVehID)
	end
	if not dbPlayEffect(dbVehID) then
		print("Cannt play effect for", dbVehID)
	end
end
function dbFindCarIndex(VehID)
	if dbCars == nil then return nil end
	for i = 1, #dbCars do
		if not(dbCars[i] == nil) then
			if dbCars[i].vehID == VehID then return i end
		end
	end
	return nil
end
function dbFindInactiveCars()
	if dbCars == nil then return end
	for i = 1, #dbCars do
		dbFindInactiveCarIteration(i)
	end
end
function dbFindInactiveCarIteration(i)
	if dbCars[i] == nil then return end
	if dbCars[i].vehID == nil then return end
	if not doesVehicleExist(dbCars[i].vehID) then
		dbDelCar(i)
	elseif not IsVehicleActive(i) then
		dbDelCar(i)
	end
end
function dbUpdateCarTimer(dbVehID)
	dbCars[dbVehID].timeUpdate = os.clock()
end
function dbDelCar(dbVehID)
	if dbVehID == nil then return false end
	dbDeleteEffect(dbVehID)
	dbCars[dbVehID] = nil
	return true
end
function dbCreateEffect(dbVehID)
	if dbVehID == nil or dbCars[dbVehID] == nil then return false end
	local vehid = dbCars[dbVehID].vehID
	local offindex = dbCars[dbVehID].offsetID
	
	local prt1 = createFxSystemOnCar(dbOffset[offindex].particleName1, 
		vehid, 
		dbOffset[offindex].x1, 
		dbOffset[offindex].y1, 
		dbOffset[offindex].z1, 
		dbCars[dbVehID].Type)
	local prt2 = createFxSystemOnCar(dbOffset[offindex].particleName2, 
		vehid, 
		dbOffset[offindex].x2, 
		dbOffset[offindex].y2, 
		dbOffset[offindex].z2, 
		dbCars[dbVehID].Type)
	if prt1 == nil or prt1 == -1 or prt2 == nil or prt2 == -1 then 
		killFxSystem(prt1)
		killFxSystem(prt2)
		return false 
	end
	table.insert(dbCars[dbVehID].particle, prt1)
	table.insert(dbCars[dbVehID].particle, prt2)
	return true
end
function dbStopEffect(dbVehID)
	if dbVehID == nil or dbCars[dbVehID] == nil then print("StopErr: dbVehID or [dbVeh] == nil") return false end
	if dbCars[dbVehID].particle == nil then print("StopErr: Particle == nil") return false end
	if dbCars[dbVehID].particle[1] == -1 or dbCars[dbVehID].particle[2] == -1 then return false end
	if dbCars[dbVehID].isPlaying == false then return true end
	
	stopFxSystem(dbCars[dbVehID].particle[1])
	stopFxSystem(dbCars[dbVehID].particle[2])
	dbCars[dbVehID].isPlaying = false
end

function dbPlayEffect(dbVehID)
	if dbVehID == nil or dbCars[dbVehID] == nil then return false end
	if dbCars[dbVehID].particle == nil then return false end
	if dbCars[dbVehID].particle[1] == -1 or dbCars[dbVehID].particle[2] == -1 then return false end
	if dbCars[dbVehID].isPlaying == true then 
		wait(10)
	end
	
	playFxSystem(dbCars[dbVehID].particle[1])
	playFxSystem(dbCars[dbVehID].particle[2])
	dbCars[dbVehID].isPlaying = true
	return true
end

function dbDeleteEffect(dbVehID)
	if dbVehID == nil or dbCars[dbVehID] == nil then return false end
	if dbCars[dbVehID].particle == nil then return false end
	dbStopEffect(dbVehID)
	for i = 1, #dbCars[dbVehID].particle do
		killFxSystem(dbCars[dbVehID].particle[i])
		dbCars[dbVehID].particle[i] = nil
	end
end

function dbClearCars()
	for i = 1, #dbCars do
		dbDelCar(i)
	end
end

----------------------------------------------Other Tools

function OptimizeTable(tableObject)
    if tableObject == nil then return tableObject end
    if #tableObject < 1 then return tableObject end
    local firstNilIndex
	local i = 0
    repeat 
		firstNilIndex = nil
		if tableObject[i] == nil and i < #tableObject then
			firstNilIndex = i
		elseif firstNilIndex ~= nil then
			tableObject[firstNilIndex] = tableObject[i]
			firstNilIndex = i
		end
		i = i + 1
	until firstNilIndex ~= nil
    
    return tableObject
end

function IsVehSupportsFX(vehID)
	if dbOffset == nil then return end
	for i = 1, #dbOffset do -- 1
		if vehID == dbOffset[i].modelID then return i end
	end
	return nil
end

function IsVehicleActive(vehID)
	local result, passengerCount = getNumberOfPassengers(dbCars[vehID].vehID)
	if (getDriverOfCar(dbCars[vehID].vehID) ~= 0) then passengerCount = passengerCount + 1 end
	if not(dbCars[vehID] == nil) then
		if ((os.clock() - dbCars[vehID].timeUpdate) > CarTimeout) then
			return false
		elseif (passengerCount < 1) then
			return false
		end
	end
	return true
end

----------------------------------------------------------------