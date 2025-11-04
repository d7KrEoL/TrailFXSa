-- Original file encoding is ASCII Cyrillic Windows-1251
require 'moonloader'
require 'sampfuncs'

sampev = require "samp.events"

local dbOffset
local dbFX
local dbCars
local SmokeHistory
local CarTimeout
local IsActive
local Ver = "0.0.3-Alpha.0411"
local IsSmokeEnabled

script_name("TrailFX")
script_author("d7.KrEoL")
script_version(Ver)
script_url("https://vk.com/d7kreol")
script_description("Adding smoke trail effects to any plane")

function main()

	print("Waiting for SAMPFUNCS to load")
	
	repeat wait(3000) until isSampLoaded()
	repeat wait(3000) until isSampAvailable()
	
	print("TrailFX ver:", Ver)
	InitVars()
	InitDB()
	OnUpdate()
end

--------------------------------------------------Inits
function InitVars()
	FXStr = string.format("%s\\moonloader\\resource\\hyfx\\effects.fxp", getGameDirectory())
	CarTimeout = 30
	dbOffset = { modelID, x1, y1, z1, x2, y2, z2 }
	dbCars = {vehID, timeUpdate, isPlaying, offsetID, fxType, particle = {}}
	SmokeHistory = {time, particle}
	IsActive = true
	IsSmokeEnabled = true
	print("Vars initialized!")
end
function InitDB()
	print("Updating database")
	table.insert(dbOffset, { particleName = "blood_heli", modelID = 520, x1 = -5.21, y1 = -1.7, z1 = -0.35, x2 = 5.21, y2 = -1.7, z2 = -0.35 })
	table.insert(dbOffset, { particleName = "blood_heli", modelID = 476, x1 = 5.5, y1 = 1, z1 = -0.6, x2 = -5.5, y2 = 1, z2 = -0.6 })
	table.insert(SmokeHistory, {time = os.clock(), particle = 0})
	dbCars = OptimizeTable(dbCars)
	SmokeHistory = OptimizeTable(SmokeHistory)
	dbOffset = OptimizeTable(dbOffset)
	
	print("Loaded ", #dbOffset, " supported vehicles and models")
	print("Database initialized!")
end
-------------------------------------------------Update nearby
function EffectSwitch()
	IsActive = not(IsActive)
	if IsActive == false then 
		print("[TrailFX]: Скрипт отключен", 0xFF3CB371)
		dbClearCars()
	else
		print("[TrailFX]: Скрипт включен", 0xFF3CB371)
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
			dbFindInactiveCars()
		end
		if os.clock() - optimizationTimer > 60 then
			dbCars = OptimizeTable(dbCars)
			SmokeHistory = OptimizeTable(SmokeHistory)
		end
	end
end
function UpdateByChar()
	local vehs = getAllVehicles()
	local pPos = {X, Y, Z}
	pPos.X, pPos.Y, pPos.Z = getCharCoordinates(playerPed)
	for i, v in ipairs(vehs) do
		UpdateVehicle(v, pPos)
	end
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


----------------------------------------------Events
function OnExitScript(quitGame)
	ClearAll()
end
function onScriptTerminate(s, quitGame)
	if s == this then ClearAll() end
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
	print("OnVehOut: ", vehicleId)
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
	if not doesVehicleExist(v, pPos) then return end
	local PosX,PosY,PosZ = getCarCoordinates(v)
	local dist = getDistanceBetweenCoords3d(pPos.X, pPos.Y, pPos.Z, PosX, PosY, PosZ)
	local vehmodel = getCarModel(v)
	local planeOffset = GetPlaneOffsetType(vehmodel)
	if dist < 200 and not(planeOffset == nil) then
		local dbVehID = dbFindCarIndex(v)
		local vSpd = getCarSpeed(v)

		if dbVehID == nil or dbCars[dbVehID] == nil then
			print("Adding new veh to db (vehid, index): ", v, vehmodel, dbOffset[planeOffset].particleName)
			dbVehID = dbAddCar(v, planeOffset, 1)
		elseif IsSmokeEnabled and 
			vSpd > 10 then
				dbUpdateCarEffect(dbVehID)
			  dbStopEffect(dbVehID)
		end
	end
end

function GetPlaneOffsetType(modelID)
	if modelID == 520 then return 1
	elseif modelID == 476 then return 2
	end
end
----------------------------------------------Car Database Tools
function ClearAll()
	dbClearCars()
	ClearAllFXs()
	HistoryClearEffects()
end
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
	if dbCars[dbVehID].particle == nil  then
		dbCreateEffect(dbVehID)
	elseif dbCars[dbVehID].particle[1] == nil or dbCars[dbVehID].particle[2] == nil then
		dbCreateEffect(dbVehID)
	else
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
		print("car ", i, "is inactive")
		dbDelCar(i)
	elseif not IsVehicleActive(i) then
		print("car ", i, "is inactive")
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
	
	local prt1 = createFxSystemOnCar(dbOffset[offindex].particleName, 
		vehid, 
		dbOffset[offindex].x1, 
		dbOffset[offindex].y1, 
		dbOffset[offindex].z1, 
		dbCars[dbVehID].Type)
	local prt2 = createFxSystemOnCar(dbOffset[offindex].particleName, 
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
			print("count < 1: ", passengerCount, result, dbCars[vehID].vehID)
			return false
		end
	end
	return true
end

function AddFXCar(vID, sampID, idx, fxType)
	local index = FindSAIdIndbFX(sampID)
	if index == nil then
		table.insert(dbFX, {FXID = vID, sID= sampID, offsetID = idx, FXType = fxType, Particle = {}})
		return true
	end
	return false
end

function DeleteFXCar(vehID)
	local idx = FindIdIndbFX(vehID)
	if not(idx == nil) then
		DeleteEffect(idx)
		dbFX[idx] = nil
		return true
	end
	return false
end

function DeleteFXCarbySAID(sampID)
	local idx = FindSAIdIndbFX(sampID)
	if not(idx == nil) then
		DeleteEffect(idx)
		dbFX[idx] = nil
		return true
	end
	return false
end

function DeleteFXCarbyLocalID(scriptid)
	dbFX[scriptid] = nil
end

function FindIdIndbFX(id)
	if dbFX == nil then return end
	for i = 1, #dbFX do
		if dbFX[i].FXID == id then return i end
	end
	return nil
end

function FindSAIdIndbFX(sid)
	if dbFX == nil then return end
	for i = 1, #dbFX do
		if not(dbFX[i] == nil) then
			if dbFX[i].sID == sid then return i end
		end
	end
	return nil
end

function ClearAllFXs()
	if dbFX == nil then return end
	for i = 1, #dbFX do
		DeleteEffect(i)
		dbFX[i] = nil
	end
end

function Concta(id)
	local str
	if dbCars == nil then return end
	for i = 1, #dbCars do -- 1
		str = 
		sampAddChatMessage(string.format("%s %s %s %s %s %s %s", 
			dbCars[i].vehID, dbCars[i].timeUpdate, 
			dbCars[i].isPlaying, 
			dbCars[i].offsetID, 
			dbCars[i].fxType, 
			dbCars[i].particle[1], 
			dbCars[i].particle[2]), 
			0xFFFFFFFF)
	end
	
end

----------------------------------------------------------------
