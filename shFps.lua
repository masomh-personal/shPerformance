local _, ns = ...
local SHP = ns.SHP

local GameTooltip = GameTooltip
local string_format = string.format

local FORMAT_STRINGS = SHP.FORMAT_STRINGS

local DATA_TEXT_FPS = SHP.LDB:NewDataObject("shFps", {
	type = "data source",
	text = "Initializing...",
	icon = SHP.CONFIG.FPS_ICON,
})

SHP.OnFpsUpdate(function(fpsText)
	DATA_TEXT_FPS.text = string_format(FORMAT_STRINGS.FPS_TEXT, fpsText)
end)

local function updateTooltipContent()
	GameTooltip:ClearLines()
	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Fps|r")
	GameTooltip:AddLine("[Latency + Bandwidth]")
	SHP.AddLineSeparatorToTooltip()
	SHP.AddNetworkStatsToTooltip()
	GameTooltip:Show()
end

SHP.AttachTooltipHandlers(DATA_TEXT_FPS, updateTooltipContent)
