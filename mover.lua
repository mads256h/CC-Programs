-- This program sends item information via rednet
-- then it moves the items to another inventory
-- This requires a narcissistic turtle
-- The program assumes that a modem is attached on the left side
-- and a duck antenna is attached to the right side
local modemSide = "left"
local inventorySide = "right"

-- Moving global objects to local for optimization
local rednet = rednet
local pullEvent = os.pullEvent
local broadcast = rednet.broadcast
local getItemCount = turtle.getItemCount
local select = turtle.select
local drop = turtle.drop

-- Setup rednet and peripherals
rednet.open(modemSide)
local inv = peripheral.wrap(inventorySide)
local getStackInSlot = inv.getStackInSlot

-- Event loop
while true do
	pullEvent("turtle_inventory")
	for i = 1,16 do
		local count = getItemCount(i)
		if count > 0 then
			select(i)
			local item = getStackInSlot(i)
			drop(count)
			broadcast({
				type = "items",
				item = item
			})
		end
	end
end