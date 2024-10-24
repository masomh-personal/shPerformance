local _, ns = ...
ns.SHP = {}
local SHP = ns.SHP

--[[----------------CONFIG---------------------
NOTE: data brokers will always update in real time, this is just configuring the tooltip

wantAlphaSorting
	false: sorts addon list by usage (descending)
	true: sorts addon list in alphabetical order

wantColoring
	true: colors addon names AND memusage
	false: just colors memusage and applies them to colors labeled in toc

UPDATEPERIOD
	number (seconds) that your data broker AND tooltip will be updated IMPORTANT!!!! ANYTHING UNDER 2 will likely effect performance!

MEMTHRESH
	number (kb) that will limit addon visibility, anything less than this number will NOT show in tooltip

maxaddons
	max number of addons that will be displayed in tooltip. NOTE: if you are using alphabetical sorting it will NOT display all addons and will
	cut off based on this number.  Keep default value of 100 if you do not want that to happen

showboth
	show both the FPS counter and latency counter in your data text
]]

SHP.config = {
	-- Base config variables (see above comments for details)
	WANT_ALPHA_SORTING = false,
	WANT_COLORING = false,
	UPDATE_PERIOD = 2,
	MEM_THRESHOLD = 50,
	MAX_ADDONS = 40,
	SHOW_BOTH = true,

	-- CONSTANT Thresholds for gradient coloring
	FPS_GRADIENT_THRESHOLD = 75,
	MS_GRADIENT_THRESHOLD = 300,
	MEM_GRADIENT_THRESHOLD = 40,

	-- Addon specific constants (broker icons)
	FPS_ICON = "Interface\\AddOns\\shPerformance\\media\\fpsicon",
	MS_ICON = "Interface\\AddOns\\shPerformance\\media\\msicon",
}

-- Localize commonly used libraries
local math = math
local string = string
local table = table

-- Math, String, and Table functions accessed through the local table
SHP.math = math -- You can access math functions directly (e.g., SHP.math.floor)
SHP.string = string -- You can use string functions directly (e.g., SHP.string.format)
SHP.table = table -- You can use table functions directly (e.g., SHP.table.sort)

-- Game and system-related functions
SHP.GetNetStats = GetNetStats
SHP.GetFramerate = GetFramerate
SHP.collectgarbage = collectgarbage

-- Add-on management functions
SHP.UpdateAddOnMemoryUsage = UpdateAddOnMemoryUsage
SHP.GetAddOnMemoryUsage = GetAddOnMemoryUsage
SHP.GetNumAddOns = C_AddOns.GetNumAddOns
SHP.GetAddOnInfo = C_AddOns.GetAddOnInfo
SHP.IsAddOnLoaded = C_AddOns.IsAddOnLoaded

-- Tooltip references
SHP.GameTooltip = GameTooltip

-- TODO: Static values and icons (really need these?)
-- SHP.prevmem = SHP.collectgarbage("count")
-- SHP.tipshownMem = nil
-- SHP.tipshownLatency = nil

-- Main table to store addon names
SHP.ADDONS_TABLE = {}

-- Function to create and populate the addons table
local function CreateAddonTable()
	-- Get the number of addons
	local numAddOns = SHP.GetNumAddOns()

	-- Iterate through each addon
	for i = 1, numAddOns do
		if SHP.IsAddOnLoaded(i) then
			local name = select(1, SHP.GetAddOnInfo(i))
			SHP.table.insert(SHP.ADDONS_TABLE, name)
		end
	end

	-- Sort the addons table alphabetically, ignoring case
	SHP.table.sort(SHP.ADDONS_TABLE, function(a, b)
		return a:lower() < b:lower()
	end)

	-- Run garbage collection after loading the addons
	SHP.collectgarbage("collect")
end

-- Event frame to trigger addon initialization
local gFrame = CreateFrame("Frame")
gFrame:RegisterEvent("PLAYER_LOGIN")
gFrame:SetScript("OnEvent", function()
	CreateAddonTable()
end)
