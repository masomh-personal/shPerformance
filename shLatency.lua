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
local function OnEnterLatency(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint(SHP.GetTipAnchor(self))
	updateTooltipContent() -- Initial call to display tooltip content
	
	-- Reset elapsed counter and use reusable handler
	self.tooltipElapsed = 0
	self:SetScript("OnUpdate", tooltipUpdateHandler)
end
DATA_TEXT_LATENCY.OnEnter = OnEnterLatency

-- Clear the OnUpdate handler when the tooltip is no longer hovered
local function OnLeaveLatency(self)
	SHP.HideTooltip()
	self:SetScript("OnUpdate", nil)
	self.tooltipElapsed = nil
end
DATA_TEXT_LATENCY.OnLeave = OnLeaveLatency
