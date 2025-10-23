--[[
	@fileinfo Hecs.d.luau
	Holds all of the types used in Hecs to
	avoid circular dependencies
]]

-- Archetype types
export type ArchetypeId = number
export type Archetype = {
   Components: {
		ComponentId
	},
	Entities: {
		[EntityId]: boolean
	},
   Next: {
   	[ComponentId]: ArchetypeId
   }
}

-- Component types
export type ComponentId = string
export type Component<T> = {
	Id: ComponentId,
} & T
export type ComponentSet = {
	[ComponentId]: Component<unknown>
}

-- System types
export type SystemId = number
export type System = {
	update: (world: World, dt: number) -> (),
	cleanup: (world: World) -> (),
}

-- Entity types
export type EntityId = number

-- World types
export type World = {
	Entities: {
		[EntityId]: boolean,
	},
	Systems: {
		[SystemId]: System,
	},
	Archetypes: {
		[ArchetypeId]: Archetype,
	},
	EntityComponents: {
		[EntityId]: ComponentSet,
	},
	EntityArchetypes: {
		[EntityId]: ArchetypeId,
	},
	Tick: (self: World, dt: number) -> (),
	RegisterSystem: (self: World, system: System) -> SystemId,
	Query: <T>(self: World, ...ComponentId) -> () -> (EntityId, Component<T>),
	CreateEntity: (self: World) -> EntityId,
	RemoveEntity: (self: World, entityId: EntityId) -> (),
	SetComponent: <T>(self: World, entityId: EntityId, component: Component<T>) -> (),
}

return {}