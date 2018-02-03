if not ((socket and socket.websocket) or http.websocketAsync) then
  error("You do not have CC:Tweaked/CCTweaks installed or you are not on the latest version.")
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
local defaultEndpoint = "ws://rednoot.krist.club"
local defaultSide = "front"

local args = {...}

if args[1] and (args[1].sub(1,1) == "-" or #args[1] == 4 or #args[1] == 1) and (args[1]:find("help") or args[1]:find("%?") or args[1]:find("/")) then
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
local connected = false
local timer
local timeout = 10

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
	return oldPeripheral.call(side, method, unpack(args))
end

peripheral.wrap = function(side)
	if side == mountPoint then
		return virtualModem
	end
	return oldPeripheral.wrap(side)
end

peripheral.find = function(pType, fnFilter)
	if pType == "modem" then
		if not fnFilter then
			return peripheral.wrap(mountPoint)
		elseif fnFilter(mountPoint, peripheral.wrap(mountPoint)) then
			return peripheral.wrap(mountPoint)
		end
	end
	return oldPeripheral.find(pType, fnFilter)
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

local function processMessage(mess)
  local msg = json.decode(mess)
  if msg.type == "id" then
      userID = msg.value
  elseif msg.type == "receive" then
      os.queueEvent("modem_message", mountPoint, msg.channel, msg.reply_channel, msg.message, 0, msg.id)
  elseif msg.type == "error" then
      os.queueEvent("rednoot_error", msg.message)
  end
end

local function daemon()
    local newws = socket and socket.websocket or http.websocketAsync
    local async
    if socket and socket.websocket then
      async = false
    else
      async = true
    end
    ws = newws(endpoint)
    timer = os.startTimer(timeout)
    while true do
        local ev = {coroutine.yield()}
        if ev[1] == "socket_connect" and ev[2] == ws.id() then
            connected = true
        elseif ev[1] == "websocket_success" and ev[2] == endpoint then
            ws = ev[3]
            ws.write = ws.send
            connected = true
        elseif ev[1] == "websocket_message" and ev[2] == endpoint then
            local mess = ev[3]
            if mess then
              processMessage(mess)
            end
        elseif ev[1] == "socket_message" and ev[2] == ws.id() then
            local mess = ws.read()
            if mess then
              processMessage(mess)
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
        elseif ev[1] == "timer" and ev[2] == timer then
            if not connected then
                return
            end
        end
    end
end

term.clear()
term.setCursorPos(1,1)

parallel.waitForAny(daemon, function()
    while not connected do
        write(".")
        sleep(0)
    end
    term.clear()
    term.setCursorPos(1,1)
	print("Connected to network!")
	shell.run("/rom/programs/shell")
end)

_G.peripheral = oldPeripheral
_G.os.getComputerID = oldGetID
if ws.checkConnected() then
    ws.close()
    print("Disconnected from the network.")
else
    print("Timed out.")
end
