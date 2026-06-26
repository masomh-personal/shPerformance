local _, ns = ...
local SHP = ns.SHP

-- ===================================================================================
-- OPTIMIZED: Localize frequently used functions
-- ===================================================================================
local CreateFrame = CreateFrame
local string_format = SHP.string.format
local GameTooltip = SHP.GameTooltip
local FORMAT_STRINGS = SHP.FORMAT_STRINGS

----------------------
--> Modules, frames, update controllers
----------------------
local FRAME_LATENCY = CreateFrame("frame")

-- Adding one to update period to ensure first and immediate update
local elapsedLatencyController = SHP.CONFIG.UPDATE_PERIOD_LATENCY_DATA_TEXT + 1
local cachedDetailedLatencyText = "Initializing ms..."

local DATA_TEXT_LATENCY = SHP.LibStub:NewDataObject("shLatency", {
	type = "data source",
	text = "Initializing (ms)",
	icon = SHP.CONFIG.MS_ICON,
})

----------------------
--> shLatency Module
----------------------

-- Helper function to update data text
local function updateDataText()
	-- Combine latency details for display
	cachedDetailedLatencyText = SHP.UpdateLatencyDataText()
	DATA_TEXT_LATENCY.text = cachedDetailedLatencyText
end

-- Helper function to update tooltip content
local function updateTooltipContent()
	GameTooltip:ClearLines()
	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Latency|r")
	GameTooltip:AddLine("[Latency + Bandwidth]")
	SHP.AddLineSeparatorToTooltip()
	SHP.AddNetworkStatsToTooltip()
	GameTooltip:Show()
end

-- DATA TEXT: OnUpdate helper function
FRAME_LATENCY:SetScript("OnUpdate", function(_, t)
	elapsedLatencyController = elapsedLatencyController + t
	if elapsedLatencyController >= SHP.CONFIG.UPDATE_PERIOD_LATENCY_DATA_TEXT then
		elapsedLatencyController = 0
		updateDataText()
	end
end)

SHP.AttachTooltipHandlers(DATA_TEXT_LATENCY, updateTooltipContent)
