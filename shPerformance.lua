local _, ns = ...
local SHP = ns.SHP

-- Localize: Tooltip variables
local GameTooltip = GameTooltip

----------------------
--> Modules, frames, uppdate controllers
----------------------
local ffps = CreateFrame("frame")
local elapsedFpsController = 0

local flatency = CreateFrame("frame")
local elapsedLatencyController = 0
local cachedDetailedLatencyText = "Initializing ms..."

local lib = LibStub:GetLibrary("LibDataBroker-1.1")

local data_FPS = lib:NewDataObject("shFps", {
	type = "data source",
	text = "Initializing (fps)",
	icon = SHP.config.FPS_ICON,
})
local data_Latency = lib:NewDataObject("shLatency", {
	type = "data source",
	text = "Initializing (ms)",
	icon = SHP.config.MS_ICON,
})

----------------------
--> shLatency Module
----------------------
-- Helper function to get formatted latency and bandwidth data
local function getFormattedLatencyAndBandwidth()
	local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = SHP.GetNetStats()

	-- Format latency with colors
	local rH, gH, bH = SHP.GetColorFromGradientTable(latencyHome / SHP.config.MS_GRADIENT_THRESHOLD)
	local rW, gW, bW = SHP.GetColorFromGradientTable(latencyWorld / SHP.config.MS_GRADIENT_THRESHOLD)
	local colorizedHome = SHP.ColorizeText(rH, gH, bH, SHP.string.format("%.0f ms", latencyHome))
	local colorizedWorld = SHP.ColorizeText(rW, gW, bW, SHP.string.format("%.0f(w) ms", latencyWorld))

	-- Format bandwidth with colors
	local rIn, gIn, bIn = SHP.GetColorFromGradientTable(bandwidthIn / SHP.config.BANDWIDTH_INCOMING_GRADIENT_THRESHOLD)
	local rOut, gOut, bOut =
		SHP.GetColorFromGradientTable(bandwidthOut / SHP.config.BANDWIDTH_OUTGOING_GRADIENT_THRESHOLD)
	local colorizedBin = SHP.ColorizeText(rIn, gIn, bIn, SHP.string.format("%.2f KB/s", bandwidthIn))
	local colorizedBOut = SHP.ColorizeText(rOut, gOut, bOut, SHP.string.format("%.2f KB/s", bandwidthOut))

	return colorizedHome, colorizedWorld, colorizedBin, colorizedBOut
end

-- Helper function to update data text
local function updateDataText()
	local colorizedHome, colorizedWorld = getFormattedLatencyAndBandwidth()

	-- Combine latency details for display
	cachedDetailedLatencyText = SHP.string.format("%s | %s", colorizedHome, colorizedWorld)

	data_Latency.text = cachedDetailedLatencyText
end

-- Helper function to update tooltip content
local function updateTooltipContent()
	GameTooltip:ClearLines()
	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Latency|r")
	GameTooltip:AddLine("[Bandwidth/Latency]")
	GameTooltip:AddLine("|cffc3771aDATABROKER|r tooltip showing network stats")
	SHP.AddToolTipLineSpacer()

	-- Use formatted data from the helper function
	local colorizedHome, colorizedWorld, colorizedBin, colorizedBOut = getFormattedLatencyAndBandwidth()

	-- Add latency and bandwidth to the tooltip
	SHP.AddColoredDoubleLine("|cff00FFFFHome Latency:|r", colorizedHome)
	SHP.AddColoredDoubleLine("|cff00FFFFWorld Latency:|r", colorizedWorld)
	SHP.AddColoredDoubleLine("|cff00FFFFIncoming bandwidth:|r", colorizedBin)
	SHP.AddColoredDoubleLine("|cff00FFFFOutgoing bandwidth:|r", colorizedBOut)
	GameTooltip:Show()
end

-- Use helper function in OnUpdate to update data text only
flatency:SetScript("OnUpdate", function(_, t)
	elapsedLatencyController = elapsedLatencyController - t
	if elapsedLatencyController < 0 then
		updateDataText()
		elapsedLatencyController = SHP.config.UPDATE_PERIOD_LATENCY_DATA_TEXT
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
		if elapsed >= SHP.UPDATE_PERIOD_TOOLTIP then
			elapsed = 0
			updateTooltipContent() -- Refresh tooltip content every 0.5 seconds
		end
	end)
end
data_Latency.OnEnter = OnEnterLatency

local function OnLeaveLatency(self)
	SHP.HideTooltip()
	self:SetScript("OnUpdate", nil)
end
data_Latency.OnLeave = OnLeaveLatency -- Clear the `OnUpdate` handler when the tooltip is no longer hovered

-- ----------------------
-- --> ONLEAVE FUNCTIONS
-- ----------------------

-- Updated OnLeave Handlers
data_FPS.OnLeave = function()
	SHP.HideTooltip()
end

----------------------
--> FPS Data TOOLTIP
----------------------
--[[ 
    Function to populate the FPS tooltip with addon memory usage details.
    Updates addon memory usage, sorts the addon data for display, and 
    formats the tooltip with memory and latency data if enabled.

    @param self: The tooltip anchor (frame) from which this function is called.
    @return: None. Modifies the tooltip display in place.
--]]
local function OnEnterFPS(self)
	GameTooltip:ClearLines()
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint(SHP.GetTipAnchor(self))

	-- Header information for the tooltip
	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Performance|r")
	GameTooltip:AddLine(SHP.config.SHOW_BOTH and "[Memory/Latency]" or "[Memory]")
	GameTooltip:AddLine("|cffc3771aDATABROKER|r tooltip showing sorted memory usage")

	-- Display latency stats if configured to show both memory and latency
	if SHP.config.SHOW_BOTH then
		GameTooltip:AddLine(
			SHP.string.format("|cffC3771ANETWORK|r stats (latency: home / world) → %s", cachedDetailedLatencyText)
		)
	end

	-- Add column headers and a separator line
	SHP.AddToolTipLineSpacer()
	GameTooltip:AddDoubleLine(
		"ADDON NAME",
		SHP.string.format("MEMORY USED (|cff06ddfaabove %sK|r)", SHP.config.MEM_THRESHOLD)
	)
	SHP.AddToolTipLineSpacer(true)

	-- Update memory usage for all addons in `SHP.ADDONS_TABLE` using the SHP method
	SHP.UpdateUserAddonMemoryUsageTable()

	-- Sort `SHP.ADDONS_TABLE` directly based on config
	if not SHP.config.WANT_ALPHA_SORTING then
		table.sort(SHP.ADDONS_TABLE, function(a, b)
			return a.memory > b.memory
		end)
	else
		table.sort(SHP.ADDONS_TABLE, function(a, b)
			return a.colorizedTitle:lower() < b.colorizedTitle:lower()
		end)
	end

	-- Display memory usage for each addon from `SHP.ADDONS_TABLE`
	local counter, hiddenAddonMemoryUsage = 0, 0
	local totalNumAddons, totalUserAddonMemoryUsage = #SHP.ADDONS_TABLE, 0
	for _, addon in ipairs(SHP.ADDONS_TABLE) do
		local colorizedTitle = addon.colorizedTitle
		local addonMemUsage = addon.memory
		totalUserAddonMemoryUsage = totalUserAddonMemoryUsage + addonMemUsage
		if addonMemUsage > SHP.config.MEM_THRESHOLD then
			counter = counter + 1
			-- Determine color gradient for memory usage and format string
			local r, g, b = SHP.GetColorFromGradientTable((addonMemUsage - SHP.config.MEM_THRESHOLD) / 15e3)
			local memStr = SHP.ColorizeText(r, g, b, SHP.formatMem(addonMemUsage))
			-- Format counter with padding for numbers under 10
			local counterText = counter < 10 and SHP.string.format("|cffDAB024 %d)|r", counter)
				or SHP.string.format("|cffDAB024%d)|r", counter)
			GameTooltip:AddDoubleLine(SHP.string.format("%s %s", counterText, colorizedTitle), memStr)
		else
			hiddenAddonMemoryUsage = hiddenAddonMemoryUsage + addonMemUsage
		end
	end

	-- Display summary for hidden addons if applicable
	if hiddenAddonMemoryUsage > 0 then
		GameTooltip:AddDoubleLine(
			SHP.string.format(
				"|cff06DDFA... [%d] hidden addons|r (usage less than %dK)",
				totalNumAddons - counter,
				SHP.config.MEM_THRESHOLD
			),
			" "
		)
	end

	-- Display total user addon memory usage
	GameTooltip:AddDoubleLine(" ", "|cffffffff------------|r")
	GameTooltip:AddDoubleLine(
		" ",
		SHP.string.format(
			"|cffC3771ATOTAL ADDON|r memory usage → |cff06ddfa%s|r",
			SHP.formatMem(totalUserAddonMemoryUsage)
		)
	)

	-- Display hint for forced garbage collection
	SHP.AddToolTipLineSpacer()
	GameTooltip:AddLine("→ *Click to force |cffc3771agarbage|r collection and to |cff06ddfaupdate|r tooltip*")

	-- Finally, show the tooltip
	GameTooltip:Show()
end
data_FPS.OnEnter = OnEnterFPS

local function OnClickFPS()
	local preCollect = SHP.collectgarbage("count")
	SHP.collectgarbage("collect")
	local deltaMemCollected = preCollect - SHP.collectgarbage("count")

	-- Display the amount of memory collected
	print(
		SHP.string.format(
			"|cff0DEB11shPerformance|r - Garbage Collected: |cff06ddfa%s|r",
			SHP.formatMem(deltaMemCollected, true)
		)
	)
end
data_FPS.OnClick = OnClickFPS
