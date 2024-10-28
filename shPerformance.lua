local _, ns = ...
local SHP = ns.SHP

-- Tooltip variables
local GameTooltip = GameTooltip
local tipshownMem, tipshownLatency
local prevmem = SHP.collectgarbage("count") -- Initialize memory tracking

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
-- FPS OnUpdate script
local elapsedFpsController = -10
ffps:SetScript("OnUpdate", function(_, t)
	elapsedFpsController = elapsedFpsController - t
	if elapsedFpsController < 0 then
		if tipshownMem and not SHP.IsAddOnLoaded("shMem") then
			data_FPS.OnEnter(tipshownMem)
		end

		local fps = SHP.GetFramerate()
		local rf, gf, bf = SHP.GetFPSColor(fps)
		local fpsText = SHP.ColorizeText(rf, gf, bf, string.format("%.0f", fps))

		if SHP.config.SHOW_BOTH then
			local _, _, lh, lw = SHP.GetNetStats()
			local rl, gl, bl = SHP.GetColorFromGradientTable(((lh + lw) / 2) / SHP.config.MS_GRADIENT_THRESHOLD)
			local latencyText = SHP.ColorizeText(rl, gl, bl, string.format("%.0f", lw))

			data_FPS.text = SHP.string.format("%s | %s", fpsText, latencyText)
		else
			data_FPS.text = SHP.string.format("%s |cffE8D200fps|r", fpsText)
		end

		elapsedFpsController = SHP.config.UPDATE_PERIOD_FPS_DATA_TEXT
	end
end)

-- Latency OnUpdate script
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
		local formattedHomeLatency = string.format("%.0f", latencyHome)
		local formattedWorldLatency = string.format("%.0f(w)", latencyWorld)

		-- Apply color to formatted latency strings
		local colorizedHome = SHP.ColorizeText(rH, gH, bH, formattedHomeLatency)
		local colorizedWorld = SHP.ColorizeText(rW, gW, bW, formattedWorldLatency)

		-- Separate color gradients for boht home and world latencies
		data_Latency.text = SHP.string.format("%s | %s", colorizedHome, colorizedWorld)

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
	GameTooltip:AddLine("|cffc3771aDataBroker|r tooltip showing network stats")
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
	local formattedBin = string.format("%.2f KB/s", bandwidthIn)
	local formattedBOut = string.format("%.2f KB/s", bandwidthOut)

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
if not SHP.IsAddOnLoaded("shMem") then
	-- Update addon memory usage without overwriting the entire table
	local function UpdateAddonMemoryUsage()
		SHP.UpdateAddOnMemoryUsage()
		for name, addonData in pairs(SHP.ADDONS_TABLE) do
			if addonData then
				addonData.memory = SHP.GetAddOnMemoryUsage(name) or 0 -- Update only the memory field
			end
		end
	end

	local function OnEnterFPS(self)
		-- Initialize tooltip
		tipshownMem = self
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint(SHP.GetTipAnchor(self))
		GameTooltip:ClearLines()

		-- Header information
		GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Performance|r")
		GameTooltip:AddLine(SHP.config.SHOW_BOTH and "[Memory/Latency]" or "[Memory]")
		GameTooltip:AddLine("|cffc3771aDataBroker|r tooltip showing sorted memory usage")

		-- Column headers
		SHP.AddToolTipLineSpacer()
		GameTooltip:AddDoubleLine(
			"Addon name",
			SHP.string.format("Memory above (|cff06ddfa%s kb|r)", SHP.config.MEM_THRESHOLD)
		)
		SHP.AddToolTipLineSpacer(true)

		-- Update memory usage data before displaying
		UpdateAddonMemoryUsage()

		-- Convert `SHP.ADDONS_TABLE` to a sortable array for display
		local addonMemoryList = {}
		for addonName, addonData in pairs(SHP.ADDONS_TABLE) do
			SHP.table.insert(
				addonMemoryList,
				{ name = addonName, memory = addonData.memory, colorizedTitle = addonData.colorizedTitle }
			)
		end

		-- Sort `addonMemoryList` by memory usage or alphabetically if configured
		if not SHP.config.WANT_ALPHA_SORTING then
			SHP.table.sort(addonMemoryList, function(a, b)
				return a.memory > b.memory
			end)
		else
			SHP.table.sort(addonMemoryList, function(a, b)
				return a.colorizedTitle:lower() < b.colorizedTitle:lower()
			end)
		end

		-- Display memory usage for each addon
		local counter, shownmem, hiddenmem = 0, 0, 0
		for _, addon in ipairs(addonMemoryList) do
			local colorizedTitle = addon.colorizedTitle
			local memUsage = addon.memory
			if memUsage > SHP.config.MEM_THRESHOLD and counter < SHP.config.MAX_ADDONS then
				counter = counter + 1
				shownmem = shownmem + memUsage

				-- Calculate gradient color for memory usage
				local r, g, b = SHP.GetColorFromGradientTable((memUsage - SHP.config.MEM_THRESHOLD) / 15e3)
				local memStr = SHP.ColorizeText(r, g, b, SHP.formatMem(memUsage))

				-- Display with formatted addon title and colored memory usage
				local counterText = counter < 10 and SHP.string.format("|cffDAB024 %d)|r", counter)
					or SHP.string.format("|cffDAB024%d)|r", counter)
				GameTooltip:AddDoubleLine(SHP.string.format("%s %s", counterText, colorizedTitle), memStr)
			else
				hiddenmem = hiddenmem + memUsage
			end
		end

		-- Display total memory usage
		local totalMemory = SHP.collectgarbage("count")
		local deltaMemory = totalMemory - prevmem
		prevmem = totalMemory
		GameTooltip:AddDoubleLine("Total addon memory usage:", SHP.formatMem(totalMemory, true))

		-- Show tooltip
		GameTooltip:Show()
		elapsedFpsController = -10
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
end
