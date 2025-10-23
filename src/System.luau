--!strict

local Hecs_d = require("./Hecs.d")

export type System = Hecs_d.System
type World = Hecs_d.World

type UpdateCallback = (world: World, dt: number) -> ()
type CleanupCallback = (world: World) -> ()
type SystemFunction = (
	onUpdate: (fn: UpdateCallback) -> (), 
	onCleanup: (fn: CleanupCallback) -> ()
) -> ()

-- Empty function to not waste any
-- extra memory creating empty functions
-- during instantiation
local function emptyFn()
	return
end

--[[
	@class System
	Systems interact with entities and their
	components as to provide logic and functionality
	over them, while also being able to be
	hot-reloaded and switched easily
]]
local System = {}
System.__index = System

--[[
	@within System
	Creates a new system, to be registered inside a world

	@prop updateCb -- The callback that runs upon being updated by the world
	@prop cleanupCb -- The callback that runs upon the cleanup stage of the world
]]
function System.new(updateCb: UpdateCallback?, cleanupCb: CleanupCallback?): System
	local self = {}
	setmetatable(self, System)
	
	self.update = updateCb or emptyFn
	self.cleanup = cleanupCb or emptyFn

	return (self :: any)
end

--[[
	@within System
	Creates a new system quickly by receiving two
	parameters that allow it to assign both
	callbacks

	@prop fn -- The system's creation function
]]
function System.Define(fn: SystemFunction)
	local system = System.new(nil, nil)

	fn(function(updateCb: UpdateCallback)
		system.update = updateCb
	end, function(cleanupCb: CleanupCallback)
		system.cleanup = cleanupCb
	end)

	return system
end

return System
