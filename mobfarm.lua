-- Monitors and controls different parts of a mobfarm
-- Assumes that a monitor is attached to the top of the computer
-- fans are attach via redstone on the bottom
-- and that a modem is attached on the back

local monitorSide = "top"
local fanSide = "bottom"
local modemSide = "back"
local apiPath = "/usr/apis/touchpoint"

-- Moving global objects to local for optimization
local string = string
local stringRep = string.rep
local fsExists = fs.exists
local print = print
local shellRun = shell.run
local os = os
local osLoadAPI = os.loadAPI
local osPullEvent = os.pullEvent
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

-- Check if touchpoint is installed
if not fsExists(apiPath) then
	print("touchpoint is not installed; installing...")
	shellRun("pastebin run 4zyreNZy")
	shellRun("packman install touchpoint")
end

osLoadAPI("/usr/apis/touchpoint")

local mon = peripheral.wrap(monitorSide)

local tankLevel = 0
function drawGraph()
	
	-- Draw essense label
	mon.setBackgroundColor(colorsBlack)
	mon.setCursorPos(52, 2)
	mon.write(tankLabelBackground)
	mon.setCursorPos(52 + ((tankWidth / 2) - (tankLabelLen / 2)), 2)
	mon.write(tankLabel)
	
	-- Draw percentage
	mon.setCursorPos(52, 3)
	mon.write(tankBlank)
	
	local percentage = stringSub(tostring(tankLevel*100), 1, 5)
	
	mon.setCursorPos(52 + ((tankWidth / 2) - ((#percentage + 1) / 2)), 3)
	mon.write(percentage)
	mon.write("%")
	
	-- Draw bar
	local h = mathFloor(tankLevel*tankBarHeight)
	
	for i = 0, tankBarHeight do 
		if i >= tankBarHeight - h then
			mon.setBackgroundColor(colorsGreen)
		else
			mon.setBackgroundColor(colorsGray)
		end
		mon.setCursorPos(52, i + 5)
		mon.write(tankBlank)
	end
end

local totalItems = 0
local items = {}
function drawTopItems()
	-- Draw top items label
	mon.setBackgroundColor(colorsBlack)
	mon.setCursorPos(2,2)
	mon.write(topItemsLabelBackground)
	mon.setCursorPos(2 + ((topItemsWidth / 2) - (topItemsLabelLen / 2)), 2)
	mon.write(topItemsLabel)
	
	-- Draw total items
	local totalItemsStr = tostring(totalItems)
	
	mon.setCursorPos(2 + ((topItemsWidth / 2) - ((#totalItemsStr + #" items") / 2)), 3)
	mon.write(totalItemsStr)
	mon.write(" items")
	
	-- Draw top items
	for i = 1, topItemsHeight do
		mon.setCursorPos(2, i + 4)
		mon.write(topItemsBlank)
	end
	
	local itemsToDraw = topItemsHeight * 2
	
	if #items < itemsToDraw then
	itemsToDraw = #items
	end
	
	for i = 1, itemsToDraw do
		if i > topItemsHeight then
			mon.setCursorPos(2 + (topItemsWidth / 2), i + 4 - topItemsHeight)
		else
			mon.setCursorPos(2, i + 4)
		end
		
		mon.write(tostring(items[i].count))
		mon.write(" - ")
		mon.write(items[i].name)
	end
	
end

rednet.open(modemSide)

local t = touchpoint.new(monitorSide)

t:add("fan",     nil, 2,  21, 25, 25, colors.red, colors.lime)
t:add("lantern", nil, 27, 21, 50, 25, colors.red, colors.lime)
t:draw()
drawGraph()
drawTopItems()

while true do
	local event = {t:handleEvents(os.pullEvent())}
	if event[1] == "button_click" then
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
			local item = message.item
			local count = item.qty
			local name = item.display_name
			totalItems = totalItems + count
			
			local found = false
			
			for i = 1, #items do
				local item = items[i]
				if item.name == name then
					item.count = item.count + count
					found = true
					break
				end
			end
			
			if not found then
				tableInsert(items, {count = count, name = name})
			end
			
			tableSort(items, function(a, b)
				if a.count == b.count then
					return a.name < b.name
				end
				return a.count > b.count
			end)
			drawTopItems()
		end
	end
end