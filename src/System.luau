--!strict

local Hecs_d = require("./Hecs.d")

export type System = Hecs_d.System
type World = Hecs_d.World

type UpdateCallback = (world: World, dt: number) -> ()
type CleanupCallback = (world: World) -> ()

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

	@prop updateCb -- The callback that runs upon being updated by the world
	@prop cleanupCb -- The callback that runs upon the cleanup stage of the world
]]
function System.new(updateCb: UpdateCallback, cleanupCb: CleanupCallback): System
	local self = {}
	setmetatable(self, System)
	
	self.update = updateCb or emptyFn
	self.cleanup = cleanupCb or emptyFn

	return (self :: any)
end

return System
