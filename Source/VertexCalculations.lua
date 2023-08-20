local addonName, addon = ...

addon.currentVertices = {}
addon.nextVertexNum = 1
addon.currentVerticesTimes = {}

local MIN_VERTICES = 4
local MAX_VERTICES = 10
local CHANGE_THRESHOLD = math.pi/8
local OVERRIDE_VERTICES = 6
local SPACING = 3
local SWITCH_DIRECTION_THRESHOLD = 4

function addon.findVertices(currentQuest)
    wipe(addon.currentVertices)
    addon.nextVertexNum = 1
    wipe(addon.currentVerticesTimes)
    
    local data = DragonridingSpeedrunDB[currentQuest]
    
    if data == nil then return end
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
            
            if ((node.time - lastTime > SPACING)) and ((angle > threshold) or (angle < (threshold*-1))) then
                table.insert(addon.currentVertices, node)
                
                originX, originY = data.nodes[i-1].x, data.nodes[i-1].y
                lastX, lastY = node.x - originX, node.y - originY
                magLast = math.sqrt((lastX*lastX) + (lastY*lastY))
                lastTime = node.time
            end

        end
        
        threshold = threshold + 0.001
    until (#addon.currentVertices < MAX_VERTICES)
    
    table.insert(addon.currentVertices, data.nodes[#data.nodes])
    
    if #addon.currentVertices < MIN_VERTICES then
        wipe(addon.currentVertices)
    
        local numNodes = #data.nodes
        for i = 1, OVERRIDE_VERTICES do
            local num = math.floor((numNodes / OVERRIDE_VERTICES) * i)
            table.insert(addon.currentVertices, data.nodes[num])
        end
    end
end
