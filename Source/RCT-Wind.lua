--[[
	---------------------------------------------------------
                    RCT WindSpeed
    
    RCT WindSpeed is a lua-app counting wind speed model 
    experiences in the air from air-speed and ground-speed.
    
    Requires transmitter firmware 4.22 or higher.
    
    Works in DC/DS-14/16/24 with firmware 4.22 and up
	---------------------------------------------------------
	Localization-file has to be as /Apps/Lang/RCT-Wind.jsn
    
    Voice-files has to be as follows:
    Headwind-file: /Apps/Voices/Headwind.wav
    Tailwind-file: /Apps/Voices/Tailwind.wav
	---------------------------------------------------------
	RCT WindSpeed is part of RC-Thoughts Jeti Tools.
	---------------------------------------------------------
	Released under MIT-license by Tero @ RC-Thoughts.com 2018
	---------------------------------------------------------
--]]
--------------------------------------------------------------------------------
-- Locals for application
local airSpeedSensId, airSpeedSensPa, groundSpeedSensId, groundSpeedSensPa
local airSpeed, groundSpeed, windSpeed, windMin, windMax, windSw = 0, 0, 0, 0, 0
local sensorsAvailable, playDone, playTime, timeNow = {"..."}, false, 0, 0
local windUnit, airValid, unitStore, unitStoreDone = "", false, "", false
--------------------------------------------------------------------------------
-- Read and set translations
local function setLanguage()
    local lng=system.getLocale()
    local file = io.readall("Apps/Lang/RCT-Wind.jsn")
    local obj = json.decode(file)
    if(obj) then
        trans24 = obj[lng] or obj[obj.default]
    end
end
----------------------------------------------------------------------
-- Draw telemetry screen for main display
local function printWind()
    if(airValid) then
        if(windSpeed < 0) then
            lcd.drawText(77 - lcd.getTextWidth(FONT_NORMAL,"Headwind:"),2,"Headwind:",FONT_NORMAL)
            else
            lcd.drawText(66 - lcd.getTextWidth(FONT_NORMAL,"Tailwind:"),2,"Tailwind:",FONT_NORMAL)
        end
        if(windSpeed < 0) then
            windSpeed = windSpeed * -1
        end
        lcd.drawText(145 - lcd.getTextWidth(FONT_BIG,string.format("%.1f", windSpeed)),0,string.format("%.1f", windSpeed),FONT_BIG)
    else
        lcd.drawText(30 - lcd.getTextWidth(FONT_NORMAL,"N/A"),2,"N/A",FONT_NORMAL)
        lcd.drawText(145 - lcd.getTextWidth(FONT_BIG,"-"),0,"-",FONT_BIG)
    end
end
----------------------------------------------------------------------
-- Actions when settings changed
local function airSpeedSensChanged(value)
    local pSave = system.pSave
	airSpeedSensId  = sensorsAvailable[value].id
	airSpeedSensPa  = sensorsAvailable[value].param
	pSave("airSpeedSensId", airSpeedSensId)
	pSave("airSpeedSensPa", airSpeedSensPa)
end

local function groundSpeedSensChanged(value)
    local pSave = system.pSave
	groundSpeedSensId  = sensorsAvailable[value].id
    groundSpeedSensPa  = sensorsAvailable[value].param
	pSave("groundSpeedSensId", groundSpeedSensId)
    pSave("groundSpeedSensPa", groundSpeedSensPa)
end

local function windSwChanged(value)
    local pSave = system.pSave
	windSw = value
	pSave("windSw", value)
end
--------------------------------------------------------------------------------
-- Draw the main form (Application inteface)
local function initForm()
    local form, addRow, addLabel = form, form.addRow ,form.addLabel
    local addSelectbox, addInputbox = form.addSelectbox, form.addInputbox 
    -- List sensors only if menu is active to preserve memory at runtime 
    -- (measured up to 25% save if menu is not opened)
    sensorsAvailable = {}
    local sensors = system.getSensors();
    local list={}
    local curIndex1, curIndex2 = -1, -1
    local descr = ""
    for index,sensor in ipairs(sensors) do 
        if(sensor.param == 0) then
            descr = sensor.label
            else
            list[#list + 1] = string.format("%s - %s", descr, sensor.label)
            sensorsAvailable[#sensorsAvailable + 1] = sensor
           	if(sensor.id == airSpeedSensId and sensor.param == airSpeedSensPa) then
                curIndex1 =# sensorsAvailable
            end
            if(sensor.id == groundSpeedSensId and sensor.param == groundSpeedSensPa) then
                curIndex2 =# sensorsAvailable
            end
        end
    end
    
    addRow(1)
    addLabel({label="---     RC-Thoughts Jeti Tools      ---",font=FONT_BIG})
    
    addRow(1)
    addLabel({label=trans24.labelSensor,font=FONT_BOLD})
    
    addRow(2)
    addLabel({label=trans24.airSpeedLbl, width=200})
    addSelectbox(list, curIndex1, true, airSpeedSensChanged)
    
    addRow(2)
    addLabel({label=trans24.groundSpeedLbl, width=200})
    addSelectbox(list, curIndex2, true, groundSpeedSensChanged)
    
    addRow(1)
    addLabel({label=trans24.labelOther,font=FONT_BOLD})
    
    addRow(2)
    addLabel({label=trans24.windSw, width=220})
    addInputbox(windSw, true, windSwChanged)
    
    addRow(1)
    addLabel({label="Powered by RC-Thoughts.com - v."..windSpeedVersion.." ", font=FONT_MINI, alignRight=true})
    collectgarbage()
end
--------------------------------------------------------------------------------
local function loop()
    -- Setting basic stuff like time % read values
    timeNow = system.getTimeCounter()
    local air = system.getSensorByID(airSpeedSensId, airSpeedSensPa)
    local ground = system.getSensorByID(groundSpeedSensId, groundSpeedSensPa)
    startAnnounce = system.getInputsVal(windSw)
    -- Calculate wind speed only if we have valid sensors-values
    if(air and air.valid and ground and ground.valid) then
        airValid = true
        windSpeed = ground.value - air.value
        -- Get windspeed unit from sensor
        windUnit = string.format("%s", air.unit)
        -- If unit is km/h calculate windspeed to m/s (mph-user get windspeed in mph)
        if(windUnit == "km/h") then
            windUnit = "m/s"
            windSpeed = windSpeed * 1000 / 3600
        end
        -- Windspeed value for transmitter log-file
        windSpeedLog = windSpeed
        -- Taking care of announcement
        if(not playDone and startAnnounce == 1) then
            if(windSpeed < 0)then
                system.playFile("/Apps/Voice/Headwind.wav", AUDIO_QUEUE)
                system.playNumber((windSpeed * -1), 1, windUnit)
            else
                system.playFile("/Apps/Voice/Tailwind.wav", AUDIO_QUEUE)
                system.playNumber(windSpeed, 1, windUnit)
            end
            playTime = timeNow + 5000
            playDone = true
        end
    else
        airValid = false
        unitStoreDone = false
    end
    -- Reset playtimer
    if(timeNow > playTime and playDone) then
        playDone = false
        playTime = 0
    end
    -- Set value for logging
    windSpeedLog = windSpeed
    -- Store windspeed unit for logs (Effective from second use!)
    if(windUnit ~= "" and not unitStoreDone) then
        system.pSave("unitStore", windUnit)
        unitStoreDone = true
    end
    collectgarbage()
end
--------------------------------------------------------------------------------
local function init()
    local pLoad, registerForm, registerTelemetry = system.pLoad, system.registerForm, system.registerTelemetry
	windSw = pLoad("windSw")
    unitStore = pLoad("unitStore", "")
    airSpeedSensId = pLoad("airSpeedSensId", 0)
    airSpeedSensPa = pLoad("airSpeedSensPa", 0)
    groundSpeedSensId = pLoad("groundSpeedSensId", 0)
    groundSpeedSensPa = pLoad("groundSpeedSensPa", 0)
    windLabel = pLoad("cntLb1",trans24.appName)
    system.registerLogVariable("Wind Speed",unitStore,(
        function(index)
            result = windSpeedLog * 100
            return result, 2
        end
        )
    )
    system.registerTelemetry(1,windLabel,1,printWind)
    registerForm(1, MENU_APPS, trans24.appName, initForm)
    collectgarbage()
end
--------------------------------------------------------------------------------
windSpeedVersion = "1.0"
setLanguage()
collectgarbage()
return {init=init, loop=loop, author="RC-Thoughts", version=windSpeedVersion, name=trans24.appName}