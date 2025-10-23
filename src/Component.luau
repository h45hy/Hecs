--!strict

local Hecs_d = require("./Hecs.d")

export type Component<T> = Hecs_d.Component<T>
type ComponentId = Hecs_d.ComponentId

--[[
	@class Component

	Contains only exclusively data that is
	read and modified by systems
]]
local Component = {}
Component.__index = Component

--[[
	@within Component
	Creates a new component

	@prop id -- The 'id' or 'type' that this component will be identified by
	@prop data -- Data to attach to this component on initialization
]]
function Component.new<T>(id: ComponentId, data: T?): Component<T>
	assert(typeof(data) == "table", "Data must be a dictionary")
	assert(data["id"] == nil, "'id' is a restricted field")

	local self = {}
	setmetatable(self, Component)

	self.Id = id

	if data then
		for key, value in data do
			self[key] = value
		end
	end

	return (self :: any)
end


return Component :: {
	new: typeof(Component.new),
}