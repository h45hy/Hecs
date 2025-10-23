# Hecs

"Hell's ECS"

A simple ECS library made for Roblox

## Usage

```lua
local Hecs = require(path.to.Hecs)
local World, Component, System = Hecs.World, Hecs.Component, Hecs.System

local myWorld = World.new()

local function createAgeSystem()
	local system = System.new()

	function system.update(world: World.World, dt: number)
		for entity, ageComponent in world:Query("Age") do
			ageComponent.ageMs += dt
		end
	end

	return system
end

local function createAgeComponent()
	return Component.new("Age", {
		ageMs = 0
	})
end

local entity = myWorld:CreateEntity()
myWorld:SetComponent(entity, createAgeComponent())
myWorld:RegisterSystem(createAgeSystem())

while true do
	local dt = task.wait()
	myWorld:Tick(dt)
end
```