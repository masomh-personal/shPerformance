local _, ns = ...
local SHP = ns.SHP

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
	SHP.GameTooltip:ClearLines()
	SHP.GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Latency|r")
	SHP.GameTooltip:AddLine("[Latency + Bandwidth]")
	SHP.AddLineSeparatorToTooltip()
	SHP.AddNetworkStatsToTooltip()
	SHP.GameTooltip:Show()
end

-- DATA TEXT: OnUpdate helper function
FRAME_LATENCY:SetScript("OnUpdate", function(_, t)
	elapsedLatencyController = elapsedLatencyController + t
	if elapsedLatencyController >= SHP.CONFIG.UPDATE_PERIOD_LATENCY_DATA_TEXT then
		elapsedLatencyController = 0
		updateDataText()
	end
end)

-- Use helper function in OnEnter to update tooltip in real time
local function OnEnterLatency(self)
	SHP.GameTooltip:SetOwner(self, "ANCHOR_NONE")
	SHP.GameTooltip:SetPoint(SHP.GetTipAnchor(self))
	updateTooltipContent() -- Initial call to display tooltip content

	-- Set up OnUpdate to refresh tooltip content in real time while hovered
	local elapsed = 0
	self:SetScript("OnUpdate", function(_, t)
		elapsed = elapsed + t
		if elapsed >= SHP.CONFIG.UPDATE_PERIOD_LATENCY_DATA_TEXT then
			elapsed = 0
			updateTooltipContent() -- Refresh tooltip content every 0.5 seconds
		end
	end)
end
DATA_TEXT_LATENCY.OnEnter = OnEnterLatency

-- Clear the `OnUpdate` handler when the tooltip is no longer hovered
local function OnLeaveLatency(self)
	SHP.HideTooltip()
	self:SetScript("OnUpdate", nil)
end
DATA_TEXT_LATENCY.OnLeave = OnLeaveLatency
