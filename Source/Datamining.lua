local addonName, addon = ...

function addon.loadDatamining()
    if not DragonridingSpeedrunDB.datamining then return end
    
    local frame = CreateFrame("Button", "DragonridingSpeedrunDataminingButton")
    frame:SetSize(35, 35)
    frame:SetPoint("CENTER", 0, -200)
    local tex = frame:CreateTexture(nil, "BACKGROUND")
    
    tex:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	tex:SetSize(24, 24)
	tex:SetAllPoints()
	frame:SetNormalTexture(tex)
    frame:RegisterForClicks("AnyUp")
    
    frame:SetScript("OnClick", function(self, button, down)
        if not addon.currentQuest then return end
        
        if not DragonridingSpeedrunDatamining then
            DragonridingSpeedrunDatamining = {}
        end
        
        if not DragonridingSpeedrunDatamining[addon.currentQuest] then
            DragonridingSpeedrunDatamining[addon.currentQuest] = {}
        end
        
        if button == "RightButton" then
            wipe(DragonridingSpeedrunDatamining[addon.currentQuest])
            print("Wiped questID", addon.currentQuest)
            return
        end
        
        local x, y = UnitPosition("player")
        table.insert(DragonridingSpeedrunDatamining[addon.currentQuest], {["x"] = x, ["y"] = y})
        print("Saved", x, ",", y)
    end)
end

function DragonridingSpeedrunCleanupMemory()
    if not DragonridingSpeedrunDB.datamining then return end
    
    for questID, data in pairs(addon.coordinates) do
        addon.currentQuest = questID
        addon.findVertices()
    end
    
    addon.currentQuest = nil
end
