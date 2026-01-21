local addonName, addon = ...

local libEME = LibStub:GetLibrary("EditModeExpanded-1.0")

addon.eventListener = CreateFrame("Frame")
addon.isMirrorQuest = nil
addon.currentQuest = nil

function addon.questAcceptedHandler(...)
    local questID = ...
    for _, v in pairs(addon.questIDs) do
        if questID == v then
            addon.currentQuest = questID
            
            local text, objectiveType, finished, fulfilled, required = GetQuestObjectiveInfo(questID, 1, false)
            if (objectiveType == "monster") and (finished == false) and (fulfilled == 0) and (required == 9) then
                addon:handleMirrorQuest(questID)
            end
            
            addon.eventListener:RegisterEvent("UNIT_AURA")
            addon.findVertices()
            addon.CountdownLabel:Show()
            return
        end
    end
end

local currentRaceStartAuraInstanceID

function addon.questRemovedHandler(...)
    local questID = ...
    if addon.currentQuest ~= questID then return end
    addon.CountdownLabel:Hide()
    currentRaceStartAuraInstanceID = nil
    addon.isMirrorQuest = nil
    addon.eventListener:UnregisterEvent("QUEST_WATCH_UPDATE")
    
    C_Timer.After(2, function()
        addon.eventListener:UnregisterEvent("DISPLAY_EVENT_TOASTS")
        addon.stopTimers()
    end)
end

function addon.unitAuraHandler(...)
    if InCombatLockdown() then return end
    local unitID, updateInfo = ...
    if unitID ~= "player" then return end
    
    if currentRaceStartAuraInstanceID then
        if not updateInfo.removedAuraInstanceIDs then
            return
        end
        if not addon.currentQuest then
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
    addon.eventListener:UnregisterEvent("QUEST_WATCH_UPDATE")
    
    addon.isMirrorQuest = nil
    
    addon.processEndOfRace(raceTime)
end

function addon.unitSpellcastSucceededHandler(...)
    local unitID, guid, spellID = ...
    if unitID ~= "player" then return end
    if spellID ~= 370007 then return end
    
    addon.resetTimers()
    addon.findVertices()
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
    elseif event == "QUEST_WATCH_UPDATE" then
        addon.questWatchUpdateHandler(...)
    end
end)

local currentInstanceID
local startTime
local ticker
local currentRaceData = {}

function addon.startTimers()
    currentRaceData = {}
    startTime = GetTime()
    
    local x, y, z, instanceID = UnitPosition("player")
    currentInstanceID = instanceID
    
    if addon.isMirrorQuest then return end
    
    table.insert(currentRaceData, {
        ["time"] = 0,
        ["x"] = x,
        ["y"] = y,
    })
    
    if ticker then
        ticker:Cancel()
    end
    
    ticker = C_Timer.NewTicker(1/addon.options.global.detectionFrequency, addon.ticker)
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
    if addon.isMirrorQuest then return end
    
    local x, y, z, instanceID = UnitPosition("player")
    
    if instanceID ~= currentInstanceID then
        addon.stopTimers()
        return
    end
    
    if (currentRaceData[#currentRaceData].x == x) and (currentRaceData[#currentRaceData].y == y) then
        return
    end
    
    if addon.coordinates[addon.currentQuest] then
        local data = addon.coordinates[addon.currentQuest]
        if type(data) == "number" then
            data = addon.coordinates[data]
        end
        
        local needed = false
        
        for index, node in ipairs(data) do
            if (math.abs(node.x - x) < addon.options.global.radiusPermitted) and (math.abs(node.y - y) < addon.options.global.radiusPermitted) then
                needed = true
                break
            end
        end
        
        if not needed then return end
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
    
    addon.loadDatamining()
end

function addon.processEndOfRace(raceTime)
    local currentQuest = addon.currentQuest
    addon.currentQuest = nil
    
    if not DragonridingSpeedrunDB[currentQuest] then
        DragonridingSpeedrunDB[currentQuest] = {}
    end
    
    if DragonridingSpeedrunDB[currentQuest].bestTime and (DragonridingSpeedrunDB[currentQuest].bestTime < raceTime) then
        return
    end
    
    local x, y, z, instanceID = UnitPosition("player")
    local elapsedTime = GetTime() - startTime
    
    local data = {}
    data.time = elapsedTime
    data.x = x
    data.y = y
    
    table.insert(currentRaceData, data)
    
    DragonridingSpeedrunDB[currentQuest].bestTime = raceTime
    
    for _, node in ipairs(currentRaceData) do
        node.x = math.floor(node.x*1000)/1000
        node.y = math.floor(node.y*1000)/1000
        node.time = math.floor(node.time*1000)/1000
    end
    
    DragonridingSpeedrunDB[currentQuest].nodes = currentRaceData
end

addon.CountdownLabel = CreateFrame("Frame", "DragonridingSpeedrunLabel", UIParent)
addon.CountdownLabel:SetPoint("LEFT", UIParent, "LEFT")
addon.CountdownLabel:SetSize(80, 50)

addon.CountdownLabel.Text = addon.CountdownLabel:CreateFontString(nil, "OVERLAY", "GameTooltipText")
addon.CountdownLabel.Text:SetPoint("CENTER")
addon.CountdownLabel.Text:SetJustifyH("LEFT")
addon.CountdownLabel:Hide()

addon.CountdownLabel:SetScript("OnUpdate", function()
    if EditModeManagerFrame.editModeActive then return end  
    addon.CountdownLabel.Text:SetText("")
    if not addon.currentQuest then return end
    if #addon.currentVertices == 0 then return end
    
    local x, y, z, instanceID = UnitPosition("player")
    if instanceID ~= currentInstanceID then return end
    if not x then return end
    
    local elapsedTime = GetTime() - startTime
    local output = ""
    local currentVertex
    
    local initialVertexNum = addon.nextVertexNum - addon.options.global.maxLinesBeforeAfter
    if initialVertexNum < 1 then
        initialVertexNum = 1
    end
    
    local maxVertexNum = addon.nextVertexNum + addon.options.global.maxLinesBeforeAfter
    if maxVertexNum > #addon.currentVertices then
        maxVertexNum = #addon.currentVertices
    end 
    
    for i = initialVertexNum, maxVertexNum do
        local vertex = addon.currentVertices[i]
        local precision = 10^addon.options.global.precision
        if i < addon.nextVertexNum then
            if vertex.time then
                local timeDiff = vertex.time - addon.currentVerticesTimes[i]
                timeDiff = math.floor(timeDiff*precision)/precision
                if timeDiff < 0 then
                    output = output.."|cFFFF0000"..timeDiff.."|r\n"
                else
                    output = output.."|c00008000"..timeDiff.."|r\n"
                end
            end
        elseif i == addon.nextVertexNum then
            currentVertex = vertex
            if vertex.time then
                local timeDiff = vertex.time - elapsedTime
                timeDiff = math.floor(timeDiff*precision)/precision
                if timeDiff < 0 then
                    output = output.."|cFFFF0000"..timeDiff.."|r\n"
                else
                    output = output..timeDiff.."\n"
                end
            end
        else
            if vertex.time and currentVertex.time then
                local time = vertex.time - currentVertex.time
                time = math.floor(time*precision)/precision
                output = output.."|c00808080"..time.."|r\n"
            end
        end
    end
    addon.CountdownLabel.Text:SetText(output)
    
    if addon.isMirrorQuest then return end
    
    local nextVertex = addon.currentVertices[addon.nextVertexNum]
    if not nextVertex then return end
    local diffX, diffY = x - nextVertex.x, y - nextVertex.y
    local radiusPermitted = addon.options.global.radiusPermitted
    if (diffX < radiusPermitted) and (diffX > (-1 * radiusPermitted)) then
        if (diffY < radiusPermitted) and (diffY > (-1 * radiusPermitted)) then
            addon.currentVerticesTimes[addon.nextVertexNum] = elapsedTime
            addon.nextVertexNum = addon.nextVertexNum + 1
        end
    end
    
    if DragonridingSpeedrunDB.datamining then
        diffX = math.floor(diffX)
        diffY = math.floor(diffY)
        if diffX < radiusPermitted and diffX > (-1 * radiusPermitted) then
            diffX = "|cFFFF0000"..diffX
        end
        if diffY < radiusPermitted and diffY > (-1 * radiusPermitted) then
            diffY = "|cFFFF0000"..diffY
        end
        DragonridingSpeedrunDebuggingFrame.Text:SetText(diffX..", "..diffY..": ("..radiusPermitted..")")
    end
end)

hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
    addon.CountdownLabel.Text:SetText("123.45\n|cFFFF0000-123.45\n123.45\n|r|c00008000123.45|r\n|c0080808012.34\n12.34\n12.34\n12.34\n12.34\n12.34\n|r")
end)

-- These use a different algorithm to handle races that explicitly show a counter for "number of rings" in the quest objective
-- These races are ones that don't follow a set path, so instead use the quest objective to track whether the player has flown through each ring
function addon:handleMirrorQuest(questID)
    -- QUEST_WATCH_UPDATE is triggered when player flies through ring on these quests
    
    addon.eventListener:RegisterEvent("QUEST_WATCH_UPDATE")
    addon.isMirrorQuest = true
end

function addon.questWatchUpdateHandler(...)
    local questID = ...
    
    if not addon.isMirrorQuest then return end
    
    if questID ~= addon.currentQuest then return end
    
    local x, y, z, instanceID = UnitPosition("player")
    
    local elapsedTime = GetTime() - startTime
    
    local data = {}
    data.time = elapsedTime
    data.x = x
    data.y = y
    
    table.insert(currentRaceData, data)
    
    addon.currentVerticesTimes[addon.nextVertexNum] = elapsedTime
    addon.nextVertexNum = addon.nextVertexNum + 1
end
