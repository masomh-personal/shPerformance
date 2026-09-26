local _, ns = ...
local SHP = ns.SHP

local GameTooltip = GameTooltip

local DATA_TEXT_LATENCY = SHP.LDB:NewDataObject("shLatency", {
	type = "data source",
	text = "Initializing (ms)",
	icon = SHP.CONFIG.MS_ICON,
})

SHP.OnLatencyUpdate(function(latencyText)
	DATA_TEXT_LATENCY.text = latencyText
end)

local function updateTooltipContent()
	GameTooltip:ClearLines()
	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Latency|r")
	GameTooltip:AddLine("[Latency + Bandwidth]")
	SHP.AddLineSeparatorToTooltip()
	SHP.AddNetworkStatsToTooltip()
	GameTooltip:Show()
end

SHP.AttachTooltipHandlers(DATA_TEXT_LATENCY, updateTooltipContent)
