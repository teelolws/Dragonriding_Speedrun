local addonName, addon = ...

local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

local defaults = {
    global = {
        radiusPermitted = 10,
        minVertices = 4,
        maxVertices = 10,
        overrideVertices = 6,
        timeSpacing = 3,
        precision = 2,
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
        minVertices = {
            name = "Minimum Checkpoints",
            desc = "Fewest number of checkpoints",
            type = "range",
            min = 1,
            max = 20,
            step = 1,
        },
        maxVertices = {
            name = "Maximum Checkpoints",
            desc = "Maximum number of checkpoints",
            type = "range",
            min = 2,
            max = 20,
            step = 1,
        },
        overrideVertices = {
            name = "Fallback Checkpoints",
            desc = "How many checkpoints to calculate if the fallback algorithm is used",
            type = "range",
            min = 3,
            max = 20,
            step = 1,
        },
        timeSpacing = {
            name = "Minimum Time Spacing",
            desc = "Minimum number of seconds between checkpoints",
            type = "range",
            min = 1,
            max = 30,
            step = 1,
        },
        precision = {
            name = "Decimal places",
            desc = "Number of decimal places to show times to",
            type = "range",
            min = 0,
            max = 6,
            step = 1,
        },
    },
}

EventUtil.ContinueOnAddOnLoaded(addonName, function()
    addon.options = LibStub("AceDB-3.0"):New("DragonridingSpeedrunOptions", defaults)
        
    AceConfigRegistry:RegisterOptionsTable(addonName, options)
    AceConfigDialog:AddToBlizOptions(addonName)
end)
