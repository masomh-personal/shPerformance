local _, ns = ...
local SHP = ns.SHP

local C_AddOns = C_AddOns
local C_Timer = C_Timer
local GameTooltip = GameTooltip
local GetAddOnMemoryUsage = GetAddOnMemoryUsage
local GetFramerate = GetFramerate
local GetNetIpTypes = GetNetIpTypes
local GetNetStats = GetNetStats
local UIParent = UIParent
local UpdateAddOnMemoryUsage = UpdateAddOnMemoryUsage
local ipairs = ipairs
local math_floor = math.floor
local math_max = math.max
local math_min = math.min
local string_format = string.format

local CONFIG = SHP.CONFIG
local GRADIENT_TABLE = SHP.GRADIENT_TABLE
local IP_TYPES = { "IPv4", "IPv6" }

--[[
	Formats memory usage with optional color coding.
	@param mem: Memory value in kilobytes (number).
	@param useColor: Boolean to determine if the formatted output should be colored.
	@return: Formatted string with memory value in either "K" or "M" units, colored if specified.
]]
SHP.FormatMemString = function(mem, useColor)
	local isMB = mem >= 1024
	local unit = isMB and "M" or "K"
	local formattedMem = isMB and mem / 1024 or mem

	return useColor and string_format("%.2f|cffE8D200%s|r", formattedMem, unit)
		or string_format("%.2f%s", formattedMem, unit)
end

local function getGradientEntry(proportion)
	return GRADIENT_TABLE[math_min(100, math_max(0, math_floor(proportion * 100 + 0.5)))]
end

SHP.GetColorFromGradientTable = function(proportion)
	local entry = getGradientEntry(proportion)
	return entry.r, entry.g, entry.b
end

--[[
	Wraps text in the gradient color for a 0-1 proportion (values outside the range are clamped).
	@return: Color-escaped string.
]]
SHP.ColorizeByProportion = function(proportion, text)
	return "|cff" .. getGradientEntry(proportion).hex .. text .. "|r"
end

SHP.GetTipAnchor = function(frame)
	local x, y = frame:GetCenter()
	if not x or not y then
		return "TOPLEFT", frame, "BOTTOMLEFT"
	end

	local screenWidth = UIParent:GetWidth()
	local screenHeight = UIParent:GetHeight()

	local hPos = (x > screenWidth * 0.66) and "RIGHT" or (x < screenWidth * 0.33) and "LEFT" or ""
	local vPos = (y > screenHeight * 0.5) and "TOP" or "BOTTOM"

	return vPos .. hPos, frame, (vPos == "TOP" and "BOTTOM" or "TOP") .. hPos
end

--[[
	Wires LDB OnEnter/OnLeave to show and periodically refresh GameTooltip.
	The display addon owns the hovered frame, so no scripts or fields are set on it;
	refreshes stop as soon as another element takes ownership of GameTooltip.
	@param renderTooltip: Function that clears, fills, and shows GameTooltip.
]]
SHP.AttachTooltipHandlers = function(dataObject, renderTooltip)
	local owner, ticker

	local function stopRefresh()
		if ticker then
			ticker:Cancel()
			ticker = nil
		end
		owner = nil
	end

	local function refresh()
		if owner and GameTooltip:IsOwned(owner) then
			renderTooltip()
		else
			stopRefresh()
		end
	end

	dataObject.OnEnter = function(frame)
		stopRefresh()
		owner = frame
		GameTooltip:SetOwner(frame, "ANCHOR_NONE")
		GameTooltip:SetPoint(SHP.GetTipAnchor(frame))
		renderTooltip()
		ticker = C_Timer.NewTicker(CONFIG.UPDATE_PERIOD_TOOLTIP, refresh)
	end

	dataObject.OnLeave = function(frame)
		if owner == frame then
			stopRefresh()
		end
		if GameTooltip:IsOwned(frame) then
			GameTooltip:Hide()
		end
	end
end

--[[
	Adds a line spacer to the tooltip. Optionally adds a dashed line if dashedSpacer is true.
	@param dashedSpacer: Boolean value; if true, adds a dashed line. Otherwise, adds a blank line.
--]]
SHP.AddLineSeparatorToTooltip = function(dashedSpacer)
	if dashedSpacer then
		GameTooltip:AddDoubleLine("|cffffffff————|r", "|cffffffff————|r")
	else
		GameTooltip:AddLine(" ")
	end
end

--[[
	Refreshes WoW's addon memory snapshot and updates `memory` and `isLoaded`
	for each entry in `SHP.ADDONS_TABLE` in place.
--]]
SHP.UpdateUserAddonMemoryUsageTable = function()
	UpdateAddOnMemoryUsage()

	for _, addonData in ipairs(SHP.ADDONS_TABLE) do
		-- Names remain valid if the client changes addon index ordering.
		addonData.memory = GetAddOnMemoryUsage(addonData.name) or 0
		addonData.isLoaded = C_AddOns.IsAddOnLoaded(addonData.name) and true or false
	end
end

--[[
	Adds colorized latency and bandwidth statistics to the shared game tooltip.
]]
SHP.AddNetworkStatsToTooltip = function()
	local bandwidthIn, bandwidthOut, latencyHome, latencyWorld = GetNetStats()
	local ipTypeHome, ipTypeWorld = GetNetIpTypes()

	GameTooltip:AddDoubleLine(
		string_format("|cff42AAFFHOME (%s)|r |cffFFFFFFlatency:|r", IP_TYPES[ipTypeHome] or UNKNOWN),
		SHP.ColorizeByProportion(latencyHome / CONFIG.MS_GRADIENT_THRESHOLD, string_format("%.0f ms", latencyHome))
	)
	GameTooltip:AddDoubleLine(
		string_format("|cffDCFF42WORLD (%s)|r |cffFFFFFFlatency:|r", IP_TYPES[ipTypeWorld] or UNKNOWN),
		SHP.ColorizeByProportion(latencyWorld / CONFIG.MS_GRADIENT_THRESHOLD, string_format("%.0f ms", latencyWorld))
	)

	SHP.AddLineSeparatorToTooltip(true)

	GameTooltip:AddDoubleLine(
		"|cff00FFFFIncoming|r |cffFFFFFFbandwidth:|r",
		SHP.ColorizeByProportion(
			bandwidthIn / CONFIG.BANDWIDTH_INCOMING_GRADIENT_THRESHOLD,
			string_format("▼ %.2f KB/s", bandwidthIn)
		)
	)
	GameTooltip:AddDoubleLine(
		"|cff00FFFFOutgoing|r |cffFFFFFFbandwidth:|r",
		SHP.ColorizeByProportion(
			bandwidthOut / CONFIG.BANDWIDTH_OUTGOING_GRADIENT_THRESHOLD,
			string_format("▲ %.2f KB/s", bandwidthOut)
		)
	)
end

local function formatFpsText()
	local fps = GetFramerate()
	return SHP.ColorizeByProportion(1 - fps / CONFIG.FPS_GRADIENT_THRESHOLD, string_format("%.0f", fps))
end

local function formatLatencyText()
	local _, _, latencyHome, latencyWorld = GetNetStats()
	local home =
		SHP.ColorizeByProportion(latencyHome / CONFIG.MS_GRADIENT_THRESHOLD, string_format("%.0f", latencyHome))
	local world = SHP.ColorizeByProportion(
		latencyWorld / CONFIG.MS_GRADIENT_THRESHOLD,
		string_format("%.0f (world)", latencyWorld)
	)
	return home .. " → " .. world
end

-- Each feed registers listeners so shared stats are sampled and formatted once per tick.
local fpsListeners, latencyListeners = {}, {}

SHP.OnFpsUpdate = function(listener)
	fpsListeners[#fpsListeners + 1] = listener
end

SHP.OnLatencyUpdate = function(listener)
	latencyListeners[#latencyListeners + 1] = listener
end

local function notify(listeners, text)
	for _, listener in ipairs(listeners) do
		listener(text)
	end
end

local function updateFps()
	notify(fpsListeners, formatFpsText())
end

local function updateLatency()
	notify(latencyListeners, formatLatencyText())
end

--[[
	Publishes an immediate first update, then starts the FPS and latency tickers.
	Latency runs first so combined feeds already have it when FPS renders.
]]
SHP.StartFeeds = function()
	updateLatency()
	updateFps()
	C_Timer.NewTicker(CONFIG.UPDATE_PERIOD_LATENCY_DATA_TEXT, updateLatency)
	C_Timer.NewTicker(CONFIG.UPDATE_PERIOD_FPS_DATA_TEXT, updateFps)
end
