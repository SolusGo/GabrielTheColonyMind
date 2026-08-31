-- Human Colony Node selection panel. Gameplay revalidates every request.

local gPlayerID = -1
local gCityID = -1
local gCandidates = {}
local gSelection = 1

local function PlotIndex(plot)
    return plot:GetPlotIndex()
end

local function ClearHighlights()
    for _, plot in ipairs(gCandidates) do
        Events.SerialEventHexHighlight(ToHexFromGrid(Vector2(plot:GetX(), plot:GetY())), false)
    end
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

local function PlotLabel(plot)
    if plot == nil then return '' end
    local terrain = GameInfo.Terrains[plot:GetTerrainType()]
    local terrainName = terrain and Locale.ConvertTextKey(terrain.Description) or Locale.ConvertTextKey('TXT_KEY_MISC_UNKNOWN')
    local ownerText = plot:GetOwner() == -1
        and Locale.ConvertTextKey('TXT_KEY_GABRIEL_NODE_UNOWNED')
        or Locale.ConvertTextKey('TXT_KEY_GABRIEL_NODE_OWNED')
    return string.format('%s — (%d, %d) — %s', terrainName, plot:GetX(), plot:GetY(), ownerText)
end

local function RefreshPanel()
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
        local color = i == gSelection and Vector4(1.0, 0.72, 0.18, 1.0) or Vector4(0.72, 0.42, 0.08, 0.65)
        Events.SerialEventHexHighlight(ToHexFromGrid(Vector2(plot:GetX(), plot:GetY())), true, color)
    end
    local selected = gCandidates[gSelection]
    Controls.Candidate:SetText(tostring(gSelection) .. '/' .. tostring(#gCandidates) .. ': ' .. PlotLabel(selected))
    UI.LookAt(selected, 0)
end

local function HidePanel()
    ClearHighlights()
    ContextPtr:SetHide(true)
end

local function ShowPlacement(playerID, cityID)
    if playerID ~= Game.GetActivePlayer() then return end
    local player = Players[playerID]
    local city = player and player:GetCityByID(cityID) or nil
    if city == nil then return end
    ClearHighlights()
    gPlayerID = playerID
    gCityID = cityID
    gCandidates = BuildCandidates(playerID, city)
    gSelection = 1
    Controls.Instructions:SetText(Locale.ConvertTextKey('TXT_KEY_GABRIEL_NODE_PANEL_INSTRUCTIONS', city:GetName()))
    ContextPtr:SetHide(false)
    RefreshPanel()
end

local function OnPrevious()
    if #gCandidates == 0 then return end
    gSelection = gSelection - 1
    RefreshPanel()
end

local function OnNext()
    if #gCandidates == 0 then return end
    gSelection = gSelection + 1
    RefreshPanel()
end

local function OnPlace()
    local plot = gCandidates[gSelection]
    if plot == nil then return end
    LuaEvents.Gabriel_PlaceNode(gPlayerID, gCityID, plot:GetX(), plot:GetY())
end

local function OnPlacementResult(success, playerID, cityID)
    if playerID ~= gPlayerID or cityID ~= gCityID then return end
    if success then
        HidePanel()
        gCandidates = {}
        gPlayerID = -1
        gCityID = -1
    else
        local player = Players[playerID]
        local city = player and player:GetCityByID(cityID) or nil
        if city ~= nil then
            gCandidates = BuildCandidates(playerID, city)
            gSelection = 1
            RefreshPanel()
        else
            HidePanel()
        end
    end
end

local function InputHandler(uiMsg, wParam)
    if uiMsg == KeyEvents.KeyDown and wParam == Keys.VK_ESCAPE then
        HidePanel()
        return true
    end
    return false
end

Controls.PreviousButton:RegisterCallback(Mouse.eLClick, OnPrevious)
Controls.NextButton:RegisterCallback(Mouse.eLClick, OnNext)
Controls.PlaceButton:RegisterCallback(Mouse.eLClick, OnPlace)
Controls.LaterButton:RegisterCallback(Mouse.eLClick, HidePanel)
ContextPtr:SetInputHandler(InputHandler)

LuaEvents.Gabriel_NodePlacementAvailable.Add(ShowPlacement)
LuaEvents.Gabriel_NodePlacementResult.Add(OnPlacementResult)
Events.GameplaySetActivePlayer.Add(HidePanel)
