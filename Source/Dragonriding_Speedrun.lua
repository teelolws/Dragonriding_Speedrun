local addonName, addon = ...

local libEME = LibStub:GetLibrary("EditModeExpanded-1.0")

addon.eventListener = CreateFrame("Frame")
local currentQuest

function addon.questAcceptedHandler(...)
    local questID = ...
    for _, v in pairs(addon.questIDs) do
        if questID == v then
            currentQuest = questID
            addon.eventListener:RegisterEvent("UNIT_AURA")
            addon.findVertices(currentQuest)
            addon.CountdownLabel:Show()
            return
        end
    end
end

local currentRaceStartAuraInstanceID

function addon.questRemovedHandler(...)
    local questID = ...
    if currentQuest ~= questID then return end
    addon.CountdownLabel:Hide()
    currentRaceStartAuraInstanceID = nil
    
    C_Timer.After(2, function()
        addon.eventListener:UnregisterEvent("DISPLAY_EVENT_TOASTS")
        addon.stopTimers()
    end)
end

function addon.unitAuraHandler(...)
    local unitID, updateInfo = ...
    if unitID ~= "player" then return end
    
    if currentRaceStartAuraInstanceID then
        if not updateInfo.removedAuraInstanceIDs then
            return
        end
        if not currentQuest then
            return
        end
        for _, removedAuraInstanceID in pairs(updateInfo.removedAuraInstanceIDs) do
            if removedAuraInstanceID == currentRaceStartAuraInstanceID then
                addon.startTimers()
                addon.eventListener:RegisterEvent("DISPLAY_EVENT_TOASTS")
                currentRaceStartAuraInstanceID = nil
                return
            end
        end
        return
    end
    
    if updateInfo.addedAuras then
        for _, addedAuraData in pairs(updateInfo.addedAuras) do
            if addon.raceStartingSpellIDs[addedAuraData.spellId] then
                currentRaceStartAuraInstanceID = addedAuraData.auraInstanceID
                return
            end
        end
    end
end

function addon.displayEventToastHandler()
    local toastInfo = C_EventToastManager.GetNextToastToDisplay()
    if toastInfo.displayType ~= 6 then return end
    
    local text = toastInfo.subtitle
    local raceTime = text:match(addon.raceTimePattern[GetLocale()])
    if not raceTime then return end
    
    raceTime = tonumber(raceTime)
    addon.eventListener:UnregisterEvent("DISPLAY_EVENT_TOASTS")
    addon.processEndOfRace(raceTime)
end

function addon.unitSpellcastSucceededHandler(...)
    local unitID, guid, spellID = ...
    if unitID ~= "player" then return end
    if spellID ~= 370007 then return end
    
    addon.resetTimers()
    addon.findVertices(currentQuest)
end

addon.eventListener:RegisterEvent("QUEST_ACCEPTED")
addon.eventListener:RegisterEvent("QUEST_REMOVED")
addon.eventListener:RegisterEvent("ADDON_LOADED")
addon.eventListener:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
addon.eventListener:RegisterEvent("UNIT_AURA")

addon.eventListener:SetScript("OnEvent", function(self, event, ...)
    if event == "QUEST_ACCEPTED" then
        addon.questAcceptedHandler(...)
    elseif event == "QUEST_REMOVED" then
        addon.questRemovedHandler(...)
    elseif event == "ADDON_LOADED" then
        addon.addonLoadedHandler(...)
    elseif event == "DISPLAY_EVENT_TOASTS" then
        addon.displayEventToastHandler(...)
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        addon.unitSpellcastSucceededHandler(...)
    elseif event == "UNIT_AURA" then
        addon.unitAuraHandler(...)
    end
end)

local currentInstanceID
local startTime
local ticker
local currentRaceData = {}

function addon.startTimers()
    local x, y, z, instanceID = UnitPosition("player")
    currentInstanceID = instanceID
    startTime = GetTime()
    
    currentRaceData = {}
    table.insert(currentRaceData, {
        ["time"] = 0,
        ["x"] = x,
        ["y"] = y,
    })
    
    if ticker then
        ticker:Cancel()
    end
    
    ticker = C_Timer.NewTicker(0.1, addon.ticker)
end

function addon.resetTimers()
    addon.stopTimers()
end

--
-- Structure format:
-- {
--   [questID] = {
--      [nodes] = {
--        [primary key] = {
--           time = number (float),
--           x = number,
--           y = number,
--        }
--      }
--      bestTime = number,
--   }
-- }
--
addon.raceData = {}

function addon.ticker()
    local x, y, z, instanceID = UnitPosition("player")
    
    if instanceID ~= currentInstanceID then
        addon.stopTimers()
        return
    end
    
    if (currentRaceData[#currentRaceData].x == x) and (currentRaceData[#currentRaceData].y == y) then
        return
    end
    
    local elapsedTime = GetTime() - startTime    
    
    local data = {}
    data.time = elapsedTime
    data.x = x
    data.y = y
    
    table.insert(currentRaceData, data)
end

function addon.stopTimers()
    currentInstanceID = nil
    if ticker then
        ticker:Cancel()
    end
end

function addon.addonLoadedHandler(...)
    local name = ...
    if name ~= addonName then return end
    
    addon.eventListener:UnregisterEvent("ADDON_LOADED")
    
    if not DragonridingSpeedrunDB then
        DragonridingSpeedrunDB = {}
    end
    
    if not DragonridingSpeedrunUI then
        DragonridingSpeedrunUI = {}
    end
    
    libEME:RegisterFrame(addon.CountdownLabel, "Dragonriding Speedrun", DragonridingSpeedrunUI)
    libEME:RegisterResizable(addon.CountdownLabel)
end

function addon.processEndOfRace(raceTime)
    if not DragonridingSpeedrunDB[currentQuest] then
        DragonridingSpeedrunDB[currentQuest] = {}
    end
    
    if DragonridingSpeedrunDB[currentQuest].bestTime and (DragonridingSpeedrunDB[currentQuest].bestTime < raceTime) then
        return
    end
    
    DragonridingSpeedrunDB[currentQuest].bestTime = raceTime
    DragonridingSpeedrunDB[currentQuest].nodes = currentRaceData
end

addon.CountdownLabel = CreateFrame("Frame", "DragonridingSpeedrunLabel", UIParent)
addon.CountdownLabel:SetPoint("LEFT", UIParent, "LEFT")
addon.CountdownLabel:SetSize(80, 50)

addon.CountdownLabel.Text = addon.CountdownLabel:CreateFontString(nil, "OVERLAY", "GameTooltipText")
addon.CountdownLabel.Text:SetPoint("CENTER")
addon.CountdownLabel.Text:SetJustifyH("LEFT")
addon.CountdownLabel:Hide()

local RADIUS_PERMITTED = 10

addon.CountdownLabel:SetScript("OnUpdate", function()
    if EditModeManagerFrame.editModeActive then return end  
    addon.CountdownLabel.Text:SetText("")
    if not currentQuest then return end
    if #addon.currentVertices == 0 then return end
    
    local x, y, z, instanceID = UnitPosition("player")
    if instanceID ~= currentInstanceID then return end
    if not x then return end
    
    local elapsedTime = GetTime() - startTime
    local output = ""
    local currentVertex
    
    for i = 1, #addon.currentVertices do
        local vertex = addon.currentVertices[i]
        if i < addon.nextVertexNum then
            local timeDiff = vertex.time - addon.currentVerticesTimes[i]
            timeDiff = math.floor(timeDiff*100)/100
            if timeDiff < 0 then
                output = output.."|cFFFF0000"..timeDiff.."|r\n"
            else
                output = output.."|c00008000"..timeDiff.."|r\n"
            end
        elseif i == addon.nextVertexNum then
            local timeDiff = vertex.time - elapsedTime
            currentVertex = vertex
            timeDiff = math.floor(timeDiff*100)/100
            if timeDiff < 0 then
                output = output.."|cFFFF0000"..timeDiff.."|r\n"
            else
                output = output..timeDiff.."\n"
            end
        else
            local time = vertex.time
            time = time - currentVertex.time
            time = math.floor(time*100)/100
            output = output.."|c00808080"..time.."|r\n"
        end
    end
    addon.CountdownLabel.Text:SetText(output)
    
    local nextVertex = addon.currentVertices[addon.nextVertexNum]
    if not nextVertex then return end
    local diffX, diffY = x - nextVertex.x, y - nextVertex.y 
    if (diffX < RADIUS_PERMITTED) and (diffX > (-1 * RADIUS_PERMITTED)) then
        if (diffY < RADIUS_PERMITTED) and (diffY > (-1 * RADIUS_PERMITTED)) then
            addon.currentVerticesTimes[addon.nextVertexNum] = elapsedTime
            addon.nextVertexNum = addon.nextVertexNum + 1
        end
    end
end)

hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
    addon.CountdownLabel.Text:SetText("123.45\n|cFFFF0000-123.45\n123.45\n|r|c00008000123.45|r\n|c0080808012.34\n12.34\n12.34\n12.34\n12.34\n12.34\n|r")
end)
