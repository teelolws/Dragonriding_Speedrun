local addonName, addon = ...

-- Translation file
-- When a race is finished successfully, a message pops up
-- "Race Time: 123.45 seconds"
-- To work in other languages, this addon needs the phrase in the other languages

addon.raceTimePattern = {}
addon.raceTimePattern.enUS = "Race Time: (%d+%.%d+) seconds"
addon.raceTimePattern[GetLocale()] = addon.raceTimePattern.enUS

--addon.raceTimePattern.frFR = " (%d+%.%d+) "
--addon.raceTimePattern.deDE = " (%d+%.%d+) "
--addon.raceTimePattern.koKR = " (%d+%.%d+) "
--addon.raceTimePattern.ruRU = " (%d+%.%d+) "
--addon.raceTimePattern.esMX = " (%d+%.%d+) "
--addon.raceTimePattern.ptBR = " (%d+%.%d+) "
--addon.raceTimePattern.esES = " (%d+%.%d+) "
--addon.raceTimePattern.zhCN = " (%d+%.%d+) "
--addon.raceTimePattern.zhTW = " (%d+%.%d+) "

