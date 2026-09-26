local addonName, ns = ...
local SHP = ns.SHP

local C_AddOns = C_AddOns
local CreateFrame = CreateFrame
local ipairs = ipairs
local pcall = pcall
local print = print
local string_format = string.format
local type = type

local function runDiagnostics()
	local tests = {
		{
			name = "Gradient boundaries",
			run = function()
				local lowR, lowG, lowB = SHP.GetColorFromGradientTable(0)
				local highR, highG, highB = SHP.GetColorFromGradientTable(1)
				return type(lowR) == "number"
					and type(lowG) == "number"
					and type(lowB) == "number"
					and type(highR) == "number"
					and type(highG) == "number"
					and type(highB) == "number"
					and lowG > lowR
					and highR > highG
			end,
		},
		{
			name = "Gradient colorizer",
			run = function()
				local low = SHP.ColorizeByProportion(0, "x")
				local clamped = SHP.ColorizeByProportion(5, "x")
				return low:match("^|cff%x%x%x%x%x%xx|r$") ~= nil and clamped == SHP.ColorizeByProportion(1, "x")
			end,
		},
		{
			name = "Memory formatting",
			run = function()
				return SHP.FormatMemString(512) == "512.00K" and SHP.FormatMemString(1024) == "1.00M"
			end,
		},
		{
			name = "Required WoW APIs",
			run = function()
				return type(GetFramerate) == "function"
					and type(GetNetStats) == "function"
					and type(UpdateAddOnMemoryUsage) == "function"
					and type(GetAddOnMemoryUsage) == "function"
					and type(C_Timer.NewTicker) == "function"
					and type(GameTooltip.IsOwned) == "function"
			end,
		},
		{
			name = "LibDataBroker feeds",
			run = function()
				return SHP.LDB:GetDataObjectByName("shPerformance") ~= nil
					and SHP.LDB:GetDataObjectByName("shFps") ~= nil
					and SHP.LDB:GetDataObjectByName("shLatency") ~= nil
			end,
		},
		{
			name = "Safe addon memory entries",
			run = function()
				for _, addon in ipairs(SHP.ADDONS_TABLE) do
					if
						type(addon.name) ~= "string"
						or type(addon.sortKey) ~= "string"
						or addon.index ~= nil
						or type(addon.memory) ~= "number"
					then
						return false
					end
				end
				return true
			end,
		},
		{
			name = "Plain alphabetical sort keys",
			run = function()
				for _, addon in ipairs(SHP.ADDONS_TABLE) do
					if addon.sortKey:find("|", 1, true) or addon.sortKey ~= addon.sortKey:lower() then
						return false
					end
				end
				return true
			end,
		},
		{
			name = "Addon memory refresh",
			run = function()
				SHP.UpdateUserAddonMemoryUsageTable()
				for _, addon in ipairs(SHP.ADDONS_TABLE) do
					if addon.memory < 0 then
						return false
					end
				end
				return true
			end,
		},
	}

	local results = {}
	for _, test in ipairs(tests) do
		local completed, passed = pcall(test.run)
		results[#results + 1] = {
			name = test.name,
			passed = completed and passed == true,
		}
	end

	return results
end

local ROW_TOP, ROW_HEIGHT, FRAME_CHROME_HEIGHT = -45, 27, 88

local dashboard
local rows = {}

local function getRow(index)
	local row = rows[index]
	if not row then
		row = dashboard:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row:SetPoint("TOPLEFT", 28, ROW_TOP - ((index - 1) * ROW_HEIGHT))
		row:SetJustifyH("LEFT")
		rows[index] = row
	end
	return row
end

local function createDashboard()
	local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	frame:SetWidth(380)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		edgeSize = 24,
		insets = { left = 6, right = 6, top = 6, bottom = 6 },
	})

	local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	title:SetPoint("TOP", 0, -18)
	local version = C_AddOns.GetAddOnMetadata(addonName, "Version")
	title:SetText(string_format("shPerformance %s diagnostics", version or ""))

	local closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	closeButton:SetPoint("TOPRIGHT", -4, -4)

	local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	hint:SetPoint("BOTTOM", 0, 18)
	hint:SetText("Run again with /shperformance test")

	return frame
end

local function showDashboard()
	dashboard = dashboard or createDashboard()

	local results = runDiagnostics()
	for index, result in ipairs(results) do
		local status = result.passed and "PASS" or "FAIL"
		local color = result.passed and "|cff00ff00" or "|cffff4040"
		getRow(index):SetText(string_format("%s%s|r  %s", color, status, result.name))
	end
	dashboard:SetHeight(FRAME_CHROME_HEIGHT + #results * ROW_HEIGHT)

	dashboard:Show()
end

SLASH_SHPERFORMANCE1 = "/shperformance"
SLASH_SHPERFORMANCE2 = "/shp"
SlashCmdList.SHPERFORMANCE = function(message)
	local command = message:match("^%s*(.-)%s*$"):lower()
	if command == "test" then
		showDashboard()
		return
	end

	print("shPerformance: use /shperformance test")
end
