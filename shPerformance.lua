if not LibStub then error("shPerformance requires LibStub") end

--[[----------------CONFIG---------------------
NOTE: databrokers will always update in real time, this is just configuring the tooltip

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

local wantAlphaSorting = false
local wantColoring = false
local UPDATEPERIOD = 2
local MEMTHRESH = 50
local maxaddons = 40
local showboth = true
------------------END of CONFIG---------------
-- CONSTANT Thresholds for gradient coloring
local FPSGradientThreshold = 75
local MSGradientThreshhold = 500
local MEMGradientThreshold = 30

local prevmem, tipshownMem, tipshownLatency = collectgarbage("count")
local format, modf, floor, GetNetStats, GetFramerate, collectgarbage, lower = format, math.modf, floor, GetNetStats, GetFramerate, collectgarbage, lower
local UpdateAddOnMemoryUsage, GetAddOnMemoryUsage, GetAddOnInfo, select, sort = UpdateAddOnMemoryUsage, GetAddOnMemoryUsage, C_AddOns.GetAddOnInfo, select, sort
local IsAddOnLoaded, ipairs, insert, print = C_AddOns.IsAddOnLoaded, ipairs, table.insert, print
local GameTooltip, AddLine, AddDoubleLine, abs = GameTooltip, AddLine, AddDoubleLine, math.abs
local fpsIcon = "Interface\\AddOns\\shPerformance\\media\\fpsicon"
local msIcon = "Interface\\AddOns\\shPerformance\\media\\msicon"

---------------------
--> FUNCTIONS
---------------------

--INIT
local addons = {} --main table to manipulate
local gFrame = CreateFrame("frame")
local GetNumAddOns = C_AddOns.GetNumAddOns;
gFrame:RegisterEvent("PLAYER_LOGIN")
gFrame:SetScript("OnEvent", function()
	for i=1,GetNumAddOns(), 1 do
		-- local tester = C_AddOns.GetAddOnEnableState(nil, i) and IsAddOnLoaded(i)
		if IsAddOnLoaded(i) then -->check to see if addon is even enabled/loaded
			local name = select(1, GetAddOnInfo(i))
			insert(addons, name)
		end
	end
	sort(addons, function(a,b) return a and b and a:lower() < b:lower() end)
	collectgarbage("collect")
end)

-->sort based on usage (will check to see what usage in tooltip updater)
local usageSort =  function (a,b)
	return GetAddOnMemoryUsage(a) > GetAddOnMemoryUsage(b)
end

-->Format Mem with stylez
local formatMem = function(mem, x)
	if x then
		if abs(mem) > 1024 then return format("%.2f|cffE8D200M|r", mem/1e3)
		else return format("%.1f|cffE8D200K|r", mem) end
	else
		if mem > 1024 then return format("%.2fM", mem/1e3)
		else return format("%.1fK", mem) end
	end
end

-- http://www.wowwiki.com/ColorGradient
function ColorGradient(perc, ...)
	if perc >= 1 then
		return select(select('#', ...) - 2, ...)
	elseif perc <= 0 then
		return ...
	end

	local num = select('#', ...) / 3
	local segment, relperc = modf(perc*(num-1))
	local r1, g1, b1, r2, g2, b2 = select((segment*3)+1, ...)

	return r1 + (r2-r1)*relperc, g1 + (g2-g1)*relperc, b1 + (b2-b1)*relperc
end

-->tooltip anchor
local UIParent = UIParent
local GetTipAnchor = function(frame)
	local x,y = frame:GetCenter()
	if not x or not y then return "TOPLEFT", "BOTTOMLEFT" end
	local hhalf = (x > UIParent:GetWidth()*2/3) and "RIGHT" or (x < UIParent:GetWidth()/3) and "LEFT" or ""
	local vhalf = (y > UIParent:GetHeight()/2) and "TOP" or "BOTTOM"
	return vhalf..hhalf, frame, (vhalf == "TOP" and "BOTTOM" or "TOP")..hhalf
end

----------------------
--> MODULES AND FRAMES
----------------------
local ffps = CreateFrame("frame")
local flatency = CreateFrame("frame")
local lib = LibStub:GetLibrary("LibDataBroker-1.1")
local datafps = lib:NewDataObject("shFps", { type = "data source", text = "Initializing...fps", icon = fpsIcon })
local datalatency = lib:NewDataObject("shLatency", { type = "data source", text = "Initializing...ms", icon = msIcon })

----------------------
--> ONUPDATE HANDLERS
----------------------

-->shFps OnUpdate script
local elapsedFpsController = -10
ffps:SetScript("OnUpdate", function(self, t)
	elapsedFpsController = elapsedFpsController - t
	if elapsedFpsController < 0 then
		if tipshownMem and not IsAddOnLoaded("shMem") then datafps.OnEnter(tipshownMem) end
		local fps = GetFramerate()
		local r, g, b = ColorGradient(fps/FPSGradientThreshold, 1,0,0, 1,1,0, 0,1,0)

		if showboth then
			local fps = GetFramerate()
			local _, _, lh, lw = GetNetStats()
			local rl, gl, bl = ColorGradient(((lh+lw)/2)/MSGradientThreshhold, 0,1,0, 1,1,0, 1,0,0)
			--datafps.text = format("|cff%02x%02x%02x%.0f|r |cffE8D200fps|r |cff%02x%02x%02x%.0f|r |cffE8D200ms|r", r*255, g*255, b*255, fps, rl*255, gl*255, bl*255, lw)
			datafps.text = format("|cff%02x%02x%02x%.0f|r | |cff%02x%02x%02x%.0f|r", r*255, g*255, b*255, fps, rl*255, gl*255, bl*255, lw)
		else
			--datafps.text = format("|cff%02x%02x%02x%.0f|r |cffE8D200fps|r", r*255, g*255, b*255, fps)
			datafps.text = format("|cff%02x%02x%02x%.0f|r |cffE8D200fps|r", r*255, g*255, b*255, fps)
		end

		elapsedFpsController = UPDATEPERIOD
	end
end)

-->shLatency OnUpdate script
local elapsedLatencyController = -10
flatency:SetScript("OnUpdate", function(self, t)
	elapsedLatencyController = elapsedLatencyController - t
	if elapsedLatencyController < 0 then
		if tipshownLatency then datalatency.OnEnter(tipshownLatency) end
		local _, _, lh, lw = GetNetStats()
		local r, g, b = ColorGradient(((lh+lw)/2)/MSGradientThreshhold, 0,1,0, 1,1,0, 1,0,0)
		datalatency.text = format("|cff%02x%02x%02x%.0f/%.0f(w)|r |cffE8D200ms|r", r*255, g*255, b*255, lh, lw)
		elapsedLatencyController = UPDATEPERIOD + 20 --> blizzard set high update rate on this
	end
end)

----------------------
--> ONLEAVE FUNCTIONS
----------------------
local GameTooltip = GameTooltip
if not IsAddOnLoaded("shMem") then
	function datafps.OnLeave()
		GameTooltip:SetClampedToScreen(true)
		GameTooltip:Hide()
		tipshownMem = nil
	end
end

function datalatency.OnLeave()
	GameTooltip:SetClampedToScreen(true)
	GameTooltip:Hide()
	tipshownLatency = nil
end

----------------------
--> ONENTER FUNCTIONS
----------------------
function datalatency.OnEnter(self)
	tipshownLatency = self
	GameTooltip:SetOwner(self, "ANCHOR_NONE")
	GameTooltip:SetPoint(GetTipAnchor(self))
	GameTooltip:ClearLines()

	GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Latency|r")
	GameTooltip:AddLine("[Bandwidth/Latency]")
	GameTooltip:AddLine(format("|cffc3771aDataBroker|r based addon to show your network latency (ms)\nupdated every |cff06DDFA%s second(s)|r!\n", 30))

	local binz, boutz, l, w = GetNetStats()
	local rin, gin, bins = ColorGradient(binz/20, 0,1,0, 1,1,0, 1,0,0)
	local rout, gout, bout = ColorGradient(boutz/5, 0,1,0, 1,1,0, 1,0,0)
	local r, g, b = ColorGradient(((l+w)/2)/MSGradientThreshhold, 0,1,0, 1,1,0, 1,0,0)

	GameTooltip:AddDoubleLine("|cff42AAFFHOME|r |cffFFFFFFRealm|r |cff0deb11(latency)|r:", format("%.0f ms", l), nil, nil, nil, r, g, b)
	GameTooltip:AddDoubleLine("|cffDCFF42WORLD|r |cffFFFFFFServer|r |cff0deb11(latency)|r:", format("%.0f ms", w), nil, nil, nil, r, g, b)
	GameTooltip:AddLine(" ")
	GameTooltip:AddDoubleLine("|cff06ddfaIncoming bandwidth|r |cff0deb11(download)|r usage:", format("%.2f kb/sec", binz), nil, nil, nil, rin, gin, bins)
	GameTooltip:AddDoubleLine("|cff06ddfaOutgoing bandwidth|r |cff0deb11(upload)|r usage:", format("%.2f kb/sec", boutz), nil, nil, nil, rout, gout, bout)
	elapsedLatencyController = -10
	GameTooltip:Show()
end

function datalatency.OnClick(self)
	return
end

if not IsAddOnLoaded("shMem") then
	function datafps.OnEnter(self)
		tipshownMem = self
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint(GetTipAnchor(self))
		GameTooltip:ClearLines()

		GameTooltip:AddLine("|cff0062ffsh|r|cff0DEB11Performance|r")
		if showboth then
			GameTooltip:AddLine("[Memory/Latency]")
		else
			GameTooltip:AddLine("[Memory]")
		end

		GameTooltip:AddLine(format("|cffc3771aDataBroker|r based addon to show your addon memory\nand fps updated every |cff06DDFA%s second(s)|r!\n", UPDATEPERIOD))
		GameTooltip:AddDoubleLine(" ", " ")
		GameTooltip:AddDoubleLine("Addon name", format("Memory above (|cff06ddfa%s kb|r)", MEMTHRESH))
		GameTooltip:AddDoubleLine("|cffffffff------------|r", "|cffffffff------------|r")

		local counter = 0 -- for numbering (listing) and coloring
		local addonmem = 0
		local hidden, hiddenmem, shownmem = 0, 0, 0

		if wantAlphaSorting == false then
			sort(addons, usageSort) -->sort numerically by usage (descending) if desired
		end

		UpdateAddOnMemoryUsage()
		for i, v in ipairs(addons) do
			local newname
			local mem = GetAddOnMemoryUsage(v)
			local r, g, b = ColorGradient((mem - MEMTHRESH)/15e3, 0,1,0, 1,1,0, 1,0,0)
			addonmem = addonmem + mem
			if mem > MEMTHRESH  and maxaddons > counter then
				counter = counter + 1
				hidden = #addons - counter
				shownmem = shownmem + mem
				newname = select(2,GetAddOnInfo(v))
				local memstr = formatMem(mem)
				if wantColoring then
					if counter < 10 then GameTooltip:AddDoubleLine(format("  |cffDAB024%.0f)|r %s", counter, newname), memstr, r, g, b, r, g, b)
					else GameTooltip:AddDoubleLine(format("|cffDAB024%.0f)|r %s", counter, newname), memstr, r, g, b, r, g, b) end
				else
					if counter < 10 then GameTooltip:AddDoubleLine(format("  |cffDAB024%.0f)|r %s", counter, newname), memstr, 1, 1, 1, r, g, b)
					else GameTooltip:AddDoubleLine(format("|cffDAB024%.0f)|r %s", counter, newname), memstr, 1, 1, 1, r, g, b) end
				end
			end
		end

		hiddenmem = addonmem - shownmem
		if hiddenmem > 0 then
			GameTooltip:AddDoubleLine(format("|cff06DDFA... [%d] hidden addons|r (usage less than %d kb)", hidden, MEMTHRESH), " ")
		end

		local memstr = formatMem(addonmem)
		local mem = collectgarbage("count")
		local deltamem = mem - prevmem
		prevmem = mem

		GameTooltip:AddDoubleLine(" ", "|cffffffff------------|r")
		GameTooltip:AddDoubleLine(" ", format("|cffC3771ATOTAL USER ADDON|r |cffffffffmemory usage:|r  |cff06ddfa%s|r", memstr))
		GameTooltip:AddDoubleLine(" ", format("|cffC3771ADefault Blizzard UI|r |cffffffffmemory usage:|r  |cff06ddfa%s|r", formatMem(mem-addonmem)))
		GameTooltip:AddDoubleLine(" ", " ")

		if showboth then
			local _, _, l, w = GetNetStats()
			--local rin, gin, bins = ColorGradient(binz/20, 0,1,0, 1,1,0, 1,0,0)
			--local rout, gout, bout = ColorGradient(boutz/5, 0,1,0, 1,1,0, 1,0,0)
			local rw, gw, bw = ColorGradient((w/MSGradientThreshhold), 0,1,0, 1,1,0, 1,0,0)
			local rl, gl, bl = ColorGradient((l/MSGradientThreshhold), 0,1,0, 1,1,0, 1,0,0)

			GameTooltip:AddDoubleLine(" ", format("|cff42AAFFHOME|r |cffFFFFFFRealm (latency)|r:  %.0f ms", l), nil, nil, nil, rl, gl, bl)
			GameTooltip:AddDoubleLine(" ", format("|cffDCFF42WORLD|r |cffFFFFFFServer (latency)|r:  %.0f ms", w), nil, nil, nil, rw, gw, bw)
			GameTooltip:AddDoubleLine(" ", " ")
		end

		r, g, b = ColorGradient(deltamem/MEMGradientThreshold, 0,1,0, 1,1,0, 1,0,0)
		GameTooltip:AddDoubleLine("|cffc3771aGarbage|r churn", format("%.2f kb/sec", deltamem), nil,nil,nil, r,g,b)
		GameTooltip:AddLine("*Click to force |cffc3771agarbage|r collection and to |cff06ddfaupdate|r tooltip*")

		elapsedFpsController = -10
		GameTooltip:Show()
	end

	function datafps.OnClick(self)
		datafps.OnEnter(self) -->updates tooltip
		local collected, deltamem = 0, 0
		collected = collectgarbage('count')
		collectgarbage("collect")
		UpdateAddOnMemoryUsage()
		deltamem = collected - collectgarbage('count')
		print(format("|cff0DEB11shPerformance|r - |cffC3771AGarbage|r Collected: |cff06ddfa%s|r", formatMem(deltamem, true)))
	end
end
