-- Gabriel -- Colony Network dashboard and human Node placement.

include("IconSupport")

local G_SAVE = Modding.OpenSaveData()
local CIV_GABRIEL = GameInfoTypes.CIVILIZATION_GABRIEL_COLONY
local IMPROVEMENT_NODE = GameInfoTypes.IMPROVEMENT_GABRIEL_COLONY_NODE
local BUILDING_NEXUS = GameInfoTypes.BUILDING_GABRIEL_COLONY_NEXUS
local PROMOTION_NETWORK = GameInfoTypes.PROMOTION_GABRIEL_COLONY_NETWORK

local gPlayerID = -1
local gCityID = -1
local gCandidates = {}
local gSelection = 1
local gPlacementOpen = false
local gDashboardOpen = false
local gCityScreenOpen = false
local gDiplomacyOpen = false
local gDiplomacyPopups = {}
local gSelectedCityID = nil
local gCityDropdownEntries = {}
local RefreshDashboard

local function SavedNumber(key, fallback)
    local value = G_SAVE.GetValue(key)
    if value == nil then return fallback end
    return tonumber(value) or fallback
end

local function PlotIndex(plot)
    if plot == nil then return -1 end
    return plot:GetPlotIndex()
end

local function CityKey(prefix, playerID, city)
    return 'GABRIEL_' .. prefix
        .. '_' .. tostring(playerID)
        .. '_' .. tostring(city:GetID())
        .. '_' .. tostring(city:GetGameTurnAcquired())
        .. '_' .. tostring(city:GetX())
        .. '_' .. tostring(city:GetY())
end

local function NodeInterval()
    local speed = GameInfo.GameSpeeds[Game.GetGameSpeedType()]
    local percent = speed and tonumber(speed.TrainPercent) or 100
    return math.max(1, math.floor(30 * percent / 100 + 0.5))
end

local function IsGabrielPlayer(player)
    return player ~= nil
        and player:IsAlive()
        and CIV_GABRIEL ~= nil
        and player:GetCivilizationType() == CIV_GABRIEL
end

local function ActiveGabrielPlayer()
    local playerID = Game.GetActivePlayer()
    if playerID == nil or playerID < 0 then return nil, -1 end
    local player = Players[playerID]
    if not IsGabrielPlayer(player) then return nil, playerID end
    return player, playerID
end

local function IsDiplomacyOpen()
    if gDiplomacyOpen then return true end
    return UI ~= nil
        and UI.GetLeaderHeadRootUp ~= nil
        and UI.GetLeaderHeadRootUp()
end

local function IsOverlayBlocked()
    return gCityScreenOpen or IsDiplomacyOpen() or next(gDiplomacyPopups) ~= nil
end

local function HasBuilding(city, buildingID)
    if city == nil or buildingID == nil then return false end
    return city:GetNumRealBuilding(buildingID) > 0
        or city:GetNumFreeBuilding(buildingID) > 0
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

local function NodeOwner(plot)
    local index = PlotIndex(plot)
    if index < 0 then return -1 end
    local savedOwner = SavedNumber('GABRIEL_NODE_OWNER_' .. tostring(index), -1)
    if savedOwner >= 0 then return savedOwner end
    -- Older saves may contain a Node before the persistent builder key was
    -- introduced.  Owned plots still provide a safe ownership fallback.
    local plotOwner = plot:GetOwner()
    if IsGabrielPlayer(Players[plotOwner]) then return plotOwner end
    return -1
end

local function IsActiveNodeForPlayer(plot, playerID)
    if plot == nil or IMPROVEMENT_NODE == nil then return false end
    if plot:GetImprovementType() ~= IMPROVEMENT_NODE or plot:IsImprovementPillaged() then return false end
    if NodeOwner(plot) ~= playerID then return false end
    local owner = plot:GetOwner()
    return owner == -1 or owner == playerID
end

local function AdjacentNodeCount(city, playerID)
    local count = 0
    for _, plot in ipairs(PlotsInRadius(city:GetX(), city:GetY(), 1)) do
        if PlotIndex(plot) ~= PlotIndex(city:Plot()) and IsActiveNodeForPlayer(plot, playerID) then
            count = count + 1
        end
    end
    return math.min(6, count)
end

local function IsNaturalWonder(plot)
    local featureID = plot:GetFeatureType()
    if featureID == nil or featureID < 0 then return false end
    local info = GameInfo.Features[featureID]
    return info ~= nil and (tonumber(info.NaturalWonder) or 0) == 1
end

local function HasProtectedImprovement(plot)
    local improvementID = plot:GetImprovementType()
    if improvementID == nil or improvementID < 0 then return false end
    local info = GameInfo.Improvements[improvementID]
    if info == nil then return true end
    return (tonumber(info.CreatedByGreatPerson) or 0) == 1
        or (tonumber(info.SpecificCivRequired) or 0) == 1
        or (tonumber(info.Permanent) or 0) == 1
        or (tonumber(info.Goody) or 0) == 1
        or (tonumber(info.BarbarianCamp) or 0) == 1
end

local function IsCandidate(playerID, city, plot)
    if plot == nil or city == nil then return false end
    if Map.PlotDistance(city:GetX(), city:GetY(), plot:GetX(), plot:GetY()) > 3 then return false end
    if plot:IsCity() or plot:IsWater() or plot:IsMountain() or plot:IsImpassable() then return false end
    local owner = plot:GetOwner()
    if owner ~= -1 and owner ~= playerID then return false end
    if IsNaturalWonder(plot) or plot:GetResourceType(-1) ~= -1 then return false end
    if HasProtectedImprovement(plot) then return false end
    return true
end

local function BuildCandidates(playerID, city)
    local candidates = {}
    local seen = {}
    for dx = -3, 3 do
        for dy = -3, 3 do
            local plot = Map.PlotXYWithRangeCheck(city:GetX(), city:GetY(), dx, dy, 3)
            if plot ~= nil and IsCandidate(playerID, city, plot) then
                local index = PlotIndex(plot)
                if not seen[index] then
                    seen[index] = true
                    candidates[#candidates + 1] = plot
                end
            end
        end
    end
    table.sort(candidates, function(a, b) return PlotIndex(a) < PlotIndex(b) end)
    return candidates
end

local function ClearHighlights()
    for _, plot in ipairs(gCandidates) do
        Events.SerialEventHexHighlight(ToHexFromGrid(Vector2(plot:GetX(), plot:GetY())), false)
    end
end

local function PlotLabel(plot)
    if plot == nil then return '' end
    local terrain = GameInfo.Terrains[plot:GetTerrainType()]
    local terrainName = terrain and Locale.ConvertTextKey(terrain.Description)
        or Locale.ConvertTextKey('TXT_KEY_MISC_UNKNOWN')
    local ownerText = plot:GetOwner() == -1
        and Locale.ConvertTextKey('TXT_KEY_GABRIEL_NODE_UNOWNED')
        or Locale.ConvertTextKey('TXT_KEY_GABRIEL_NODE_OWNED')
    return string.format('%s  |  (%d, %d)  |  %s', terrainName, plot:GetX(), plot:GetY(), ownerText)
end

local function RefreshPlacementPanel()
    ClearHighlights()
    if #gCandidates == 0 then
        Controls.Candidate:SetText(Locale.ConvertTextKey('TXT_KEY_GABRIEL_NODE_INVALID'))
        Controls.PlaceButton:SetDisabled(true)
        return
    end
    if gSelection < 1 then gSelection = #gCandidates end
    if gSelection > #gCandidates then gSelection = 1 end
    Controls.PlaceButton:SetDisabled(false)
    for i, plot in ipairs(gCandidates) do
        local color = i == gSelection and Vector4(1.0, 0.72, 0.18, 1.0)
            or Vector4(0.22, 0.60, 0.78, 0.62)
        Events.SerialEventHexHighlight(ToHexFromGrid(Vector2(plot:GetX(), plot:GetY())), true, color)
    end
    local selected = gCandidates[gSelection]
    Controls.Candidate:SetText(tostring(gSelection) .. '/' .. tostring(#gCandidates) .. '  •  ' .. PlotLabel(selected))
    UI.LookAt(selected, 0)
end

local function HidePlacement()
    ClearHighlights()
    gPlacementOpen = false
    Controls.PlacementPanel:SetHide(true)
end

local function ShowPlacement(playerID, cityID)
    if playerID ~= Game.GetActivePlayer() then return end
    if IsOverlayBlocked() then return end
    local player = Players[playerID]
    local city = player and player:GetCityByID(cityID) or nil
    if city == nil then return end
    ClearHighlights()
    gDashboardOpen = false
    Controls.NetworkPanel:SetHide(true)
    gPlayerID = playerID
    gCityID = cityID
    gCandidates = BuildCandidates(playerID, city)
    gSelection = 1
    Controls.Instructions:SetText(Locale.ConvertTextKey(
        'TXT_KEY_GABRIEL_NODE_PANEL_INSTRUCTIONS', city:GetName()))
    gPlacementOpen = true
    Controls.PlacementPanel:SetHide(false)
    RefreshPlacementPanel()
end

local function OnPrevious()
    if #gCandidates == 0 then return end
    gSelection = gSelection - 1
    RefreshPlacementPanel()
end

local function OnNext()
    if #gCandidates == 0 then return end
    gSelection = gSelection + 1
    RefreshPlacementPanel()
end

local function OnPlace()
    local plot = gCandidates[gSelection]
    if plot == nil then return end
    LuaEvents.Gabriel_PlaceNode(gPlayerID, gCityID, plot:GetX(), plot:GetY())
end

local function OnPlacementResult(success, playerID, cityID)
    if playerID ~= gPlayerID or cityID ~= gCityID then return end
    if success then
        HidePlacement()
        gCandidates = {}
        gPlayerID = -1
        gCityID = -1
    else
        local player = Players[playerID]
        local city = player and player:GetCityByID(cityID) or nil
        if city ~= nil then
            gCandidates = BuildCandidates(playerID, city)
            gSelection = 1
            RefreshPlacementPanel()
        else
            HidePlacement()
        end
    end
    if RefreshDashboard ~= nil then RefreshDashboard() end
end

local function HookIcon(index, size, atlas, control)
    local ok, result = pcall(function() return IconHookup(index, size, atlas, control) end)
    control:SetHide(not (ok and result ~= false))
end

local function SetDashboardIcons()
    HookIcon(0, 64, 'GABRIEL_CIV_ATLAS', Controls.NetworkCivIcon)
    HookIcon(2, 64, 'GABRIEL_OBJECT_ATLAS', Controls.NodeCardIcon)
    HookIcon(0, 64, 'GABRIEL_CIV_ATLAS', Controls.CityCardIcon)
    HookIcon(0, 64, 'GABRIEL_OBJECT_ATLAS', Controls.UnitCardIcon)
    HookIcon(1, 64, 'GABRIEL_OBJECT_ATLAS', Controls.NexusIcon)
end

local function BuildNetworkSnapshot(player, playerID)
    local snapshot = {
        activeNodes = 0,
        pillagedNodes = 0,
        coveredUnits = 0,
        militaryUnits = 0,
        readyCities = 0,
        cities = {}
    }

    if IMPROVEMENT_NODE ~= nil then
        -- Read the map as the source of truth.  MapModData can be initialized
        -- before a saved game's improvement state is restored, leaving an
        -- empty cache and incorrectly displaying zero Nodes.
        for index = 0, Map.GetNumPlots() - 1 do
            local plot = Map.GetPlotByIndex(index)
            if plot ~= nil and plot:GetImprovementType() == IMPROVEMENT_NODE
                and NodeOwner(plot) == playerID then
                if IsActiveNodeForPlayer(plot, playerID) then
                    snapshot.activeNodes = snapshot.activeNodes + 1
                else
                    snapshot.pillagedNodes = snapshot.pillagedNodes + 1
                end
            end
        end
    end

    for unit in player:Units() do
        if unit:IsCombatUnit() then
            snapshot.militaryUnits = snapshot.militaryUnits + 1
            if PROMOTION_NETWORK ~= nil and unit:IsHasPromotion(PROMOTION_NETWORK) then
                snapshot.coveredUnits = snapshot.coveredUnits + 1
            end
        end
    end

    local interval = NodeInterval()
    for city in player:Cities() do
        local pending = SavedNumber(CityKey('PENDING', playerID, city), 0) == 1
        local timer = math.max(0, math.min(interval,
            SavedNumber(CityKey('TIMER', playerID, city), 0)))
        if pending then
            timer = interval
            snapshot.readyCities = snapshot.readyCities + 1
        end
        snapshot.cities[#snapshot.cities + 1] = {
            id = city:GetID(),
            name = city:GetName(),
            population = city:GetPopulation(),
            x = city:GetX(),
            y = city:GetY(),
            timer = timer,
            interval = interval,
            pending = pending,
            adjacentNodes = AdjacentNodeCount(city, playerID),
            nexus = HasBuilding(city, BUILDING_NEXUS)
        }
    end
    return snapshot
end

local function FindCityStatus(snapshot, cityID)
    for _, cityStatus in ipairs(snapshot.cities) do
        if cityStatus.id == cityID then return cityStatus end
    end
    return nil
end

local function RebuildCityDropdown(snapshot)
    local selected = FindCityStatus(snapshot, gSelectedCityID)
    if selected == nil and #snapshot.cities > 0 then
        selected = snapshot.cities[1]
        gSelectedCityID = selected.id
    end

    Controls.CityPullDown:ClearEntries()
    gCityDropdownEntries = {}
    for index, cityStatus in ipairs(snapshot.cities) do
        local entry = {}
        Controls.CityPullDown:BuildEntry('InstanceOne', entry)
        local status = cityStatus.pending and 'READY' or (tostring(cityStatus.timer) .. '/' .. tostring(cityStatus.interval))
        entry.Button:SetText(cityStatus.name .. '  •  ' .. tostring(cityStatus.adjacentNodes)
            .. ' Nodes  •  ' .. status)
        entry.Button:SetVoid1(index)
        gCityDropdownEntries[index] = cityStatus.id
    end
    Controls.CityPullDown:CalculateInternals()
    Controls.CityPullDown:GetButton():SetText(selected and selected.name or 'NO COLONY CITIES')
    return selected
end

local function RefreshSelectedCity(cityStatus)
    if cityStatus == nil then
        Controls.CityNameLabel:SetText('No Colony City')
        Controls.CityPopulationLabel:SetText('0 [ICON_CITIZEN]')
        Controls.PreparationStateLabel:SetText('No preparation')
        Controls.PreparationFill:SetSizeX(1)
        Controls.PreparationPercentLabel:SetText('0%')
        Controls.PreparationDetailLabel:SetText('Found a city to begin preparing Colony Nodes.')
        Controls.AdjacentNodesLabel:SetText('0 adjacent Nodes')
        Controls.CityBonusLabel:SetText('+0% Science  •  +0% City Defense')
        Controls.NexusStatusLabel:SetText('Colony Nexus unavailable')
        Controls.SelectedCitySummaryLabel:SetText('No city selected.')
        Controls.ReadyNodeButton:SetHide(true)
        Controls.ViewCityButton:SetDisabled(true)
        return
    end

    Controls.ViewCityButton:SetDisabled(false)
    Controls.CityNameLabel:SetText(cityStatus.name)
    Controls.CityPopulationLabel:SetText(tostring(cityStatus.population) .. ' [ICON_CITIZEN]')
    local percent = math.floor((cityStatus.timer * 100) / math.max(1, cityStatus.interval))
    Controls.PreparationFill:SetSizeX(math.max(1, math.floor(358 * percent / 100)))
    Controls.PreparationPercentLabel:SetText(tostring(percent) .. '%')
    Controls.PreparationStateLabel:SetText(cityStatus.pending
        and '[COLOR_POSITIVE_TEXT]READY[ENDCOLOR]'
        or (tostring(cityStatus.timer) .. ' / ' .. tostring(cityStatus.interval) .. ' turns'))
    if cityStatus.pending then
        Controls.PreparationDetailLabel:SetText(
            'Preparation complete. Choose a legal plot; this city\'s timer is paused until placement.')
    else
        local remaining = math.max(0, cityStatus.interval - cityStatus.timer)
        Controls.PreparationDetailLabel:SetText(
            tostring(remaining) .. (remaining == 1 and ' turn remains before placement.'
                or ' turns remain before placement.'))
    end

    local nodes = cityStatus.adjacentNodes
    Controls.AdjacentNodesLabel:SetText(tostring(nodes)
        .. (nodes == 1 and ' active adjacent Node' or ' active adjacent Nodes'))
    Controls.CityBonusLabel:SetText('+' .. tostring(nodes) .. '% [ICON_RESEARCH] Science  •  +'
        .. tostring(nodes) .. '% City Defense')
    if cityStatus.nexus then
        Controls.NexusStatusLabel:SetText('[COLOR_POSITIVE_TEXT]COLONY NEXUS CONNECTED[ENDCOLOR][NEWLINE]+'
            .. tostring(nodes) .. ' [ICON_RESEARCH] Science from local Nodes; detection network active.')
    else
        Controls.NexusStatusLabel:SetText('Colony Nexus not constructed.[NEWLINE]Build one to convert adjacent Nodes into flat Science and detection coverage.')
    end
    Controls.SelectedCitySummaryLabel:SetText(cityStatus.nexus
        and (cityStatus.name .. ' links ' .. tostring(nodes) .. ' Nodes through its Nexus.')
        or (cityStatus.name .. ' has ' .. tostring(nodes) .. ' local network connections.'))
    Controls.ReadyNodeButton:SetHide(not cityStatus.pending)
end

local function SetDashboardOpen(open)
    local player = ActiveGabrielPlayer()
    gDashboardOpen = open == true and player ~= nil and not IsOverlayBlocked()
    Controls.NetworkPanel:SetHide(not gDashboardOpen)
    if gDashboardOpen then
        HidePlacement()
        SetDashboardIcons()
        if RefreshDashboard ~= nil then RefreshDashboard() end
    end
end

RefreshDashboard = function()
    local player, playerID = ActiveGabrielPlayer()
    if player == nil or IsOverlayBlocked() then
        Controls.NetworkButton:SetHide(true)
        Controls.NetworkPanel:SetHide(true)
        gDashboardOpen = false
        return
    end

    Controls.NetworkButton:SetHide(false)
    local snapshot = BuildNetworkSnapshot(player, playerID)
    local selected = RebuildCityDropdown(snapshot)
    local cityCount = #snapshot.cities
    local preparing = math.max(0, cityCount - snapshot.readyCities)

    Controls.NetworkTurnLabel:SetText('TURN ' .. tostring(Game.GetGameTurn()))
    Controls.NodeCountValue:SetText(tostring(snapshot.activeNodes))
    Controls.NodeCountDetail:SetText(tostring(snapshot.pillagedNodes) .. ' offline or pillaged')
    Controls.ReadyCountValue:SetText(tostring(snapshot.readyCities))
    Controls.ReadyCountDetail:SetText(tostring(preparing) .. ' preparing')
    Controls.CoveredCountValue:SetText(tostring(snapshot.coveredUnits))
    Controls.CoveredCountDetail:SetText(tostring(snapshot.militaryUnits) .. ' total military')

    local state = 'NETWORK FORMING'
    if snapshot.readyCities > 0 then
        state = '[COLOR_POSITIVE_TEXT]PLACEMENT READY[ENDCOLOR]'
    elseif snapshot.activeNodes >= math.max(1, cityCount) then
        state = '[COLOR_CYAN]NETWORK MATURE[ENDCOLOR]'
    elseif snapshot.activeNodes > 0 then
        state = 'NETWORK EXPANDING'
    end
    Controls.EmpireStateLabel:SetText(state)
    Controls.NetworkButtonLabel:SetText('[ICON_RESEARCH] COLONY NETWORK  •  '
        .. tostring(snapshot.activeNodes) .. ' NODES')
    Controls.NetworkButton:SetToolTipString('COLONY NETWORK[NEWLINE]'
        .. tostring(snapshot.activeNodes) .. ' active Nodes[NEWLINE]'
        .. tostring(snapshot.readyCities) .. ' cities ready to place[NEWLINE]'
        .. tostring(snapshot.coveredUnits) .. ' of ' .. tostring(snapshot.militaryUnits)
        .. ' military units covered[NEWLINE][NEWLINE]Click to inspect the network.')
    Controls.NetworkFooterLabel:SetText(snapshot.pillagedNodes > 0
        and ('[COLOR_WARNING_TEXT]' .. tostring(snapshot.pillagedNodes)
            .. ' Node links are offline. Repair or reclaim them to restore effects.[ENDCOLOR]')
        or 'Pillaged Nodes provide no network effects. Coverage bonuses never stack.')
    RefreshSelectedCity(selected)
end

local function OnViewCity()
    local player = ActiveGabrielPlayer()
    if player == nil or gSelectedCityID == nil then return end
    local city = player:GetCityByID(gSelectedCityID)
    if city ~= nil then UI.LookAt(city:Plot(), 0) end
end

local function OnPlaceReadyNode()
    local player, playerID = ActiveGabrielPlayer()
    if player == nil or gSelectedCityID == nil then return end
    local city = player:GetCityByID(gSelectedCityID)
    if city == nil or SavedNumber(CityKey('PENDING', playerID, city), 0) ~= 1 then return end
    ShowPlacement(playerID, city:GetID())
end

local function InputHandler(uiMsg, wParam)
    if uiMsg == KeyEvents.KeyDown and wParam == Keys.VK_ESCAPE then
        if gPlacementOpen then
            HidePlacement()
            return true
        elseif gDashboardOpen then
            SetDashboardOpen(false)
            return true
        end
    end
    return false
end

Controls.PreviousButton:RegisterCallback(Mouse.eLClick, OnPrevious)
Controls.NextButton:RegisterCallback(Mouse.eLClick, OnNext)
Controls.PlaceButton:RegisterCallback(Mouse.eLClick, OnPlace)
Controls.LaterButton:RegisterCallback(Mouse.eLClick, HidePlacement)
Controls.NetworkButton:RegisterCallback(Mouse.eLClick, function()
    SetDashboardOpen(not gDashboardOpen)
end)
Controls.CloseButton:RegisterCallback(Mouse.eLClick, function()
    SetDashboardOpen(false)
end)
Controls.RefreshButton:RegisterCallback(Mouse.eLClick, function()
    if RefreshDashboard ~= nil then RefreshDashboard() end
end)
Controls.ViewCityButton:RegisterCallback(Mouse.eLClick, OnViewCity)
Controls.ReadyNodeButton:RegisterCallback(Mouse.eLClick, OnPlaceReadyNode)
Controls.CityPullDown:RegisterSelectionCallback(function(index)
    if gCityDropdownEntries[index] ~= nil then
        gSelectedCityID = gCityDropdownEntries[index]
        if RefreshDashboard ~= nil then RefreshDashboard() end
    end
end)
ContextPtr:SetInputHandler(InputHandler)

LuaEvents.Gabriel_NodePlacementAvailable.Add(ShowPlacement)
LuaEvents.Gabriel_NodePlacementResult.Add(OnPlacementResult)

local function HideOverlayForScreen()
    HidePlacement()
    gDashboardOpen = false
    Controls.NetworkPanel:SetHide(true)
    Controls.NetworkButton:SetHide(true)
end

local function IsCityStatePopup(popupType)
    return popupType ~= nil and (
        popupType == ButtonPopupTypes.BUTTONPOPUP_CITY_STATE_DIPLO
        or popupType == ButtonPopupTypes.BUTTONPOPUP_CITY_STATE_MESSAGE
        or popupType == ButtonPopupTypes.BUTTONPOPUP_CITY_STATE_GREETING)
end

if Events.SerialEventGameMessagePopupShown ~= nil then
    Events.SerialEventGameMessagePopupShown.Add(function(info)
        if info ~= nil and IsCityStatePopup(info.Type) then
            gDiplomacyPopups[info.Type] = true
            HideOverlayForScreen()
        end
    end)
end
if Events.SerialEventGameMessagePopupProcessed ~= nil then
    Events.SerialEventGameMessagePopupProcessed.Add(function(popupType)
        if IsCityStatePopup(popupType) then
            gDiplomacyPopups[popupType] = nil
            RefreshDashboard()
        end
    end)
end

if Events.SerialEventEnterCityScreen ~= nil then
    Events.SerialEventEnterCityScreen.Add(function()
        gCityScreenOpen = true
        HideOverlayForScreen()
    end)
end
if Events.SerialEventExitCityScreen ~= nil then
    Events.SerialEventExitCityScreen.Add(function()
        gCityScreenOpen = false
        if RefreshDashboard ~= nil then RefreshDashboard() end
    end)
end
if Events.AILeaderMessage ~= nil then
    Events.AILeaderMessage.Add(function()
        gDiplomacyOpen = true
        HideOverlayForScreen()
    end)
end
if Events.LeavingLeaderViewMode ~= nil then
    Events.LeavingLeaderViewMode.Add(function()
        gDiplomacyOpen = false
        if RefreshDashboard ~= nil then RefreshDashboard() end
    end)
end

if Events.ActivePlayerTurnStart ~= nil then
    Events.ActivePlayerTurnStart.Add(function()
        if RefreshDashboard ~= nil then RefreshDashboard() end
    end)
end
if Events.SerialEventGameDataDirty ~= nil then
    Events.SerialEventGameDataDirty.Add(function()
        if gDashboardOpen and RefreshDashboard ~= nil then RefreshDashboard() end
    end)
end
Events.GameplaySetActivePlayer.Add(function()
    HidePlacement()
    gSelectedCityID = nil
    SetDashboardOpen(false)
    if RefreshDashboard ~= nil then RefreshDashboard() end
end)

SetDashboardIcons()
RefreshDashboard()
