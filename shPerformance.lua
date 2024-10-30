local _, ns = ...
local SHP = ns.SHP

----------------------
--> Module Frames and Update Controllers
----------------------
local FRAME_FPS = CreateFrame("frame")

-- Adding one to update period to ensure first and immediate update
local elapsedFpsController = SHP.CONFIG.UPDATE_PERIOD_FPS_DATA_TEXT + 1
local elapsedLatencyController = SHP.CONFIG.UPDATE_PERIOD_LATENCY_DATA_TEXT + 1

-- Since we are using latency information, get it immediately b/c it won't be updated for 30 seconds in OnUpdateScript
local cachedLatencyText = "Initializing ms..."

local DATA_TEXT_FPS = SHP.LibStub:NewDataObject("shFps", {
	type = "data source",
	text = "Initializing (fps)",
	icon = SHP.CONFIG.FPS_ICON,
})

----------------------
--> Helper Functions
----------------------
-- Helper function to get formatted memory data
local function getFormattedMemoryData()
	SHP.UpdateUserAddonMemoryUsageTable()
	local totalMemory = 0
	local formattedData = {}

	-- Sort addon memory usage
	SHP.table.sort(SHP.ADDONS_TABLE, function(a, b)
		if SHP.CONFIG.WANT_ALPHA_SORTING then
			return a.colorizedTitle:lower() < b.colorizedTitle:lower()
		else
			return a.memory > b.memory
		end
	end)

	-- Build memory data table
	for _, addon in ipairs(SHP.ADDONS_TABLE) do
		local addonMemory = addon.memory
		if addonMemory > SHP.CONFIG.MEM_THRESHOLD then
			-- Memory thresholds in KB
			local minMemory = 1 -- Minimum memory usage (1 KB)
			local maxMemory = SHP.CONFIG.MEM_GRADIENT_THRESHOLD_MAX -- Maximum memory usage (100 MB in KB)

			-- Calculate proportion for gradient
			local memoryProportion = (addonMemory - minMemory) / (maxMemory - minMemory)
			memoryProportion = math.max(0, math.min(memoryProportion, 1)) -- Clamp between 0 and 1

			-- Retrieve color based on proportion
			local r, g, b = SHP.GetColorFromGradientTable(memoryProportion)
			local memStr = SHP.ColorizeText(r, g, b, SHP.formatMemString(addonMemory))
			SHP.table.insert(formattedData, { addon.colorizedTitle, memStr })
		end
		totalMemory = totalMemory + addonMemory
	end

	return formattedData, totalMemory
end

-- Helper function to update data text for FPS display
local function updateDataText()
	local fpsText = SHP.UpdateFPSDataText()
	DATA_TEXT_FPS.text = SHP.string.format("%s | %s", fpsText, cachedLatencyText)
end

-- Helper function to update tooltip content
local function updateTooltipContent()
	SHP.GameTooltip:ClearLines()
	SHP.GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Performance|r")
	SHP.GameTooltip:AddLine(SHP.CONFIG.SHOW_BOTH and "[Memory/Latency]" or "[Memory]")
	SHP.AddLineSeparatorToTooltip()
	SHP.AddNetworkStatsToTooltip()

	-- Use helper function to add formatted memory data
	local formattedMemoryData, totalMemory = getFormattedMemoryData()

	-- Add memory details to the tooltip
	for _, data in ipairs(formattedMemoryData) do
		SHP.GameTooltip:AddDoubleLine(data[1], data[2])
	end

	-- Display total user addon memory usage
	SHP.AddLineSeparatorToTooltip()
	SHP.GameTooltip:AddDoubleLine(
		" ",
		SHP.string.format("|cffC3771ATOTAL ADDON|r memory usage → |cff06ddfa%s|r", SHP.formatMemString(totalMemory))
	)

	-- Display hint for garbage collection
	SHP.AddLineSeparatorToTooltip()
	SHP.GameTooltip:AddLine("→ *Click to force |cffc3771agarbage|r collection and to |cff06ddfaupdate|r tooltip*")
	SHP.GameTooltip:Show()
end

----------------------
--> Frame Scripts
----------------------
-- Update FPS data text in real time
FRAME_FPS:SetScript("OnUpdate", function(_, t)
	elapsedFpsController = elapsedFpsController + t
	elapsedLatencyController = elapsedLatencyController + t

	-- Update latency text every 30 seconds only due to Blizzard limitations
	if elapsedLatencyController >= SHP.CONFIG.UPDATE_PERIOD_LATENCY_DATA_TEXT then
		elapsedLatencyController = 0
		cachedLatencyText = SHP.UpdateLatencyDataText()
	end

	if elapsedFpsController >= SHP.CONFIG.UPDATE_PERIOD_FPS_DATA_TEXT then
		elapsedFpsController = 0
		updateDataText()
	end
end)

-- Use helper function in OnEnter to update tooltip in real time
local function OnEnterFPS(self)
	SHP.GameTooltip:SetOwner(self, "ANCHOR_NONE")
	SHP.GameTooltip:SetPoint(SHP.GetTipAnchor(self))
	updateTooltipContent() -- Initial call to display tooltip content

	-- Set up OnUpdate to refresh tooltip content in real time while hovered
	local elapsed = 0
	self:SetScript("OnUpdate", function(_, t)
		elapsed = elapsed + t
		if elapsed >= SHP.CONFIG.UPDATE_PERIOD_TOOLTIP then
			elapsed = 0
			updateTooltipContent() -- Refresh tooltip content
		end
	end)
end
DATA_TEXT_FPS.OnEnter = OnEnterFPS

-- Clear the `OnUpdate` handler when the tooltip is no longer hovered
local function OnLeaveFPS(self)
	SHP.HideTooltip()
	self:SetScript("OnUpdate", nil)
end
DATA_TEXT_FPS.OnLeave = OnLeaveFPS

-- OnClick handler for garbage collection
local function OnClickFPS()
	local preCollect = SHP.collectgarbage("count")
	SHP.collectgarbage("collect")
	local deltaMemCollected = preCollect - SHP.collectgarbage("count")

	-- Display the amount of memory collected
	print(
		SHP.string.format(
			"|cff0DEB11shPerformance|r - Garbage Collected: |cff06ddfa%s|r",
			SHP.formatMemString(deltaMemCollected, true)
		)
	)
end
DATA_TEXT_FPS.OnClick = OnClickFPS
