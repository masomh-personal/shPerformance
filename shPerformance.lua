local _, ns = ...
local SHP = ns.SHP

-- Localize: Tooltip variables
local GameTooltip = GameTooltip

----------------------
--> Module Frames and Update Controllers
----------------------
local FRAME_FPS = CreateFrame("frame")
local elapsedFpsController = 0

local DATA_TEXT_FPS = SHP.LibStub:NewDataObject("shFps", {
	type = "data source",
	text = "Initializing (fps)",
	icon = SHP.config.FPS_ICON,
})

----------------------
--> Helper Functions
----------------------
-- Helper function to get formatted FPS
local function getFormattedFPS()
	local fps = SHP.GetFramerate()
	local rf, gf, bf = SHP.GetFPSColor(fps)
	return SHP.ColorizeText(rf, gf, bf, SHP.string.format("%.0f fps", fps))
end

-- Helper function to get formatted memory data
local function getFormattedMemoryData()
	SHP.UpdateUserAddonMemoryUsageTable()
	local totalMemory = 0
	local formattedData = {}

	-- Sort addon memory usage
	SHP.table.sort(SHP.ADDONS_TABLE, function(a, b)
		if SHP.config.WANT_ALPHA_SORTING then
			return a.colorizedTitle:lower() < b.colorizedTitle:lower()
		else
			return a.memory > b.memory
		end
	end)

	-- Build memory data table
	for _, addon in ipairs(SHP.ADDONS_TABLE) do
		local addonMemory = addon.memory
		if addonMemory > SHP.config.MEM_THRESHOLD then
			local r, g, b = SHP.GetColorFromGradientTable((addonMemory - SHP.config.MEM_THRESHOLD) / 15e3)
			local memStr = SHP.ColorizeText(r, g, b, SHP.formatMem(addonMemory))
			SHP.table.insert(formattedData, { addon.colorizedTitle, memStr })
		end
		totalMemory = totalMemory + addonMemory
	end

	return formattedData, totalMemory
end

-- Helper function to update data text for FPS display
local function updateDataText()
	local fpsText = getFormattedFPS()
	DATA_TEXT_FPS.text = fpsText
end

-- Helper function to update tooltip content
local function updateTooltipContent()
	GameTooltip:ClearLines()
	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Performance|r")
	GameTooltip:AddLine(SHP.config.SHOW_BOTH and "[Memory/Latency]" or "[Memory]")
	GameTooltip:AddLine("|cffc3771aDATABROKER|r tooltip showing sorted memory usage")
	SHP.AddToolTipLineSpacer()

	-- Use helper function to add formatted memory data
	local formattedMemoryData, totalMemory = getFormattedMemoryData()

	-- Add memory details to the tooltip
	for _, data in ipairs(formattedMemoryData) do
		GameTooltip:AddDoubleLine(data[1], data[2])
	end

	-- Display total user addon memory usage
	SHP.AddToolTipLineSpacer()
	GameTooltip:AddDoubleLine(
		" ",
		SHP.string.format("|cffC3771ATOTAL ADDON|r memory usage → |cff06ddfa%s|r", SHP.formatMem(totalMemory))
	)

	-- Display hint for garbage collection
	SHP.AddToolTipLineSpacer()
	GameTooltip:AddLine("→ *Click to force |cffc3771agarbage|r collection and to |cff06ddfaupdate|r tooltip*")
	GameTooltip:Show()
end

----------------------
--> Frame Scripts
----------------------
-- Update FPS data text in real time
FRAME_FPS:SetScript("OnUpdate", function(_, t)
	elapsedFpsController = elapsedFpsController + t
	if elapsedFpsController >= SHP.config.UPDATE_PERIOD_FPS_DATA_TEXT then
		elapsedFpsController = 0
		updateDataText()
	end
end)

-- Use helper function in OnEnter to update tooltip in real time
local function OnEnterFPS(self)
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint(SHP.GetTipAnchor(self))
	updateTooltipContent() -- Initial call to display tooltip content

	-- Set up OnUpdate to refresh tooltip content in real time while hovered
	local elapsed = 0
	self:SetScript("OnUpdate", function(_, t)
		elapsed = elapsed + t
		if elapsed >= SHP.config.UPDATE_PERIOD_TOOLTIP then
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
			SHP.formatMem(deltaMemCollected, true)
		)
	)
end
DATA_TEXT_FPS.OnClick = OnClickFPS
