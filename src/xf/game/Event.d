module xf.game.Event;

public {
	import xf.game.Defs : playerId, tick;
	import xf.game.TimeHub;
	import xf.utils.BitStream : BitStreamReader, BitStreamWriter;
	import xf.utils.Singleton;

	import xf.xpose2.Expose;
	//import xf.xpose2.MiniD;
	
	import tango.stdc.stdio : printf;
}



// TODO: move this somewhere

import xf.omg.core.LinearAlgebra : vec2, vec3, vec4;

void bsWrite(T)(BitStreamWriter* bs, ref T t) {
	static if (is(T == vec2)) {
		bs.write(t.x);
		bs.write(t.y);
	}
	else static if (is(T == vec3)) {
		bs.write(t.x);
		bs.write(t.y);
		bs.write(t.z);
	}
	else static if (is(T == vec4)) {
		bs.write(t.x);
		bs.write(t.y);
		bs.write(t.z);
		bs.write(t.w);
	}
	else static if (is(T == char[])) {
		bs.writeString(t);
	}
	else {
		bs.write(t);
	}
}


void bsRead(T)(BitStreamReader* bs, T t) {
	static if (is(T == vec2*)) {
		bs.read(&t.x);
		bs.read(&t.y);
	}
	else static if (is(T == vec3*)) {
		bs.read(&t.x);
		bs.read(&t.y);
		bs.read(&t.z);
	}
	else static if (is(T == vec4*)) {
		bs.read(&t.x);
		bs.read(&t.y);
		bs.read(&t.z);
		bs.read(&t.w);
	}
	else static if (is(T == char[]*)) {
		bs.readString(t, (size_t len) {
			return new char[len];		// TODO: mem
		});
	}
	else {
		bs.read(t);
	}
}



abstract class Event {
	abstract void handle();
	
	/**
		These should add the event to local queues and also send it through the network
	*/
	final void delayed(float seconds) {
		this.atTick(cast(tick)(timeHub.currentTick + timeHub.secondsToTicks(seconds)));
	}
	abstract void atTick(tick);
	abstract void immediate();

	abstract void unref();
	abstract void addRef();
	
	abstract void readFromStream(BitStreamReader*);
	abstract void writeToStream(BitStreamWriter*);
	
	abstract ushort getEventId();
	
	private {
		static ushort	eventId = ushort.max;
	}

	bool logged() {
		return false;
	}
	
	bool replayed() {
		return false;
	}
	
	ushort	instanceId = ushort.max;
	tick	eventTargetTick;

	//mixin(xpose2(`instanceId|eventTargetTick|logged|replayed|atTick|immediate|delayed|getEventId`));
	//mixin xposeMiniDNoSubclass;
}


template MEventFreeList() {
	typeof(this)		_freeListNext;
	int					_references = 1;
	static typeof(this)	_freeListHead;

	private static import tango.stdc.stdio;


	static typeof(this) _alloc() {
		if (auto h = _freeListHead) {
			_freeListHead = h._freeListNext;
			final init = this.classinfo.init;
			(cast(void*)h)[0..init.length] = init;
			assert (1 == h._references);
			return h;
		} else {
			printf("Allocating a new instance of event %.*s\n", typeof(this).stringof);
			return new typeof(this);
		}
	}


	override void unref() {
		assert (_references > 0);
		if (0 == --_references) {
			_freeListNext = _freeListHead;
			_freeListHead = this;
		}
	}


	override void addRef() {
		assert (_references > 0);
		++_references;
	}


	~this() {
		if (_references > 0) {
			tango.stdc.stdio.printf(
				"Onoz, ~%.*s() has %d references still in dtor.\n",
				typeof(this).stringof,
				_references
			);
		}
	}
}


template EventExpose() {
	mixin MEventFreeList;
	
	
	pragma(ctfe) private static char[] argListCodegen(bool types = true) {
		char[] res = "";
		foreach (i, field; xposeFields) {
			static if (field.isData) {
				const char[] name = field.name;
				if (i > 0) {
					res ~= ",";
				}
				if (types) {
					res ~= "typeof(this." ~ name ~ ")" ~ name;
				} else {
					res ~= name;
				}
			}
		}
		return res;
	}
	
	pragma(ctfe) private static char[] opCallCodegen() {
		char[] res = "static typeof(this) opCall(" ~ argListCodegen ~ "){";
		res ~= "return _alloc().initialize(" ~ argListCodegen(false) ~ ");";
		res ~= "}";
		return res;
	}
	
	mixin(opCallCodegen());
	
	static if (is(typeof(this) : Local)) {
		public override void writeToStream(BitStreamWriter* bs) {
			throw new Exception("Trying to call writeToStream() on a Local event");
		}
		public override void readFromStream(BitStreamReader* bs) {
			throw new Exception("Trying to call readFromStream() on a Local event");
		}
	} else {
		public override void writeToStream(BitStreamWriter* bs) {
			foreach (i, field; xposeFields) {
				static if (field.isData) {
					const char[] _fieldName = field.name;
					mixin(`
					static if(is(typeof(this.`~_fieldName~`) T__ == typedef)) {
						bs.write(cast(T__)this.`~_fieldName~`);
					} else {
						bsWrite(bs, this.`~_fieldName~`);
					}`);
				}
			}
		}
		
		public override void readFromStream(BitStreamReader* bs) {
			foreach (i, field; xposeFields) {
				static if (field.isData) {
					const char[] _fieldName = field.name;
					mixin(`
					static if(is(typeof(this.`~_fieldName~`) T__ == typedef)) {
						bs.read(cast(T__*)&this.`~_fieldName~`);
					} else {
						bsRead(bs, &this.`~_fieldName~`);
					}`);
				}
			}
		}
	}
}


template _exposeEvent(_ThisType) {
	static void addHandler(void delegate(typeof(this)) h) {
		assert (h.funcptr !is null);
		handlers ~= cast(void delegate(Event))h;
	}

	override void handle() {
		foreach (h; handlers) {
			h(this);
		}
	}

	static typeof(this) createUninitialized() {
		return _alloc();
		//return new typeof(this);
		//return cast(typeof(this))typeof(this).classinfo.init.dup.ptr;
	}
	
	override ushort getEventId() {
		return eventId;
	}

	
	static this() {
		xf.game.Event.registerEvent!(typeof(this));
	}

	override void atTick(tick t) {
		if (eventTargetTick == eventTargetTick.init) {
			eventTargetTick = t;
		}
		_references = submitHandlers.length;
		super.atTick(t);
	}
	
	// ----

	/+private import xf.xpose2.Expose;
	private import xf.xpose2.MiniD;+/
	private import xf.game.Event : EventExpose;
	
	typeof(this) initialize(typeof(_ThisType.tupleof) args) {
		foreach (i, a; args) {
			this.tupleof[i] = a;
		}
		static if (is(typeof(this) : Wish)) {
			wishOrigin = Wish.defaultWishOrigin;
		}
		return this;
	}
	
	static if (typeof(_ThisType.tupleof).length > 0) {
		mixin(xpose2(`.*`));
		mixin EventExpose;

		this() {
			// for createUninitialized
		}
	} else {
		mixin MEventFreeList;
		
		static typeof(this) opCall() {
			return _alloc().initialize();
		}
		
		void writeToStream(BitStreamWriter* bs) {}
		void readFromStream(BitStreamReader* bs) {}
	}


	//mixin xposeMiniDNoSubclass;

	static if (is(typeof(this) : Order)) {
		typeof(this) filter(bool delegate(playerId) destinationFilter) {
			this.destinationFilter = destinationFilter;
			return this;
		}
	}

	static void delegate(Event)[]	handlers;
	private {
		static ushort	eventId = ushort.max;
	}
}


template MEvent() {
	mixin _exposeEvent!(typeof(this));
}



private template MBaseEvent() {
	static {
		private void delegate(Event, tick)[] submitHandlers;
	
		void addSubmitHandler(void delegate(Event, tick) h) {
			submitHandlers ~= h;
		}
	}
	

	override void atTick(tick t) {
		foreach (sh; submitHandlers) {
			sh(this, t);
		}
	}

	override void immediate() {
		return this.atTick(timeHub.currentTick);
	}
}


/**
	initiated by the server
	executed by the server and the client 
*/
class Order : Event {
	mixin MBaseEvent;
	
	
	abstract void	writeToStream(BitStreamWriter*);
	bool			strictTiming() { return false; }
	
	final override bool logged() {		// not sure about it yet, but it makes sense, unless there's a separate queue for orders at client side
													// even then, orders would have to be reversible, and it's hardly ever feasible
		return false;
	}
	
	bool delegate(playerId) destinationFilter;
	
	//mixin(xpose2(`strictTiming`));
	//mixin xposeMiniDNoSubclass;
}


/**
	initiated by a client
	executed by the server in a safe manner and by client’s prediction modules 
*/
class Wish : Event {
	mixin MBaseEvent;
	
	
	abstract void writeToStream(BitStreamWriter*);
	
	playerId		wishOrigin;
	static playerId	defaultWishOrigin;
	//uint			receptionTimeMillis;
	tick			receptionTick;

	/+mixin(xpose2(`wishOrigin|receptionTimeMillis`));
	mixin xposeMiniDNoSubclass;+/
}


/**
	initiated by the server and/or clients
	not sent through the network, executed locally 
*/
class Local : Event {
	mixin MBaseEvent;
	
	
	abstract void rollback();
	override bool logged() {
		return true;
	}
	
	// handling a Local event should also add it to an undo-queue

	/+mixin(xpose2(`rollback`));
	mixin xposeMiniDNoSubclass;+/
}



enum EventType {
	Order	= 0b1,
	Wish	= 0b10,
	Local	= 0b100,
	
	Any		= Order | Wish | Local
}


// not multithread-safe, but it should only be called from static ctors.
void registerEvent(T)() {
	static assert (is(T : Event));
	assert ((T.classinfo in registeredEvents) is null);
	
	debug printf(`Registering event %.*s to id %d`\n, T.classinfo.name, cast(int)lastFreeEventId);
	
	eventFactories[T.eventId = lastFreeEventId++] = cast(Event function())&T.createUninitialized;
	eventTypes[T.eventId] = is(T : Order) ? EventType.Order : is(T : Wish) ? EventType.Wish : EventType.Local;
	registeredEvents[T.classinfo] = T.eventId;
}


bool checkEventType(typeof(Event.eventId) id, EventType typeMask) {
	debug printf(`event type: %d(%d) ; type mask: %d`\n,
		id,
		id in eventTypes ? cast(int)eventTypes[id] : -1,
		cast(int)typeMask
	);
	
	// BUG, TODO: crash-proof me
	return (eventTypes[id] & typeMask) != 0;
}


Event createEvent(typeof(Event.eventId) id) {
	return eventFactories[id]();
}


Event readEventOr(BitStreamReader* bs, EventType typeMask, void delegate() error) {
	typeof(Event.eventId) eventId;
	bs.read(&eventId);
	debug printf(`read event id: %d`\n, cast(int)eventId);
	
	if (!checkEventType(eventId, typeMask)) {
		error();
		return null;
	} else {
		Event event = createEvent(eventId);
		assert (event !is null);
		debug printf(`created a %.*s`\n, event.classinfo.name);
		
		bs.read(&event.instanceId);
		debug printf(`read event instance id: %d`\n, cast(int)event.instanceId);
		
		// read the number of dependencies - some packed int  -  TODO
		// read the dependency list  -  TODO
		
		event.readFromStream(bs);
		
		debug printf(`event data unserialized`\n);
		return event;
	}
}


void writeEvent(BitStreamWriter* bs, Event event) {
	debug printf(`writing event id: %d, instance id %d`\n, cast(int)event.getEventId(), cast(int)event.instanceId);
	
	bs.write(event.getEventId());
	bs.write(event.instanceId);
	
	// write the number of dependencies - some packed int  -  TODO
	// write the dependency list  -  TODO
	
	event.writeToStream(bs);
}


private {
	typeof(Event.eventId)					lastFreeEventId = 1;
	typeof(Event.eventId)[ClassInfo]		registeredEvents;
	Event function()[typeof(Event.eventId)]	eventFactories;
	EventType[typeof(Event.eventId)]		eventTypes;
}
