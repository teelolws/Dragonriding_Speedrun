local addonName, addon = ...

local libEME = LibStub:GetLibrary("EditModeExpanded-1.0")

addon.eventListener = CreateFrame("Frame")
local currentQuest

function addon.questAcceptedHandler(...)
    local questID = ...
    for _, v in pairs(addon.questIDs) do
        if questID == v then
            currentQuest = questID
            addon.startTimers()
            addon.eventListener:RegisterEvent("DISPLAY_EVENT_TOASTS")
            addon.findVertices()
            addon.CountdownLabel:Show()
            return
        end
    end
end

function addon.questRemovedHandler(...)
    local questID = ...
    if currentQuest ~= questID then return end
    addon.CountdownLabel:Hide()
    
    C_Timer.After(2, function()
        addon.eventListener:UnregisterEvent("DISPLAY_EVENT_TOASTS")
        addon.stopTimers()
    end)
end

function addon.displayEventToastHandler()
    local toastInfo = C_EventToastManager.GetNextToastToDisplay()
    if toastInfo.displayType ~= 6 then return end
    
    local text = toastInfo.subtitle
    local raceTime = text:match("Race Time: (%d+%.%d+) seconds")
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
    addon.findVertices()
end

addon.eventListener:RegisterEvent("QUEST_ACCEPTED")
addon.eventListener:RegisterEvent("QUEST_REMOVED")
addon.eventListener:RegisterEvent("ADDON_LOADED")
addon.eventListener:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")

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
    local x, y, z, instanceID = UnitPosition("player")
    startTime = GetTime()
    
    currentRaceData = {}
    table.insert(currentRaceData, {
        ["time"] = 0,
        ["x"] = x,
        ["y"] = y,
    })
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

local currentVertices = {}
local nextVertexNum
local currentVerticesTimes = {}

local NUM_VERTICES = 6

function addon.findVertices()
    wipe(currentVertices)
    nextVertexNum = 1
    wipe(currentVerticesTimes)
    
    local data = DragonridingSpeedrunDB[currentQuest]
    
    if data == nil then return end
    
    local numNodes = #data.nodes
    for i = 1, NUM_VERTICES do
        local num = math.floor((numNodes / 6) * i)
        table.insert(currentVertices, data.nodes[num])
    end
    table.insert(currentVertices, data.nodes[numNodes])
end

addon.CountdownLabel = CreateFrame("Frame", "DragonridingSpeedrunLabel", UIParent)
addon.CountdownLabel:SetPoint("LEFT", UIParent, "LEFT")
addon.CountdownLabel:SetSize(80, 50)

addon.CountdownLabel.Text = addon.CountdownLabel:CreateFontString(nil, "OVERLAY", "GameTooltipText")
addon.CountdownLabel.Text:SetPoint("CENTER")
addon.CountdownLabel.Text:SetJustifyH("LEFT")
addon.CountdownLabel:Hide()

local RADIUS_PERMITTED = 30

addon.CountdownLabel:SetScript("OnUpdate", function()
    if EditModeManagerFrame.editModeActive then return end  
    addon.CountdownLabel.Text:SetText("")
    if not currentQuest then return end
    if #currentVertices == 0 then return end
    
    local x, y, z, instanceID = UnitPosition("player")
    if instanceID ~= currentInstanceID then return end
    
    local elapsedTime = GetTime() - startTime
    local output = ""
    
    for i = 1, NUM_VERTICES do
        local vertex = currentVertices[i]
        if i < nextVertexNum then
            local timeDiff = vertex.time - currentVerticesTimes[i]
            timeDiff = math.floor(timeDiff*100)/100
            if timeDiff < 0 then
                output = output.."|cFFFF0000"..timeDiff.."|r\n"
            else
                output = output.."|c00008000"..timeDiff.."|r\n"
            end
        elseif i == nextVertexNum then
            local timeDiff = vertex.time - elapsedTime
            timeDiff = math.floor(timeDiff*100)/100
            if timeDiff < 0 then
                output = output.."|cFFFF0000"..timeDiff.."|r\n"
            else
                output = output..timeDiff.."\n"
            end
        else
            local time = vertex.time
            time = math.floor(time*100)/100
            output = output.."|c00808080"..time.."|r\n"
        end
    end
    addon.CountdownLabel.Text:SetText(output)
    
    local nextVertex = currentVertices[nextVertexNum]
    if not nextVertex then return end
    local diffX, diffY = x - nextVertex.x, y - nextVertex.y 
    if (diffX < RADIUS_PERMITTED) and (diffX > (-1 * RADIUS_PERMITTED)) then
        if (diffY < RADIUS_PERMITTED) and (diffY > (-1 * RADIUS_PERMITTED)) then
            currentVerticesTimes[nextVertexNum] = elapsedTime
            nextVertexNum = nextVertexNum + 1
        end
    end
end)

hooksecurefunc(EditModeManagerFrame, "EnterEditMode", function()
    addon.CountdownLabel.Text:SetText("123.45\n|cFFFF0000-123.45\n123.45\n|r|c00008000123.45|r")
end)
