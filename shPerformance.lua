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
--> HELPER FUNCTIONS
----------------------
-- Helper function to add a colored double line to the tooltip
local function AddColoredDoubleLine(label, value, r, g, b)
	GameTooltip:AddDoubleLine(label, value, r, g, b)
end

----------------------
--> ONUPDATE HANDLERS for the data text themselves
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

		if SHP.config.SHOW_BOTH then
			local _, _, lh, lw = SHP.GetNetStats()
			local rl, gl, bl = SHP.GetColorFromGradientTable(((lh + lw) / 2) / SHP.config.MS_GRADIENT_THRESHOLD)
			data_FPS.text = format(
				"|cff%02x%02x%02x%.0f|r | |cff%02x%02x%02x%.0f|r",
				rf * 255,
				gf * 255,
				bf * 255,
				fps,
				rl * 255,
				gl * 255,
				bl * 255,
				lw
			)
		else
			data_FPS.text = format("|cff%02x%02x%02x%.0f|r |cffE8D200fps|r", rf * 255, gf * 255, bf * 255, fps)
		end

		elapsedFpsController = SHP.config.UPDATE_PERIOD_DATA_TEXT
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

		local _, _, lh, lw = SHP.GetNetStats()
		local r, g, b = SHP.GetColorFromGradientTable(((lh + lw) / 2) / SHP.config.MS_GRADIENT_THRESHOLD)
		data_Latency.text = format("|cff%02x%02x%02x%.0f/%.0f(w)|r |cffE8D200ms|r", r * 255, g * 255, b * 255, lh, lw)
		elapsedLatencyController = SHP.config.UPDATE_PERIOD_DATA_TEXT
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
--> LATENCY (MS) Data TEXT
----------------------
local function OnEnterLatency(self)
	tipshownLatency = self
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint(SHP.GetTipAnchor(self))
	GameTooltip:ClearLines()

	-- Tooltip Header
	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Latency|r")
	GameTooltip:AddLine("[Bandwidth/Latency]")
	GameTooltip:AddLine(
		format(
			"|cffc3771aDataBroker|r addon shows latency updated every |cff06DDFA%s second(s)|r!\n",
			SHP.config.UPDATE_PERIOD or 30
		)
	)

	-- Network Stats
	local binz, boutz, l, w = SHP.GetNetStats()
	local r, g, b = SHP.GetColorFromGradientTable(((l + w) / 2) / SHP.config.MS_GRADIENT_THRESHOLD)

	-- Latency and Bandwidth Details
	AddColoredDoubleLine("Realm latency:", format("%.0f ms", l), r, g, b)
	AddColoredDoubleLine("Server latency:", format("%.0f ms", w), r, g, b)
	GameTooltip:AddLine(" ")

	-- Bandwidth Information with Color Gradients
	AddColoredDoubleLine("Incoming bandwidth:", format("%.2f kb/sec", binz), SHP.GetColorFromGradientTable(binz / 20))
	AddColoredDoubleLine("Outgoing bandwidth:", format("%.2f kb/sec", boutz), SHP.GetColorFromGradientTable(boutz / 5))

	-- Show Tooltip
	GameTooltip:Show()
	elapsedLatencyController = -10
end

-- On Enter (MS)
data_Latency.OnEnter = OnEnterLatency
-- On Click (MS) Do nothing!
data_Latency.OnClick = function() end

----------------------
--> FPS Data TEXT
----------------------
if not SHP.IsAddOnLoaded("shMem") then
	-- Update addon memory usage without overwriting the entire table
	local function UpdateMemoryUsage()
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
		GameTooltip:AddLine(
			format(
				"|cffc3771aDataBroker|r addon shows memory and fps updated every |cff06DDFA%s second(s)|r!\n",
				SHP.config.UPDATE_PERIOD_TOOLTIP
			)
		)

		-- Column headers
		GameTooltip:AddLine(" ") -- Adds a blank line for spacing
		GameTooltip:AddDoubleLine("Addon name", format("Memory above (|cff06ddfa%s kb|r)", SHP.config.MEM_THRESHOLD))
		GameTooltip:AddDoubleLine("|cffffffff------------|r", "|cffffffff------------|r")

		-- Update memory usage data before displaying
		UpdateMemoryUsage()

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
				local memStr = format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, SHP.formatMem(memUsage))

				-- Display with formatted addon title and colored memory usage
				local counterText = counter < 10 and format("|cffDAB024 %d)|r", counter)
					or format("|cffDAB024%d)|r", counter)
				GameTooltip:AddDoubleLine(format("%s %s", counterText, colorizedTitle), memStr)
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
			format(
				"|cff0DEB11shPerformance|r - Garbage Collected: |cff06ddfa%s|r",
				SHP.formatMem(deltaMemCollected, true)
			)
		)
	end
	data_FPS.OnClick = OnClickFPS
end
