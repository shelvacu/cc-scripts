local function printUsage()
	print("Usage:")
	print(fs.getName(shell.getRunningProgram()).." <map_name> <x_pos> <y_pos> <z_pos> <(optional)max_distance>")
	print("<map_name> The name of the remoteMap to connect to and use.")
	print("<x_pos> <y_pos> <z_pos> The GPS coordinates you want to go to.")
	print("<(optional)max_distance> The farthest distance allowed to travel from start position.")
end

if not starNav then
	if not os.loadAPI("sn/starNav.lua") then
		error("could not load starNav API")
	end
end

local tArgs = {...}

if type(tArgs[1]) ~= "string" then
	printError("map_name: string expected")
	printUsage()
	return
end
starNav.setMap(tArgs[1])
 
for i = 2, 4 do
	if tonumber(tArgs[i]) then
		tArgs[i] = tonumber(tArgs[i])
	else
		printError("argument "..i.." must be a valid coordinate")
		printUsage()
		return
	end
end

local maxDistance
if tArgs[5] ~= nil then
	if tonumber(tArgs[5]) then
		print("setting max_distance to: ", tArgs[5])
		maxDistance = tonumber(tArgs[5])
	else
		printError("max_distance: number expected")
		printUsage()
		return
	end
end

print("going to coordinates = ", tArgs[2], ",", tArgs[3], ",", tArgs[4])
local ok, err = starNav.goto(tArgs[2], tArgs[3], tArgs[4], maxDistance)
if not ok then
	printError("navigation failed: ", err)
else
	print("succesfully navigated to coordinates")
end
