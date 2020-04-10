-- Monitors and controls different parts of a mobfarm
-- Assumes that a monitor is attached to the top of the computer
-- fans are attached via redstone on the bottom
-- and that a modem is attached on the back
local monitorSide = "top"
local fanSide = "bottom"
local modemSide = "back"
local apiPath = "/usr/apis/touchpoint"

-- Moving global objects to local for optimization
local string = string
local stringRep = string.rep
local fs = fs
local fsExists = fs.exists
local fsOpen = fs.open
local shellRun = shell.run
local peripheral = peripheral
local peripheralIsPresent = peripheral.isPresent
local os = os
local osPullEventRaw = os.pullEventRaw
local colors = colors
local colorsBlack = colors.black
local colorsGreen = colors.green
local colorsGray = colors.gray
local tostring = tostring
local stringSub = string.sub
local mathFloor = math.floor
local rsSetOutput = rs.setOutput
local rednet = rednet
local rednetBroadcast = rednet.broadcast
local table = table
local tableInsert = table.insert
local tableSort = table.sort

-- Constants
local tankWidth = 19
local tankBarHeight = 20

local topItemsWidth = 49
local topItemsHeight = 15

-- String constants
local tankLabel = "ESSENSE"
local tankLabelLen = #tankLabel
local tankLabelBackground = stringRep("=", tankWidth)
local tankBlank = stringRep(" ", tankWidth)

local topItemsLabel = "TOP ITEMS"
local topItemsLabelLen = #topItemsLabel
local topItemsLabelBackground = stringRep("=", topItemsWidth)
local topItemsBlank = stringRep(" ", topItemsWidth)
local topItemsItemsSuffix = " items"
local topItemsItemsSuffixLen = #topItemsItemsSuffix

-- Check if touchpoint is installed
if not fsExists(apiPath) then
    print("touchpoint is not installed; installing...")
    shellRun("pastebin run 4zyreNZy")
    shellRun("packman install touchpoint")
end

os.loadAPI("/usr/apis/touchpoint")

-- Check peripherals are where we expect them to be
if not peripheralIsPresent(monitorSide) then
    error("Monitor is not present")
elseif not peripheralIsPresent(modemSide) then
    error("Modem is not present")
end

local mon = peripheral.wrap(monitorSide)
local monSetBackgroundColor = mon.setBackgroundColor
local monSetCursorPos = mon.setCursorPos
local monWrite = mon.write

local tankLevel = 0
local function drawGraph()

    -- Draw essense label
    monSetBackgroundColor(colorsBlack)
    monSetCursorPos(52, 2)
    monWrite(tankLabelBackground)
    monSetCursorPos(52 + ((tankWidth / 2) - (tankLabelLen / 2)), 2)
    monWrite(tankLabel)

    -- Draw percentage
    monSetCursorPos(52, 3)
    monWrite(tankBlank)

    local percentage = stringSub(tostring(tankLevel * 100), 1, 5)

    monSetCursorPos(52 + ((tankWidth / 2) - ((#percentage + 1) / 2)), 3)
    monWrite(percentage)
    monWrite("%")

    -- Draw bar
    local h = mathFloor(tankLevel * tankBarHeight)

    for i = 0, tankBarHeight do
        if i >= tankBarHeight - h then
            monSetBackgroundColor(colorsGreen)
        else
            monSetBackgroundColor(colorsGray)
        end
        monSetCursorPos(52, i + 5)
        monWrite(tankBlank)
    end
end

local totalItems = 0
local items = {}
local itemsLen = 0
local function drawTopItems()
    -- Draw top items label
    monSetBackgroundColor(colorsBlack)
    monSetCursorPos(2, 2)
    monWrite(topItemsLabelBackground)
    monSetCursorPos(2 + ((topItemsWidth / 2) - (topItemsLabelLen / 2)), 2)
    monWrite(topItemsLabel)

    -- Draw total items
    local totalItemsStr = tostring(totalItems)

    monSetCursorPos(2 +
                         ((topItemsWidth / 2) -
                             ((#totalItemsStr + topItemsItemsSuffixLen) / 2)), 3)
    monWrite(totalItemsStr)
    monWrite(topItemsItemsSuffix)

    -- Draw top items
    for i = 1, topItemsHeight do
        monSetCursorPos(2, i + 4)
        monWrite(topItemsBlank)
    end

    local itemsToDraw = topItemsHeight * 2

    if itemsLen < itemsToDraw then itemsToDraw = itemsLen end

    for i = 1, itemsToDraw do
        if i > topItemsHeight then
            monSetCursorPos(2 + math.ceil(topItemsWidth / 2),
                             i + 4 - topItemsHeight)
        else
            monSetCursorPos(2, i + 4)
        end

        monWrite(tostring(items[i].count))
        monWrite(" - ")
        monWrite(items[i].name)
    end

end

rednet.open(modemSide)

if not fsExists("items") then
    local file = fsOpen("items", "w")
    file.write("{}")
    file.close()
end

local itemsFile = fsOpen("items", "r")

items = textutils.unserialize(itemsFile.readAll()) or {}
itemsLen = #items

for i = 1, itemsLen do
    local item = items[i]
    totalItems = totalItems + item.count
end

itemsFile.close()

local t = touchpoint.new(monitorSide)

t:add("fan", nil, 2, 21, 25, 25, colors.red, colors.lime)
t:add("lantern", nil, 27, 21, 50, 25, colors.red, colors.lime)
t:draw()
drawGraph()
drawTopItems()

-- Event loop
while true do
    local event = {t:handleEvents(osPullEventRaw())}
    if event[1] == "terminate" then
        itemsFile = fsOpen("items", "w")
        itemsFile.write(textutils.serialize(items))
        itemsFile.close()
        return
    elseif event[1] == "button_click" then
        local buttonName = event[2]
        t:toggleButton(buttonName)
        if buttonName == "fan" then
            rsSetOutput(fanSide, t.buttonList[buttonName].active)
        elseif buttonName == "lantern" then
            rednetBroadcast({
                type = "lantern",
                state = t.buttonList[buttonName].active
            })
        end
        drawGraph()
        drawTopItems()
    elseif event[1] == "rednet_message" then
        local message = event[3]
        if message.type == "tank" then
            tankLevel = message.amount
            drawGraph()
        elseif message.type == "items" then
            local messageItem = message.item
            local count = messageItem.qty
            local name = messageItem.display_name
            totalItems = totalItems + count

            local found = false

            for i = 1, itemsLen do
                local item = items[i]
                if item.name == name then
                    item.count = item.count + count
                    found = true
                    break
                end
            end

            if not found then
                tableInsert(items, {count = count, name = name})
                itemsLen = itemsLen + 1
            end

            tableSort(items, function(a, b)
                if a.count == b.count then return a.name < b.name end
                return a.count > b.count
            end)

            drawTopItems()
        end
    end
end
