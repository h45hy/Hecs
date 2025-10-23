--!strict

local Hecs_d = require("./Hecs.d")

export type World = Hecs_d.World
type ComponentId = Hecs_d.ComponentId
type Component<T> = Hecs_d.Component<T>
type ArchetypeId = Hecs_d.ArchetypeId
type Archetype = Hecs_d.Archetype
type EntityId = Hecs_d.EntityId
type System = Hecs_d.System

type WorldPriv = Hecs_d.World & {
	__freedIds: { EntityId },
	__lastEntityId: EntityId,
	__lastArchetypeId: ArchetypeId,
	__createArchetype: (self: WorldPriv, componentIds: { ComponentId }) -> ArchetypeId,
	__getArchetype: (self: WorldPriv, componentIds: { ComponentId }) -> ArchetypeId?,
	__setEntityArchetype: (self: WorldPriv, entityId: EntityId, archetypeId: ArchetypeId) -> (),
}

--[[
	@class World
	Acts as the environment in which entities
	and systems interact with eachother
]]
local World = {}
World.__index = World

--[[
	@within World
	Creates a new world
]]
function World.new(): World
	local self = {}
	setmetatable(self, World)

	self.Entities = {}
	self.Systems = {}
	self.Archetypes = {
		-- Default, component-less
		-- archetype
		[0] = {
			Components = {},
			Entities = {},
			Next = {},
		}
	}
	self.ComponentArchetypes = {}
	self.EntityArchetypes = {}
	self.EntityComponents = {}

	self.__freedIds = {}
	self.__lastEntityId = 0
	self.__lastArchetypeId = 0

	return (self :: any)
end

--[[
	@within World
	Ticks all systems for one frame

	@prop dt -- The delta time that passed between the current and last render
]]
function World.Tick(self: WorldPriv, dt: number)
	assert(dt > 0, `'dt' must be unsigned`)

	-- Runtime
	for systemId, system in self.Systems do
		system.update(self, dt)
	end

	-- Cleanup stage
	for systemId, system in self.Systems do
		system.cleanup(self)
	end
end

--[[
	@within World
	Queries the world for entities containing the components
	required, returning an iterator function

	@prop ... -- The component ID's to query
]]
function World.Query<T>(self: WorldPriv, ...: ComponentId): () -> (EntityId, Component<T>)
	local componentIdsNoSort = { ... }
	local componentIds = { ... }
	table.sort(componentIds)

	-- Archetype doesn't exist, so based on how the
	-- system works, no entity has that combination
	-- of components either
	local archetypeId = self:__getArchetype(componentIds)

	if not archetypeId then
		return function()
			return
		end :: any
	end

	local archetype = self.Archetypes[archetypeId]
	local entitySets = { archetype.Entities }

	-- Recursive function to register all subarchetype
	-- entities, otherwise we'll only fetch the ones
	-- from the base archetype (e.g entities from A but not AB)
	local function registerEntitySet(archetype: Archetype)
		for _, subArchetypeId in archetype.Next do
			local subArchetype = self.Archetypes[subArchetypeId]
			if next(subArchetype.Next) ~= nil then
				registerEntitySet(subArchetype)
			end

			local subEntities = subArchetype.Entities
			if next(subEntities) == nil then
				continue
			end

			table.insert(entitySets, subArchetype.Entities)
		end
	end
	registerEntitySet(archetype)

	-- Returns an iterator instead of a table
	-- as it allows direct retrieval of the
	-- desired component and less processing
	local lastKey = nil
	local entitySet = entitySets[1]

	return function()
		local entityId = next(entitySet, lastKey)

		-- When an entity set gets exhausted, loop
		-- into the next archetype's entity set
		if entityId == nil then
			table.remove(entitySets, 1)
			entitySet = entitySets[1]

			if not entitySet then
				return
			end

			entityId = next(entitySet, nil)
		end

		lastKey = entityId

		-- This is the most taxing part of the
		-- algorithm, however it is very convenient
		-- so it's a tradeoff that we'll have to
		-- live with
		local entityComponents = self.EntityComponents[entityId :: number]
		local components = {}

		for _, componentId in componentIdsNoSort do
			table.insert(components, entityComponents[componentId])
		end

		return entityId, unpack(components)
	end :: any
end

--[[
	@within World
	Registers a new system
]]
function World.RegisterSystem(self: WorldPriv, system: System)
	table.insert(self.Systems, system)
	return #self.Systems
end

--[[
	@within World
	Creates a new entity
]]
function World.CreateEntity(self: WorldPriv): EntityId
	local id = -1

	if #self.__freedIds > 0 then
		id = table.remove(self.__freedIds, 1) :: number
	else
		id = self.__lastEntityId + 1
		self.__lastEntityId = id
	end

	self.Entities[id] = true
	self.EntityComponents[id] = {}
	self.EntityArchetypes[id] = 0

	self:__setEntityArchetype(id, 0)

	return id
end

--[[
	@within World
	Removes an entity and its components

	@prop entityId -- The entity's id
]]
function World.RemoveEntity(self: WorldPriv, entityId: EntityId)
	assert(self.Entities[entityId], "Entity doesn't exist")

	local archetypeId = self.EntityArchetypes[entityId]
	local archetype = self.Archetypes[archetypeId]
	archetype.Entities[entityId] = nil

	self.Entities[entityId] = nil
	self.EntityComponents[entityId] = nil
	self.EntityArchetypes[entityId] = nil

	table.insert(self.__freedIds, entityId)
end

--[[
	@within World
	Attaches a component to an entity

	@prop entityId -- The entity's id
	@prop component -- The component to add
]]
function World.SetComponent<T>(
	self: WorldPriv, 
	entityId: EntityId, 
	component: Component<T>
)
	assert(self.Entities[entityId], "Entity doesn't exist")
	assert(typeof(component) == "table", "Invalid 'component' argument")

	local worldArchetypes = self.Archetypes
	local entityComponents = self.EntityComponents[entityId]
	local entityArchetypeId = self.EntityArchetypes[entityId]

	entityComponents[component.Id] = component

	-- Sort components by their ID so we
	-- can properly go through their
	-- archetype tree avoiding ABC and CBA
	-- errors
	local componentIds = {}
	for componentId in entityComponents do
		table.insert(componentIds, componentId)
	end
	table.sort(componentIds)

	local oldArchetype = worldArchetypes[entityArchetypeId]

	-- Check immediately if our current
	-- archetype is connected to the next
	-- archetype
	do
		local nextArchetypeId = oldArchetype.Next[component.Id]
		if nextArchetypeId then
			self:__setEntityArchetype(entityId, nextArchetypeId)
			return
		end
	end

	-- Iterate from the starting archetype
	-- until we reach a final archetype
	-- containing all of our components in
	-- an ordered manner
	local componentIdMix = {}
	local archetypeId = 0
	
	for _, componentId in componentIds do
		table.insert(componentIdMix, componentId)

		local archetype = worldArchetypes[archetypeId]
		local nextArchetypeId = archetype.Next[componentId]

		if not nextArchetypeId then
			nextArchetypeId = self:__createArchetype(componentIdMix)
			archetype.Next[componentId] = nextArchetypeId
		end

		archetypeId = nextArchetypeId
	end

	self:__setEntityArchetype(entityId, archetypeId)
end

--[[
	@private
	@within World
	Gets the archetype from a list of components

	@prop componentIds -- The list of component ids to attach to this archetype
]]
function World.__getArchetype(self: WorldPriv, componentIds: { ComponentId }): ArchetypeId?
	-- Acts as a side effect, but its tolerable as
	-- it doesn't impact the module's functionality
	table.sort(componentIds)

	local archetypeId = 0
	for _, componentId in componentIds do
		local archetype = self.Archetypes[archetypeId]
		local nextArchetypeId = archetype.Next[componentId]

		-- There are not gonna be any entities
		-- with this set of components since
		-- the archetype was never created
		if not nextArchetypeId then
			return nil
		end

		archetypeId = nextArchetypeId
	end

	return archetypeId
end

--[[
	@private
	@within World
	Creates a new archetype from the component ids given
	Doesn't perform any safety checks (such as asserting if
	it already exists)

	@prop componentIds -- The list of component ids to attach to this archetype
]]
function World.__createArchetype(self: WorldPriv, componentIds: { ComponentId }): ArchetypeId
	local archetype: Archetype = {
		Components = table.clone(componentIds),
		Next = {},
		Entities = {},
	}

	local archetypeId = self.__lastArchetypeId + 1
	self.__lastArchetypeId = archetypeId
	self.Archetypes[archetypeId] = archetype

	for _, componentId in componentIds do
		local componentArchetypes = self.ComponentArchetypes[componentId]

		if not componentArchetypes then
			componentArchetypes = {}
			self.ComponentArchetypes[componentId] = componentArchetypes
		end

		table.insert(componentArchetypes, archetypeId)

		for _, componentArchetypeId in componentArchetypes do
			local componentArchetype = self.Archetypes[componentArchetypeId]
			local componentArchetypeMix = componentArchetype.Components

			local componentsDiff = {}
			local count = #componentIds

			for _, component in componentIds do
				componentsDiff[component] = true
			end
			for _, component in componentArchetypeMix do
				if componentsDiff[component] then
					componentsDiff[component] = nil
					count -= 1

					continue
				end

				componentsDiff[component] = true
				count += 1
			end
			
			if count == 1 then
				local componentDiff = next(componentsDiff) :: string
				
				componentArchetype.Next[componentDiff] = archetypeId
				archetype.Next[componentDiff] = componentArchetypeId
			end
		end
	end

	return archetypeId
end

--[[
	@private
	@within World
	Changes an entity's archetype, removing old information
	about the entity from its old archetype

	@prop entityId -- The entity to change the archetype of
	@prop archetypeId -- The new archetype's id
]]
function World.__setEntityArchetype(
	self: WorldPriv, 
	entityId: EntityId, 
	archetypeId: ArchetypeId
)
	local oldArchetypeId = self.EntityArchetypes[entityId]
	local oldArchetype = self.Archetypes[oldArchetypeId]
	local archetype = self.Archetypes[archetypeId]

	oldArchetype.Entities[entityId] = nil
	archetype.Entities[entityId] = true
	self.EntityArchetypes[entityId] = archetypeId
end

return World :: {
	new: typeof(World.new),
}
