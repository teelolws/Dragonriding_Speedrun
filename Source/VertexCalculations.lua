local addonName, addon = ...

addon.currentVertices = {}
addon.nextVertexNum = 1
addon.currentVerticesTimes = {}

local MIN_VERTICES = 4
local MAX_VERTICES = 10
local CHANGE_THRESHOLD = 30
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
        
        local lastX, lastY = data.nodes[1].x, data.nodes[1].y
        local turningPositiveX, turningPositiveY = (data.nodes[2].x - data.nodes[1].x) >= 0, (data.nodes[2].y - data.nodes[1].y) >= 0
        lastTime = data.nodes[1].time
        
        for i = 2, #data.nodes do
            local node = data.nodes[i]
            local deltaX, deltaY = node.x - lastX, node.y - lastY
            
            if ((node.time - lastTime > SPACING)) and ((deltaX > threshold) or (deltaX < (-1 * threshold)) and ((deltaY > threshold) or (deltaY < (-1 * threshold)))) then
                lastX, lastY, lastTime = node.x, node.y, node.time
                
                local earlierNode = data.nodes[i-5]
                if i < 5 then
                    earlierNode = node
                end
                table.insert(addon.currentVertices, earlierNode)
            
            else
                if turningPositiveX and (deltaX < (-1 * SWITCH_DIRECTION_THRESHOLD)) then
                    lastX = node.x
                    turningPositiveX = false
                elseif (not turningPositiveX) and (deltaX > SWITCH_DIRECTION_THRESHOLD) then
                    lastX = node.x
                    turningPositiveX = true
                end
                
                if turningPositiveY and (deltaY < (-1 * SWITCH_DIRECTION_THRESHOLD)) then
                    lastY = node.y
                    turningPositiveY = false
                elseif (not turningPositiveY) and (deltaY > SWITCH_DIRECTION_THRESHOLD) then
                    lastY = node.y
                    turningPositiveY = true
                end
            end
        end
        
        threshold = threshold + 5
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
