-- This program controls redstone via rednet
-- My particular usage is enabling lanterns so the mobfarm stops
-- Assumes that a modem is attached to the bottom
-- And that the redstone target is on the top
local modemSide = "bottom"
local redstoneSide = "top"

-- Moving global objects to local for optimization
local setOutput = rs.setOutput
local pullEvent = os.pullEvent

-- Setup rednet and redstone
rednet.open(modemSide)
setOutput(redstoneSide, false)

-- Event loop
while true do
    local _, _, message = pullEvent("rednet_message")
    if message.type == "lantern" then setOutput(redstoneSide, message.state) end
end
