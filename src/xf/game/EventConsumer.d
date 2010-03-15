module xf.game.EventConsumer;

private {
	import xf.game.Event;
	import xf.game.Defs : tick;
}



interface EventConsumer {
	void consume(Event, tick target);
}
