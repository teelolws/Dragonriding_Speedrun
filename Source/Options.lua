local addonName, addon = ...

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local defaults = {
    global = {
        radiusPermitted = 10,
    }
}

local options = {
    type = "group",
    set = function(info, value) addon.options.global[info[#info]] = value end,
    get = function(info) return addon.options.global[info[#info]] end,
    args = {
        description = {
            name = "For details on what these options do, please check the manual at: https://github.com/teelolws/Dragonriding_Speedrun/wiki/Options",
            type = "description",
            fontSize = "medium",
            order = 0,
        },
        radiusPermitted = {
            name = "Radius to Activate",
            desc = "How close you need to get to a checkpoint to register it",
            type = "range",
            min = 1,
            max = 100,
            step = 1,
        },
    },
}

EventUtil.ContinueOnAddOnLoaded(addonName, function()
    addon.options = LibStub("AceDB-3.0"):New("DragonridingSpeedrunOptions", defaults)
        
    AceConfigRegistry:RegisterOptionsTable(addonName, options)
    AceConfigDialog:AddToBlizOptions(addonName)
end)
