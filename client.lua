if not socket or not socket.websocket then
  error("You do not have CCTweaks installed or are not on the latest version.")
end

if not fs.exists(".rednoot") then
    fs.makeDir(".rednoot")
end

if not fs.exists(".rednoot/json") then
    print("Downloading json...")
    shell.run("pastebin get 4nRg9CHU .rednoot/json")
end

os.loadAPI(".rednoot/json")
local json = json
local defaultEndpoint = "ws://rednoot.geto.ml"
local defaultSide = "front"

local args = {...}

if args[1] and (args[1].sub(1,1) == "-" or #args == 4 or #args == 1) and (args[1]:find("help") or args[1]:find("%?") or args[1]:find("/")) then
    error("Usage: "..shell.getRunningProgram().." [endpoint ("..defaultEndpoint..")] [mountPoint ("..defaultSide..")]")
end

local endpoint = args[1] or defaultEndpoint

if endpoint:sub(1,5) ~= "ws://" then
    endpoint = "ws://"..endpoint
end

local mountPoint = args[2] or defaultSide

local oldPeripheral = peripheral
local oldGetID = os.getComputerID
_G.peripheral = {}

local virtualModem = {}
local ws
local userID = 0
local openChannels = {}

os.getComputerID = function()
    return userID
end

peripheral.isPresent = function(side)
	if side == mountPoint then return true end
	return oldPeripheral.isPresent(side)
end

peripheral.getType = function(side)
	if side == mountPoint then return "modem" end
	return oldPeripheral.getType(side)
end

peripheral.getMethods = function(side)
	if side == mountPoint then
		return {
			"open", "isOpen", "close", "closeAll", "transmit", "isWireless"
		}
	end
	return oldPeripheral.getMethods(side)
end

peripheral.call = function(side, method, ...)
    local args = {...}
	if side == mountPoint then
		return virtualModem[method](unpack(args))
	end
	return oldPeripheral.call(unpack(args))
end

peripheral.wrap = function(side)
	if side == mountPoint then
		return virtualModem
	end
	return oldPeripheral.wrap(side)
end

peripheral.find = function(pType, callback)
	if pType == "modem" then
		if not callback then
			return peripheral.wrap(mountPoint)
		end

		callback(mountPoint, peripheral.wrap(mountPoint))
		return nil
	end
	return oldPeripheral.find(pType, callback)
end

peripheral.getNames = function()
	local names = oldPeripheral.getNames()
	local found = false
	for k, v in pairs(names) do
		if v == mountPoint then found = true end
	end
	if not found then
		table.insert(names, mountPoint)
	end
	return names
end

virtualModem.open = function(channel)
    table.insert(openChannels, channel)
	os.queueEvent("rednoot_open", channel)
end

virtualModem.close = function(channel)
	local newChannels = {}
	for k, v in pairs(openChannels) do
		if v ~= channel then
			table.insert(newChannels, v)
		end
	end

	openChannels = newChannels
	os.queueEvent("rednoot_close", channel)
end

virtualModem.isWireless = function()
	return true
end

virtualModem.transmit = function(channel, replyChannel, message)
    os.queueEvent("rednoot_transmit", channel, replyChannel, message)
end

virtualModem.closeAll = function()
    openChannels = {}
	os.queueEvent("rednoot_close_all")
end

virtualModem.isOpen = function(channel)
	for _, v in pairs(openChannels) do
		if v == channel then
			return true
		end
	end
	return false
end

local function daemon()
    while true do
        local ev = {coroutine.yield()}
        if ev[1] == "socket_message" then
            local msg = json.decode(ws.read())
            if msg.type == "id" then
                userID = msg.value
            elseif msg.type == "receive" then
                os.queueEvent("modem_message", mountPoint, msg.channel, msg.reply_channel, msg.message, 0, msg.id)
            elseif msg.type == "error" then
                os.queueEvent("rednoot_error", msg.message)
            end
        elseif ev[1] == "rednoot_open" then
            ws.write(json.encode({
                type = "open",
                channel = ev[2]
            }))
        elseif ev[1] == "rednoot_close" then
            ws.write(json.encode({
                type = "close",
                channel = ev[2]
            }))
        elseif ev[1] == "rednoot_close_all" then
            ws.write(json.encode({
                type = "close_all"
            }))
        elseif ev[1] == "rednoot_transmit" then
            ws.write(json.encode({
                type = "transmit",
                channel = ev[2],
                reply_channel = ev[3],
                message_type = type(ev[4]),
                message = ev[4]
            }))
        end
    end
end

ws = socket.websocket(endpoint)
local timeout = 0
while (not ws.checkConnected()) and timeout < 200 do
    write(".")
    sleep(0)
    timeout = timeout + 1
end
print()

if timeout == 200 then
    print("Timed out!")
    return
end

term.clear()
term.setCursorPos(1,1)

parallel.waitForAny(daemon, function()
	print("Connected to network!")
	shell.run("/rom/programs/shell")
end)

_G.peripheral = oldPeripheral
_G.os.getComputerID = oldGetID
ws.close()
print("Disconnected from the network.")
