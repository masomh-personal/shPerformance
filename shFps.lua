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
local FRAME_FPS = CreateFrame("Frame")

-- Adding one to update period to ensure first and immediate update
local elapsedFpsController = SHP.CONFIG.UPDATE_PERIOD_FPS_DATA_TEXT + 1

local DATA_TEXT_FPS = SHP.LibStub:NewDataObject("shFps", {
	type = "data source",
	text = "Initializing...",
	icon = SHP.CONFIG.FPS_ICON,
})

-- Helper function to update data text for FPS display
local function updateDataText()
	DATA_TEXT_FPS.text = string_format(FORMAT_STRINGS.FPS_TEXT, SHP.UpdateFPSDataText())
end

-- Helper function to update tooltip content
local function updateTooltipContent()
	GameTooltip:ClearLines()
	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Fps|r")
	GameTooltip:AddLine("[Latency + Bandwidth]")
	SHP.AddLineSeparatorToTooltip()
	SHP.AddNetworkStatsToTooltip()
	GameTooltip:Show()
end

-- DATA TEXT: OnUpdate helper function
FRAME_FPS:SetScript("OnUpdate", function(_, t)
	elapsedFpsController = elapsedFpsController + t
	if elapsedFpsController >= SHP.CONFIG.UPDATE_PERIOD_FPS_DATA_TEXT then
		elapsedFpsController = 0
		updateDataText()
	end
end)

SHP.AttachTooltipHandlers(DATA_TEXT_FPS, updateTooltipContent)
