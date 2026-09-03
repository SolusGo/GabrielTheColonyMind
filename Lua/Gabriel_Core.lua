-- Gabriel -- The Colony Mind
-- Synchronized gameplay controller for Node timers/effects and Infestation.

print('[GABRIEL] Loading Colony Network controller')

local G_SAVE = Modding.OpenSaveData()
local CIV_GABRIEL = GameInfoTypes.CIVILIZATION_GABRIEL_COLONY
local IMPROVEMENT_NODE = GameInfoTypes.IMPROVEMENT_GABRIEL_COLONY_NODE
local BUILDING_NEXUS = GameInfoTypes.BUILDING_GABRIEL_COLONY_NEXUS
local UNIT_SWARM_HOST = GameInfoTypes.UNIT_GABRIEL_SWARM_HOST
local PROMOTION_NETWORK = GameInfoTypes.PROMOTION_GABRIEL_COLONY_NETWORK
local PROMOTION_REINFORCEMENT = GameInfoTypes.PROMOTION_GABRIEL_SWARM_REINFORCEMENT
local PROMOTION_INFESTATION_SOURCE = GameInfoTypes.PROMOTION_GABRIEL_INFESTATION_SOURCE
local PROMOTION_DETECTION = GameInfoTypes.PROMOTION_GABRIEL_NEXUS_DETECTION
local PROMOTION_INFESTATION = {
    GameInfoTypes.PROMOTION_GABRIEL_INFESTATION_1,
    GameInfoTypes.PROMOTION_GABRIEL_INFESTATION_2,
    GameInfoTypes.PROMOTION_GABRIEL_INFESTATION_3
}

local NETWORK_BUILDINGS = {}
local NEXUS_SCIENCE_BUILDINGS = {}
for i = 1, 6 do
    NETWORK_BUILDINGS[i] = GameInfoTypes['BUILDING_GABRIEL_NETWORK_' .. tostring(i)]
    NEXUS_SCIENCE_BUILDINGS[i] = GameInfoTypes['BUILDING_GABRIEL_NEXUS_SCIENCE_' .. tostring(i)]
end

local nodeCache = {}
local currentBattle = nil

local function Debug(message)
    print('[GABRIEL] ' .. tostring(message))
end

local function SavedNumber(key, fallback)
    local value = G_SAVE.GetValue(key)
    if value == nil then return fallback end
    return tonumber(value) or fallback
end

local function SetSavedNumber(key, value)
    G_SAVE.SetValue(key, value)
end

local function IsGabrielPlayer(player)
    return player ~= nil
        and player:IsAlive()
        and CIV_GABRIEL ~= nil
        and player:GetCivilizationType() == CIV_GABRIEL
end

local function CityKey(prefix, playerID, city)
    return 'GABRIEL_' .. prefix
        .. '_' .. tostring(playerID)
        .. '_' .. tostring(city:GetID())
        .. '_' .. tostring(city:GetGameTurnAcquired())
        .. '_' .. tostring(city:GetX())
        .. '_' .. tostring(city:GetY())
end

local function UnitKey(prefix, playerID, unitID)
    return 'GABRIEL_' .. prefix .. '_' .. tostring(playerID) .. '_' .. tostring(unitID)
end

local function PlotIndex(plot)
    if plot == nil then return -1 end
    return plot:GetPlotIndex()
end

local function PlotsInRadius(x, y, radius)
    local plots = {}
    local seen = {}
    for dx = -radius, radius do
        for dy = -radius, radius do
            local plot = Map.PlotXYWithRangeCheck(x, y, dx, dy, radius)
            if plot ~= nil then
                local index = PlotIndex(plot)
                if not seen[index] then
                    seen[index] = true
                    plots[#plots + 1] = plot
                end
            end
        end
    end
    return plots
end

local function HasBuilding(city, buildingID)
    if city == nil or buildingID == nil then return false end
    return city:GetNumRealBuilding(buildingID) > 0
        or city:GetNumFreeBuilding(buildingID) > 0
end

local function SetRealBuilding(city, buildingID, count)
    if city == nil or buildingID == nil then return end
    count = math.max(0, math.floor(count or 0))
    local freeCount = city:GetNumFreeBuilding(buildingID) or 0
    local target = math.max(0, count - freeCount)
    if city:GetNumRealBuilding(buildingID) ~= target then
        city:SetNumRealBuilding(buildingID, target)
    end
end

local function NodeOwner(plot)
    local index = PlotIndex(plot)
    if index < 0 then return -1 end
    local cached = nodeCache[index]
    if cached ~= nil then return cached end
    local saved = SavedNumber('GABRIEL_NODE_OWNER_' .. tostring(index), -1)
    if saved >= 0 then
        nodeCache[index] = saved
    end
    return saved
end

local function IsActiveNodeForPlayer(plot, playerID)
    if plot == nil or IMPROVEMENT_NODE == nil then return false end
    if plot:GetImprovementType() ~= IMPROVEMENT_NODE or plot:IsImprovementPillaged() then return false end
    if NodeOwner(plot) ~= playerID then return false end
    local plotOwner = plot:GetOwner()
    return plotOwner == -1 or plotOwner == playerID
end

local function UnitInsideNetwork(unit, playerID)
    if unit == nil or unit:IsDead() then return false end
    local plots = PlotsInRadius(unit:GetX(), unit:GetY(), 1)
    for _, plot in ipairs(plots) do
        if IsActiveNodeForPlayer(plot, playerID) then return true end
    end
    return false
end

local function NodeConnectedToNexus(nodePlot, playerID)
    local player = Players[playerID]
    if not IsGabrielPlayer(player) then return false end
    local plots = PlotsInRadius(nodePlot:GetX(), nodePlot:GetY(), 1)
    for _, plot in ipairs(plots) do
        local city = plot:GetPlotCity()
        if city ~= nil and city:GetOwner() == playerID and HasBuilding(city, BUILDING_NEXUS) then
            return true
        end
    end
    return false
end

local function UnitInsideDetectionNetwork(unit, playerID)
    if unit == nil or unit:IsDead() then return false end
    local plots = PlotsInRadius(unit:GetX(), unit:GetY(), 1)
    for _, plot in ipairs(plots) do
        if IsActiveNodeForPlayer(plot, playerID) and NodeConnectedToNexus(plot, playerID) then
            return true
        end
    end
    return false
end

local function UpdateUnitNetworkPromotions(playerID, unit)
    local player = Players[playerID]
    if unit == nil or not IsGabrielPlayer(player) then return end
    local military = unit:IsCombatUnit()
    local inside = military and UnitInsideNetwork(unit, playerID)
    if PROMOTION_NETWORK ~= nil then unit:SetHasPromotion(PROMOTION_NETWORK, inside) end
    if PROMOTION_REINFORCEMENT ~= nil then
        unit:SetHasPromotion(PROMOTION_REINFORCEMENT, inside and unit:GetUnitType() == UNIT_SWARM_HOST)
    end
    if PROMOTION_DETECTION ~= nil then
        unit:SetHasPromotion(PROMOTION_DETECTION, military and UnitInsideDetectionNetwork(unit, playerID))
    end
end

local function ClearCityDynamicBuildings(city)
    for i = 1, 6 do
        SetRealBuilding(city, NETWORK_BUILDINGS[i], 0)
        SetRealBuilding(city, NEXUS_SCIENCE_BUILDINGS[i], 0)
    end
end

local function AdjacentNodeCount(city, playerID)
    local count = 0
    local plots = PlotsInRadius(city:GetX(), city:GetY(), 1)
    for _, plot in ipairs(plots) do
        if PlotIndex(plot) ~= PlotIndex(city:Plot()) and IsActiveNodeForPlayer(plot, playerID) then
            count = count + 1
        end
    end
    return math.min(6, count)
end

local function UpdateCityNetwork(playerID, city)
    if city == nil then return end
    if not IsGabrielPlayer(Players[playerID]) then
        ClearCityDynamicBuildings(city)
        return
    end
    local count = AdjacentNodeCount(city, playerID)
    ClearCityDynamicBuildings(city)
    if count > 0 then
        SetRealBuilding(city, NETWORK_BUILDINGS[count], 1)
        if HasBuilding(city, BUILDING_NEXUS) then
            SetRealBuilding(city, NEXUS_SCIENCE_BUILDINGS[count], 1)
        end
    end
end

local function RefreshPlayerNetwork(playerID)
    local player = Players[playerID]
    if not IsGabrielPlayer(player) then return end
    for city in player:Cities() do UpdateCityNetwork(playerID, city) end
    for unit in player:Units() do UpdateUnitNetworkPromotions(playerID, unit) end
end

local function RebuildNodeCache()
    nodeCache = {}
    if IMPROVEMENT_NODE == nil then return end
    for index = 0, Map.GetNumPlots() - 1 do
        local plot = Map.GetPlotByIndex(index)
        if plot ~= nil and plot:GetImprovementType() == IMPROVEMENT_NODE then
            local owner = SavedNumber('GABRIEL_NODE_OWNER_' .. tostring(index), -1)
            if owner >= 0 then nodeCache[index] = owner end
        end
    end
    -- Share the live cache with the UI context so its dashboard never needs a
    -- per-turn full-map scan. The table remains current as Nodes change.
    MapModData.GabrielNodeOwners = nodeCache
    Debug('Node cache rebuilt with persistent builder ownership')
end

local function ReconcileNodeOwnership()
    local remove = {}
    for index, builderID in pairs(nodeCache) do
        local plot = Map.GetPlotByIndex(index)
        if plot == nil or plot:GetImprovementType() ~= IMPROVEMENT_NODE then
            remove[#remove + 1] = index
        else
            local owner = plot:GetOwner()
            if owner ~= -1 and owner ~= builderID then
                plot:SetImprovementType(-1)
                SetSavedNumber('GABRIEL_NODE_OWNER_' .. tostring(index), -1)
                remove[#remove + 1] = index
                Debug('Removed foreign-claimed Node at plot ' .. tostring(index))
            end
        end
    end
    for _, index in ipairs(remove) do nodeCache[index] = nil end
end

local function IsNaturalWonder(plot)
    local featureID = plot:GetFeatureType()
    if featureID == nil or featureID < 0 then return false end
    local info = GameInfo.Features[featureID]
    return info ~= nil and (tonumber(info.NaturalWonder) or 0) == 1
end

local function IsValuableExistingImprovement(plot)
    local improvementID = plot:GetImprovementType()
    if improvementID == nil or improvementID < 0 then return false end
    if improvementID == IMPROVEMENT_NODE then return true end
    local info = GameInfo.Improvements[improvementID]
    if info == nil then return true end
    return (tonumber(info.CreatedByGreatPerson) or 0) == 1
        or (tonumber(info.SpecificCivRequired) or 0) == 1
        or (tonumber(info.Permanent) or 0) == 1
        or (tonumber(info.Goody) or 0) == 1
        or (tonumber(info.BarbarianCamp) or 0) == 1
end

local function IsLegalNodePlot(playerID, city, plot)
    if city == nil or plot == nil then return false end
    if Map.PlotDistance(city:GetX(), city:GetY(), plot:GetX(), plot:GetY()) > 3 then return false end
    if plot:IsCity() or plot:IsWater() or plot:IsMountain() or plot:IsImpassable() then return false end
    local owner = plot:GetOwner()
    if owner ~= -1 and owner ~= playerID then return false end
    if IsNaturalWonder(plot) then return false end
    if plot:GetResourceType(-1) ~= -1 then return false end
    if IsValuableExistingImprovement(plot) then return false end
    return true
end

local function LegalNodePlots(playerID, city)
    local legal = {}
    for _, plot in ipairs(PlotsInRadius(city:GetX(), city:GetY(), 3)) do
        if IsLegalNodePlot(playerID, city, plot) then legal[#legal + 1] = plot end
    end
    return legal
end

local function NeighborNodeCount(plot, playerID)
    local count = 0
    for _, nearby in ipairs(PlotsInRadius(plot:GetX(), plot:GetY(), 2)) do
        if IsActiveNodeForPlayer(nearby, playerID) then count = count + 1 end
    end
    return count
end

local function ScoreNodePlot(playerID, city, plot)
    local distance = Map.PlotDistance(city:GetX(), city:GetY(), plot:GetX(), plot:GetY())
    local score = (distance == 1 and 120 or (4 - distance) * 10)
    if plot:IsHills() then score = score + 20 end
    if plot:GetOwner() == playerID then score = score + 8 end
    if plot:GetOwner() == -1 then score = score + 5 end
    if plot:IsRiver() then score = score - 8 end
    score = score + NeighborNodeCount(plot, playerID) * 12
    local nearbyForeign = false
    for _, nearby in ipairs(PlotsInRadius(plot:GetX(), plot:GetY(), 2)) do
        local owner = nearby:GetOwner()
        if owner ~= -1 and owner ~= playerID then nearbyForeign = true break end
    end
    if nearbyForeign then score = score + 25 end
    return score
end

local function PlaceNode(playerID, city, plot)
    if not IsLegalNodePlot(playerID, city, plot) then return false end
    plot:SetImprovementType(IMPROVEMENT_NODE, playerID)
    local index = PlotIndex(plot)
    nodeCache[index] = playerID
    SetSavedNumber('GABRIEL_NODE_OWNER_' .. tostring(index), playerID)
    SetSavedNumber(CityKey('PENDING', playerID, city), 0)
    SetSavedNumber(CityKey('TIMER', playerID, city), 0)
    RefreshPlayerNetwork(playerID)
    Debug('Player ' .. tostring(playerID) .. ' placed Node at ' .. tostring(plot:GetX()) .. ',' .. tostring(plot:GetY()))
    return true
end

local function AutoPlaceNode(playerID, city)
    local legal = LegalNodePlots(playerID, city)
    local bestPlot = nil
    local bestScore = -999999
    for _, plot in ipairs(legal) do
        local score = ScoreNodePlot(playerID, city, plot)
        if score > bestScore or (score == bestScore and PlotIndex(plot) < PlotIndex(bestPlot)) then
            bestPlot = plot
            bestScore = score
        end
    end
    return bestPlot ~= nil and PlaceNode(playerID, city, bestPlot)
end

local function NodeInterval()
    local speed = GameInfo.GameSpeeds[Game.GetGameSpeedType()]
    local percent = speed and tonumber(speed.TrainPercent) or 100
    return math.max(1, math.floor(30 * percent / 100 + 0.5))
end

local function NotifyNodeReady(playerID, city)
    local player = Players[playerID]
    if player == nil then return end
    local title = Locale.ConvertTextKey('TXT_KEY_GABRIEL_NODE_READY_TITLE', city:GetName())
    local body = Locale.ConvertTextKey('TXT_KEY_GABRIEL_NODE_READY_BODY', city:GetName())
    player:AddNotification(NotificationTypes.NOTIFICATION_GENERIC, body, title, city:GetX(), city:GetY())
end

local function ProcessCityTimer(playerID, player, city)
    local pendingKey = CityKey('PENDING', playerID, city)
    if SavedNumber(pendingKey, 0) == 1 then
        if player:IsHuman() then
            LuaEvents.Gabriel_NodePlacementAvailable(playerID, city:GetID(), city:GetX(), city:GetY())
        else
            AutoPlaceNode(playerID, city)
        end
        return
    end

    local timerKey = CityKey('TIMER', playerID, city)
    local timer = SavedNumber(timerKey, 0) + 1
    if timer < NodeInterval() then
        SetSavedNumber(timerKey, timer)
        return
    end

    SetSavedNumber(timerKey, NodeInterval())
    SetSavedNumber(pendingKey, 1)
    if player:IsHuman() then
        NotifyNodeReady(playerID, city)
        LuaEvents.Gabriel_NodePlacementAvailable(playerID, city:GetID(), city:GetX(), city:GetY())
    else
        AutoPlaceNode(playerID, city)
    end
end

local function CurrentInfestationStack(unit)
    if unit == nil then return 0 end
    for i = 3, 1, -1 do
        local promotionID = PROMOTION_INFESTATION[i]
        if promotionID ~= nil and unit:IsHasPromotion(promotionID) then return i end
    end
    return 0
end

local function SetInfestation(playerID, unit, stack, remaining)
    if unit == nil then return end
    stack = math.max(0, math.min(3, math.floor(stack or 0)))
    for i = 1, 3 do
        if PROMOTION_INFESTATION[i] ~= nil then
            unit:SetHasPromotion(PROMOTION_INFESTATION[i], i == stack)
        end
    end
    SetSavedNumber(UnitKey('INFESTATION_STACK', playerID, unit:GetID()), stack)
    SetSavedNumber(UnitKey('INFESTATION_TURNS', playerID, unit:GetID()), stack > 0 and remaining or 0)
end

local function ApplyInfestation(targetPlayerID, targetUnit)
    if targetUnit == nil or targetUnit:IsDead() or not targetUnit:IsCombatUnit() then return end
    local stack = math.min(3, CurrentInfestationStack(targetUnit) + 1)
    SetInfestation(targetPlayerID, targetUnit, stack, 3)
    Debug('Infestation applied to player ' .. tostring(targetPlayerID) .. ' unit ' .. tostring(targetUnit:GetID()) .. ' at stack ' .. tostring(stack))
end

local function ProcessInfestationTurn(playerID, player)
    if player == nil or not player:IsAlive() then return end
    for unit in player:Units() do
        local stack = CurrentInfestationStack(unit)
        if stack > 0 then
            local key = UnitKey('INFESTATION_TURNS', playerID, unit:GetID())
            local remaining = SavedNumber(key, 3) - 1
            if remaining <= 0 then
                SetInfestation(playerID, unit, 0, 0)
            else
                SetSavedNumber(key, remaining)
            end
        end
    end
end

local function ProcessGabrielTurn(playerID, player)
    ReconcileNodeOwnership()
    for city in player:Cities() do
        ProcessCityTimer(playerID, player, city)
        UpdateCityNetwork(playerID, city)
    end
    for unit in player:Units() do UpdateUnitNetworkPromotions(playerID, unit) end
end

local function OnPlayerDoTurn(playerID)
    local player = Players[playerID]
    ProcessInfestationTurn(playerID, player)
    if IsGabrielPlayer(player) then ProcessGabrielTurn(playerID, player) end
end

local function OnUnitSetXY(playerID, unitID)
    local player = Players[playerID]
    if not IsGabrielPlayer(player) then return end
    UpdateUnitNetworkPromotions(playerID, player:GetUnitByID(unitID))
end

local function OnUnitCreated(playerID, unitID)
    local player = Players[playerID]
    local unit = player and player:GetUnitByID(unitID) or nil
    if unit == nil then return end
    -- Unit IDs can be reused. A genuinely new unit never inherits old debuff data.
    if CurrentInfestationStack(unit) == 0 then
        SetSavedNumber(UnitKey('INFESTATION_STACK', playerID, unitID), 0)
        SetSavedNumber(UnitKey('INFESTATION_TURNS', playerID, unitID), 0)
    end
    if IsGabrielPlayer(player) then UpdateUnitNetworkPromotions(playerID, unit) end
end

local function OnUnitUpgraded(playerID, oldUnitID, newUnitID)
    local player = Players[playerID]
    local unit = player and player:GetUnitByID(newUnitID) or nil
    if unit == nil then return end
    local stack = CurrentInfestationStack(unit)
    if stack > 0 then
        local remaining = SavedNumber(UnitKey('INFESTATION_TURNS', playerID, oldUnitID), 3)
        SetInfestation(playerID, unit, stack, remaining)
    end
    SetSavedNumber(UnitKey('INFESTATION_STACK', playerID, oldUnitID), 0)
    SetSavedNumber(UnitKey('INFESTATION_TURNS', playerID, oldUnitID), 0)
    if IsGabrielPlayer(player) then UpdateUnitNetworkPromotions(playerID, unit) end
end

local function OnCityCaptureComplete(oldOwnerID, isCapital, x, y, newOwnerID)
    local plot = Map.GetPlot(x, y)
    local city = plot and plot:GetPlotCity() or nil
    if city == nil then return end
    ClearCityDynamicBuildings(city)
    local player = Players[newOwnerID]
    if IsGabrielPlayer(player) then
        SetSavedNumber(CityKey('TIMER', newOwnerID, city), 0)
        SetSavedNumber(CityKey('PENDING', newOwnerID, city), 0)
        UpdateCityNetwork(newOwnerID, city)
    end
end

local function OnCityConstructed(playerID, cityID, buildingType)
    if buildingType ~= BUILDING_NEXUS then return end
    local player = Players[playerID]
    local city = player and player:GetCityByID(cityID) or nil
    if city ~= nil then UpdateCityNetwork(playerID, city) end
end

local function OnBuildFinished(playerID, x, y)
    local player = Players[playerID]
    if not IsGabrielPlayer(player) then return end
    for city in player:Cities() do UpdateCityNetwork(playerID, city) end
    for unit in player:Units() do UpdateUnitNetworkPromotions(playerID, unit) end
end

local function OnTileImprovementChanged(x, y, plotOwnerID, oldImprovementID, newImprovementID, pillaged)
    if oldImprovementID ~= IMPROVEMENT_NODE and newImprovementID ~= IMPROVEMENT_NODE then return end
    local plot = Map.GetPlot(x, y)
    if plot == nil then return end
    local index = PlotIndex(plot)
    local builderID = nodeCache[index]
    if builderID == nil then builderID = SavedNumber('GABRIEL_NODE_OWNER_' .. tostring(index), -1) end

    if newImprovementID ~= IMPROVEMENT_NODE then
        nodeCache[index] = nil
        SetSavedNumber('GABRIEL_NODE_OWNER_' .. tostring(index), -1)
    elseif builderID < 0 and IsGabrielPlayer(Players[plotOwnerID]) then
        builderID = plotOwnerID
        nodeCache[index] = builderID
        SetSavedNumber('GABRIEL_NODE_OWNER_' .. tostring(index), builderID)
    end

    if builderID ~= nil and builderID >= 0 then RefreshPlayerNetwork(builderID) end
end

local function OnBattleStarted(battleType, x, y)
    currentBattle = { battleType = battleType, x = x, y = y, participants = {} }
end

local function OnBattleJoined(playerID, objectID, role, isCity)
    if currentBattle == nil then currentBattle = { participants = {} } end
    local participant = {
        playerID = playerID,
        objectID = objectID,
        role = role,
        isCity = isCity == true,
        beforeDamage = 0,
        infestationSource = false
    }
    if not participant.isCity then
        local player = Players[playerID]
        local unit = player and player:GetUnitByID(objectID) or nil
        if unit ~= nil then
            participant.beforeDamage = unit:GetDamage()
            participant.infestationSource = PROMOTION_INFESTATION_SOURCE ~= nil
                and unit:IsHasPromotion(PROMOTION_INFESTATION_SOURCE)
        end
    end
    currentBattle.participants[#currentBattle.participants + 1] = participant
end

local function OnBattleFinished()
    local battle = currentBattle
    currentBattle = nil
    if battle == nil then return end

    local sourceTeams = {}
    for _, participant in ipairs(battle.participants) do
        if participant.infestationSource then
            local player = Players[participant.playerID]
            if player ~= nil then sourceTeams[player:GetTeam()] = true end
        end
    end
    if next(sourceTeams) == nil then return end

    for _, participant in ipairs(battle.participants) do
        if not participant.isCity then
            local player = Players[participant.playerID]
            local unit = player and player:GetUnitByID(participant.objectID) or nil
            if unit ~= nil and not unit:IsDead() and unit:GetDamage() > participant.beforeDamage then
                local enemySource = false
                for teamID, _ in pairs(sourceTeams) do
                    if Teams[teamID]:IsAtWar(player:GetTeam()) then enemySource = true break end
                end
                if enemySource then ApplyInfestation(participant.playerID, unit) end
            end
        end
    end
end

local function OnPlaceNodeRequest(playerID, cityID, x, y)
    local player = Players[playerID]
    local city = player and player:GetCityByID(cityID) or nil
    local plot = Map.GetPlot(x, y)
    local success = false
    if IsGabrielPlayer(player) and city ~= nil
        and SavedNumber(CityKey('PENDING', playerID, city), 0) == 1 then
        success = PlaceNode(playerID, city, plot)
    end
    LuaEvents.Gabriel_NodePlacementResult(success, playerID, cityID, x, y)
    if success and player:IsHuman() then
        for pendingCity in player:Cities() do
            if SavedNumber(CityKey('PENDING', playerID, pendingCity), 0) == 1 then
                LuaEvents.Gabriel_NodePlacementAvailable(
                    playerID,
                    pendingCity:GetID(),
                    pendingCity:GetX(),
                    pendingCity:GetY()
                )
                break
            end
        end
    end
end

GameEvents.PlayerDoTurn.Add(OnPlayerDoTurn)
GameEvents.UnitSetXY.Add(OnUnitSetXY)

if GameEvents.UnitCreated ~= nil then GameEvents.UnitCreated.Add(OnUnitCreated) end
if GameEvents.UnitUpgraded ~= nil then GameEvents.UnitUpgraded.Add(OnUnitUpgraded) end
if GameEvents.CityCaptureComplete ~= nil then GameEvents.CityCaptureComplete.Add(OnCityCaptureComplete) end
if GameEvents.CityConstructed ~= nil then GameEvents.CityConstructed.Add(OnCityConstructed) end
if GameEvents.BuildFinished ~= nil then GameEvents.BuildFinished.Add(OnBuildFinished) end
if GameEvents.TileImprovementChanged ~= nil then GameEvents.TileImprovementChanged.Add(OnTileImprovementChanged) end
if GameEvents.BattleStarted ~= nil then GameEvents.BattleStarted.Add(OnBattleStarted) end
if GameEvents.BattleJoined ~= nil then GameEvents.BattleJoined.Add(OnBattleJoined) end
if GameEvents.BattleFinished ~= nil then GameEvents.BattleFinished.Add(OnBattleFinished) end

LuaEvents.Gabriel_PlaceNode.Add(OnPlaceNodeRequest)

RebuildNodeCache()
