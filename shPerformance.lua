local _, ns = ...
local SHP = ns.SHP

-- Tooltip variables
local GameTooltip = GameTooltip
local tipshownMem, tipshownLatency

----------------------
--> MODULES AND FRAMES
----------------------
local ffps = CreateFrame("frame")
local flatency = CreateFrame("frame")
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
--> ONUPDATE HANDLERS for the DATA TEXT itself
----------------------
local elapsedFpsTimer = -10
local elapsedLatencyTimer = 0 -- Start at 0 to trigger an initial latency fetch
local cachedLatencyText = "|cffFFFFFF--|r ms" -- Default latency display text
ffps:SetScript("OnUpdate", function(_, t)
	-- Update elapsed time
	elapsedFpsTimer = elapsedFpsTimer - t
	elapsedLatencyTimer = elapsedLatencyTimer - t

	-- Check if it’s time to update FPS data based on configured period
	if elapsedFpsTimer < 0 then
		-- Show memory tooltip if condition met
		if tipshownMem and not SHP.IsAddOnLoaded("shMem") then
			data_FPS.OnEnter(tipshownMem)
		end

		-- Get current FPS and color it based on threshold
		local fps = SHP.math.floor(SHP.GetFramerate())
		local rf, gf, bf = SHP.GetFPSColor(fps)
		local fpsText = SHP.ColorizeText(rf, gf, bf, SHP.string.format("%.0f", fps))

		-- Update latency data only if the latency timer has reached 30 seconds
		if elapsedLatencyTimer <= 0 then
			local _, _, lh, lw = SHP.GetNetStats()
			local averageLatency = (lh + lw) / 2
			local rl, gl, bl = SHP.GetColorFromGradientTable(averageLatency / SHP.config.MS_GRADIENT_THRESHOLD)
			cachedLatencyText = SHP.ColorizeText(rl, gl, bl, SHP.string.format("%.0f", lw))

			-- Reset the latency timer to 30 seconds
			elapsedLatencyTimer = 30
		end

		-- Check if both FPS and latency should be shown
		if SHP.config.SHOW_BOTH then
			-- Display both FPS and cached latency text
			data_FPS.text = SHP.string.format("%s | %s", fpsText, cachedLatencyText)
		else
			-- Display only FPS with “fps” label
			data_FPS.text = SHP.string.format("%s |cffE8D200fps|r", fpsText)
		end

		-- Reset the FPS update timer
		elapsedFpsTimer = SHP.config.UPDATE_PERIOD_FPS_DATA_TEXT
	end
end)

-- Latency OnUpdate script
local cachedDetailedLatencyText = "Initializing ms..." -- Can be used in any scenario (used in shPerformance tooltip)
local elapsedLatencyController = -10
flatency:SetScript("OnUpdate", function(_, t)
	elapsedLatencyController = elapsedLatencyController - t
	if elapsedLatencyController < 0 then
		if tipshownLatency then
			data_Latency.OnEnter(tipshownLatency)
		end

		-- Retrieve network stats from WoW's API or custom function
		local _, _, latencyHome, latencyWorld = SHP.GetNetStats()

		-- Calculate RGB gradient colors for latency based on thresholds in the config
		local rH, gH, bH = SHP.GetColorFromGradientTable(latencyHome / SHP.config.MS_GRADIENT_THRESHOLD)
		local rW, gW, bW = SHP.GetColorFromGradientTable(latencyWorld / SHP.config.MS_GRADIENT_THRESHOLD)

		-- Format latency values to display as integers with "ms" suffix
		local formattedHomeLatency = SHP.string.format("%.0f", latencyHome)
		local formattedWorldLatency = SHP.string.format("%.0f(w)", latencyWorld)

		-- Apply color to formatted latency strings
		local colorizedHome = SHP.ColorizeText(rH, gH, bH, formattedHomeLatency)
		local colorizedWorld = SHP.ColorizeText(rW, gW, bW, formattedWorldLatency)

		-- Separate color gradients for boht home and world latencies
		cachedDetailedLatencyText = SHP.string.format("%s | %s", colorizedHome, colorizedWorld)
		data_Latency.text = cachedDetailedLatencyText

		-- Update timer
		elapsedLatencyController = SHP.config.UPDATE_PERIOD_LATENCY_DATA_TEXT
	end
end)

-- ----------------------
-- --> ONLEAVE FUNCTIONS
-- ----------------------
-- Consolidated Hide Tooltip function
local function HideTooltip(tipShown)
	GameTooltip:SetClampedToScreen(true)
	GameTooltip:Hide()
	tipShown = nil -- Ensures the tooltip reference is cleared
end

-- Updated OnLeave Handlers
if not SHP.IsAddOnLoaded("shMem") then
	data_FPS.OnLeave = function()
		HideTooltip(tipshownMem)
		tipshownMem = nil -- Clear the reference to prevent re-triggering
	end
end

data_Latency.OnLeave = function()
	HideTooltip(tipshownLatency)
	tipshownLatency = nil -- Clear the reference here as well
end

----------------------
--> LATENCY (MS) TOOLTIP
----------------------
local function OnEnterLatency(self)
	tipshownLatency = self
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint(SHP.GetTipAnchor(self))
	GameTooltip:ClearLines()

	-- Tooltip Header
	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Latency|r")
	GameTooltip:AddLine("[Bandwidth/Latency]")
	GameTooltip:AddLine("|cffc3771aDATABROKER|r tooltip showing network stats")
	SHP.AddToolTipLineSpacer()

	-- Helper function for latency module
	local bandwidthIn, bandwidthOut, _, _ = SHP.GetNetStats()
	SHP.AddNetworkStatsToTooltip()

	-- Bandwidth Gradient RGB (one for in and one for out)
	SHP.AddToolTipLineSpacer(true)
	local rIn, gIn, bIn = SHP.GetColorFromGradientTable(bandwidthIn / SHP.config.BANDWIDTH_INCOMING_GRADIENT_THRESHOLD)
	local rOut, gOut, bOut =
		SHP.GetColorFromGradientTable(bandwidthOut / SHP.config.BANDWIDTH_OUTGOING_GRADIENT_THRESHOLD)

	-- Format bandwidth details first
	local formattedBin = SHP.string.format("%.2f KB/s", bandwidthIn)
	local formattedBOut = SHP.string.format("%.2f KB/s", bandwidthOut)

	-- Colorize the formatted bandwidth strings
	local colorizedBin = SHP.ColorizeText(rIn, gIn, bIn, formattedBin)
	local colorizedBOut = SHP.ColorizeText(rOut, gOut, bOut, formattedBOut)

	-- Use AddColoredDoubleLine with the colorized text
	SHP.AddColoredDoubleLine("|cff00FFFFIncoming bandwidth:|r", colorizedBin)
	SHP.AddColoredDoubleLine("|cff00FFFFOutgoing bandwidth:|r", colorizedBOut)

	-- Show Tooltip
	GameTooltip:Show()
	elapsedLatencyController = -10
end

-- On Enter (MS)
data_Latency.OnEnter = OnEnterLatency
-- On Click (MS) Do nothing!
data_Latency.OnClick = function() end

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
	-- Set the anchor for the tooltip and clear any existing lines
	tipshownMem = self
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
	GameTooltip:Show()
end
data_FPS.OnEnter = OnEnterFPS

-- OnClickFPS Function
local function OnClickFPS()
	-- Show updated tooltip on click and perform garbage collection
	data_FPS.OnEnter(tipshownMem)
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
