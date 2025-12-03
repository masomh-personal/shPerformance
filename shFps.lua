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
--> Modules, frames, uppdate controllers
----------------------
local FRAME_FPS = CreateFrame("frame")

-- Adding one to update period to ensure first and immediate update
local elapsedLatencyController = SHP.CONFIG.UPDATE_PERIOD_LATENCY_DATA_TEXT + 1

local DATA_TEXT_FPS = SHP.LibStub:NewDataObject("shFps", {
	type = "data source",
	text = "Initializing...",
	icon = SHP.CONFIG.FPS_ICON,
})

----------------------
--> shLatency Module
----------------------

-- Helper function to update data text
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
	elapsedLatencyController = elapsedLatencyController + t
	if elapsedLatencyController >= SHP.CONFIG.UPDATE_PERIOD_FPS_DATA_TEXT then
		elapsedLatencyController = 0
		updateDataText()
	end
end)

-- ===================================================================================
-- OPTIMIZED: Reusable tooltip update handler to prevent memory leaks
-- ===================================================================================
local tooltipUpdateHandler = function(self, elapsed)
	self.tooltipElapsed = (self.tooltipElapsed or 0) + elapsed
	if self.tooltipElapsed >= SHP.CONFIG.UPDATE_PERIOD_TOOLTIP then
		self.tooltipElapsed = 0
		updateTooltipContent() -- Refresh tooltip content
	end
end

-- Use reusable handler in OnEnter to prevent closure creation
local function OnEnterFps(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint(SHP.GetTipAnchor(self))
	updateTooltipContent() -- Initial call to display tooltip content
	
	-- Reset elapsed counter and use reusable handler
	self.tooltipElapsed = 0
	self:SetScript("OnUpdate", tooltipUpdateHandler)
end
DATA_TEXT_FPS.OnEnter = OnEnterFps

-- Clear the OnUpdate handler when the tooltip is no longer hovered
local function OnLeaveFps(self)
	SHP.HideTooltip()
	self:SetScript("OnUpdate", nil)
	self.tooltipElapsed = nil
end
DATA_TEXT_FPS.OnLeave = OnLeaveFps
