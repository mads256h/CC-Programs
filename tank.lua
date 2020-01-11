-- This programs sends the status of a RailCraft tank every second
-- Assumes that the RailCraft tank with a valve is behind the computer
-- and that a modem is placed on top
local tankSide = "back"
local modemSide = "top"
local updateRate = 1

-- Moving global objects to local for optimization
local error = error
local rednet = rednet
local broadcast = rednet.broadcast
local sleep = sleep

-- Check peripherals are where we expect them to be
if not peripheral.isPresent(tankSide) then
	error("Tank is not present")
elseif not peripheral.isPresent(modemSide) then
	error("Modem is not present")
end

-- Setup tank and rednet
local tank = peripheral.wrap(tankSide)
rednet.open(modemSide)

while true do
	local tankInfo = tank.getTankInfo("unknown")[1]
	
	local fluidCapacity = tankInfo.capacity
	local contents = tankInfo.contents
	local fluidAmount = 0
	if contents then
		fluidAmount = contents.amount
	end
	
	broadcast({
		type = "tank",
		amount = fluidAmount / fluidCapacity
	})
	
	sleep(updateRate)
end