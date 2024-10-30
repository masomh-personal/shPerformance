local _, ns = ...
local SHP = ns.SHP

-- Localize: Tooltip variables
local GameTooltip = GameTooltip

----------------------
--> Modules, frames, uppdate controllers
----------------------
local FRAME_LATENCY = CreateFrame("frame")
local elapsedLatencyController = 0
local cachedDetailedLatencyText = "Initializing ms..."

local DATA_TEXT_LATENCY = SHP.LibStub:NewDataObject("shLatency", {
	type = "data source",
	text = "Initializing (ms)",
	icon = SHP.CONFIG.MS_ICON,
})

----------------------
--> shLatency Module
----------------------
-- Helper function to get formatted latency
local function getFormattedLatency()
	local _, _, latencyHome, latencyWorld = SHP.GetNetStats()

	-- Apply color gradients and format latency values
	local rH, gH, bH = SHP.GetColorFromGradientTable(latencyHome / SHP.CONFIG.MS_GRADIENT_THRESHOLD)
	local rW, gW, bW = SHP.GetColorFromGradientTable(latencyWorld / SHP.CONFIG.MS_GRADIENT_THRESHOLD)
	local colorizedHome = SHP.ColorizeText(rH, gH, bH, SHP.string.format("%.0f", latencyHome))
	local colorizedWorld = SHP.ColorizeText(rW, gW, bW, SHP.string.format("%.0f(w)", latencyWorld))

	return colorizedHome, colorizedWorld
end

--[[ 
	Adds network latency stats to a specified tooltip with colorized formatting.
	@param tooltip: The tooltip object to which the network stats will be added.
	@return: bandwidth (in and out) [optional]
--]]
local function AddNetworkStatsToTooltip()
	-- Retrieve network stats from WoW's API or custom function
	local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = SHP.GetNetStats()

	local ipTypeHomeText, ipTypeWorldText = "HOME", "WORLD"
	if not SHP.GetCVarBool("useIPv6") then
		local ipTypes = { "IPv4", "IPv6" }
		local ipTypeHome, ipTypeWorld = SHP.GetNetIpTypes()
		ipTypeHomeText = SHP.string.format("HOME (%s)", ipTypes[ipTypeHome or 0] or UNKNOWN)
		ipTypeWorldText = SHP.string.format("WORLD (%s)", ipTypes[ipTypeWorld or 0] or UNKNOWN)
	end

	-- Calculate RGB gradient colors for latency based on thresholds in the config
	local rH, gH, bH = SHP.GetColorFromGradientTable(latencyHome / SHP.CONFIG.MS_GRADIENT_THRESHOLD)
	local rW, gW, bW = SHP.GetColorFromGradientTable(latencyWorld / SHP.CONFIG.MS_GRADIENT_THRESHOLD)

	-- Format latency values to display as integers with "ms" suffix
	local formattedHomeLatency = string.format("%.0f ms", latencyHome)
	local formattedWorldLatency = string.format("%.0f ms", latencyWorld)

	-- Apply color to formatted latency strings
	local colorizedHome = SHP.ColorizeText(rH, gH, bH, formattedHomeLatency)
	local colorizedWorld = SHP.ColorizeText(rW, gW, bW, formattedWorldLatency)

	-- Add colorized latency details to the tooltip
	local homeHexColor = "42AAFF"
	local worldHexColor = "DCFF42"
	SHP.GameTooltip:AddDoubleLine(
		SHP.string.format("|cff%s%s|r |cffFFFFFFlatency:|r", homeHexColor, ipTypeHomeText),
		colorizedHome
	)
	SHP.GameTooltip:AddDoubleLine(
		SHP.string.format("|cff%s%s|r |cffFFFFFFlatency:|r", worldHexColor, ipTypeWorldText),
		colorizedWorld
	)

	-- Bandwidth Gradient RGB (one for in and one for out)
	SHP.AddLineSeparatorToTooltip(true)
	local rIn, gIn, bIn = SHP.GetColorFromGradientTable(bandwidthIn / SHP.CONFIG.BANDWIDTH_INCOMING_GRADIENT_THRESHOLD)
	local rOut, gOut, bOut =
		SHP.GetColorFromGradientTable(bandwidthOut / SHP.CONFIG.BANDWIDTH_OUTGOING_GRADIENT_THRESHOLD)

	-- Format bandwidth details first
	local formattedBin = SHP.string.format("▼ %.2f KB/s", bandwidthIn)
	local formattedBOut = SHP.string.format("▲ %.2f KB/s", bandwidthOut)

	-- Colorize the formatted bandwidth strings
	local colorizedBin = SHP.ColorizeText(rIn, gIn, bIn, formattedBin)
	local colorizedBOut = SHP.ColorizeText(rOut, gOut, bOut, formattedBOut)

	-- Use AddColoredDoubleLine with the colorized text
	SHP.AddColoredDoubleLineToTooltip("|cff00FFFFIncoming|r |cffFFFFFFbandwidth:|r", colorizedBin)
	SHP.AddColoredDoubleLineToTooltip("|cff00FFFFOutgoing|r |cffFFFFFFbandwidth:|r", colorizedBOut)
end

-- Helper function to update data text
local function updateDataText()
	local colorizedHome, colorizedWorld = getFormattedLatency()
	-- Combine latency details for display
	cachedDetailedLatencyText = SHP.string.format("%s → %s", colorizedHome, colorizedWorld)
	DATA_TEXT_LATENCY.text = cachedDetailedLatencyText
end

-- INITIAL Update of data text
updateDataText()

-- Helper function to update tooltip content
local function updateTooltipContent()
	GameTooltip:ClearLines()
	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Latency|r")
	GameTooltip:AddLine("[Bandwidth/Latency]")
	SHP.AddLineSeparatorToTooltip()
	AddNetworkStatsToTooltip()
	GameTooltip:Show()
end

-- Use helper function in OnUpdate to update data text only
FRAME_LATENCY:SetScript("OnUpdate", function(_, t)
	elapsedLatencyController = elapsedLatencyController + t
	if elapsedLatencyController >= SHP.CONFIG.UPDATE_PERIOD_LATENCY_DATA_TEXT then
		elapsedLatencyController = 0
		updateDataText()
	end
end)

-- Use helper function in OnEnter to update tooltip in real time
local function OnEnterLatency(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint(SHP.GetTipAnchor(self))
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
