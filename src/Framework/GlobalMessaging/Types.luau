--!strict
--[=[
	@module GlobalMessaging.Types
	Types for cross-server messaging via [MessagingService].
	https://create.roblox.com/docs/reference/engine/classes/MessagingService
]=]

export type Message = {
	Data: any,
	Sent: number,
}

export type MessageHandler = (message: Message) -> ()

export type InitOptions = {
	-- Prepended to every topic (counts toward the 1–80 character limit).
	TopicPrefix: string?,
}

export type ServerClass = {
	init: (self: ServerClass, options: InitOptions?) -> (),
	destroy: (self: ServerClass) -> (),
	subscribe: (self: ServerClass, topic: string, handler: MessageHandler) -> () -> (),
	unsubscribe: (self: ServerClass, topic: string) -> (),
	publish: (self: ServerClass, topic: string, data: any) -> boolean,
	resolveTopic: (self: ServerClass, topic: string) -> string,
	isSubscribed: (self: ServerClass, topic: string) -> boolean,
}

return {}
