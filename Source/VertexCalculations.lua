local addonName, addon = ...

addon.currentVertices = {}
addon.nextVertexNum = 1
addon.currentVerticesTimes = {}

local CHANGE_THRESHOLD = math.pi/8

local function useSavedCoordinates(data)
    local k = 1
    
    -- node is the stored list of coordinates known to be waypoints
    -- node2 is the players attempt at reaching that waypoint
    -- this will cut down the amount of data needed to be stored
    -- we can just store the relevant nodes instead of every 0.1s from the previous algorithm
    local node2s = {}
    
    for index, node in ipairs(data) do
        node = CopyTable(node)
        
        if DragonridingSpeedrunDB[addon.currentQuest].nodes then
            for j = k, #DragonridingSpeedrunDB[addon.currentQuest].nodes do
                local node2 = DragonridingSpeedrunDB[addon.currentQuest].nodes[j]
                
                if (math.abs(node.x - node2.x) < addon.options.global.radiusPermitted) and (math.abs(node.y - node2.y) < addon.options.global.radiusPermitted) then
                    node.time = node2.time
                    k = j
                    table.insert(node2s, node2)
                    break
                end
            end
        end
            
        table.insert(addon.currentVertices, node)
    end
    
    if DragonridingSpeedrunDB[addon.currentQuest].nodes and (#node2s > 2) and (#node2s ~= #DragonridingSpeedrunDB[addon.currentQuest].nodes) and (#node2s == #addon.currentVertices) then
        DragonridingSpeedrunDB[addon.currentQuest].nodes = node2s
    end
end

function addon.findVertices()
    wipe(addon.currentVertices)
    addon.nextVertexNum = 1
    wipe(addon.currentVerticesTimes)
    
    local data = DragonridingSpeedrunDB[addon.currentQuest]
    
    if data == nil then return end
    
    if addon.isMirrorQuest then
        addon.findMirrorVertices()
        return
    end
    
    if addon.coordinates[addon.currentQuest] then
       local data = addon.coordinates[addon.currentQuest]
        if type(data) == "number" then
            data = addon.coordinates[data]
        end
        useSavedCoordinates(data)
        return
    end
    
    if DragonridingSpeedrunDatamining and DragonridingSpeedrunDatamining[addon.currentQuest] then
        useSavedCoordinates(DragonridingSpeedrunDatamining[addon.currentQuest])
        return
    end
    
    if #data.nodes < 5 then return end
    
    local threshold = CHANGE_THRESHOLD
    
    repeat
        wipe(addon.currentVertices)
        
        local originX, originY = data.nodes[1].x, data.nodes[1].y
        local lastX, lastY = data.nodes[2].x - originX, data.nodes[2].y - originY
        if (lastX == 0) and (lastY == 0) then
            print("Speedrun: divide by zero error", lastX, lastY)
            return
        end
        
        local magLast = math.sqrt((lastX*lastX) + (lastY*lastY))
        local lastTime = data.nodes[2].time
        -- using dotproduct formula:
        -- angle = cos^-1 [ a . b / |a| |b| ]
                
        for i = 3, #data.nodes do
            local node = data.nodes[i]
            local nodeX, nodeY = node.x - originX, node.y - originY
            
            if (nodeX == 0) and (nodeY == 0) then
                print("Speedrun: divide by zero error", nodeX, nodeY, i)
                return
            end
            
            local nodeMag = math.sqrt((nodeX*nodeX) + (nodeY*nodeY))
            
            local dotproduct = (lastX * nodeX) + (lastY * nodeY)
            
            local angle = math.acos(dotproduct / (magLast * nodeMag))
            
            if ((node.time - lastTime > addon.options.global.timeSpacing)) and ((angle > threshold) or (angle < (threshold*-1))) then
                table.insert(addon.currentVertices, node)
                
                originX, originY = data.nodes[i-1].x, data.nodes[i-1].y
                lastX, lastY = node.x - originX, node.y - originY
                magLast = math.sqrt((lastX*lastX) + (lastY*lastY))
                lastTime = node.time
            end

        end
        
        threshold = threshold + 0.001
    until (#addon.currentVertices < addon.options.global.maxVertices)
    
    table.insert(addon.currentVertices, data.nodes[#data.nodes])
    
    if #addon.currentVertices < addon.options.global.minVertices then
        wipe(addon.currentVertices)
    
        local numNodes = #data.nodes
        for i = 1, addon.options.global.overrideVertices do
            local num = math.floor((numNodes / addon.options.global.overrideVertices) * i)
            table.insert(addon.currentVertices, data.nodes[num])
        end
    end
end

function addon.findMirrorVertices()
    local data = DragonridingSpeedrunDB[addon.currentQuest]
    
    -- backwards compatibility to when the addon was using positioning instead
    if (#data.nodes > 100) or (#data.nodes < 1) then
        DragonridingSpeedrunDB[addon.currentQuest] = nil
        return
    end
    
    for i = 1, #data.nodes do
        table.insert(addon.currentVertices, data.nodes[i])
    end
end
