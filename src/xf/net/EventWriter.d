module xf.net.EventWriter;

private {
	import xf.Common;
	import xf.game.EventConsumer;
	import xf.game.Event;
	import xf.game.Defs;
	import xf.utils.BitStream;
	import xf.net.Log : log = netLog;
}



/**
 * Not bothering with budgets here as events are assumed to take a small part
 * of available bandwidth, are often critical to be delivered on time,
 * plus queueing them up would be rather bothersome.
 */
class EventWriter : EventConsumer {
	int delegate(int delegate(ref playerId, ref BitStreamWriter))
			iterPlayerStreams;
			
	bool delegate(playerId, Order)
			playerOrderMask;



	void consume(Event evt, tick target) {
		assert (iterPlayerStreams !is null);
		assert (playerOrderMask !is null);

		version (Server) {
			assert (playerOrderMask !is null);
			
			if (auto order = cast(Order)evt) {
				final mask = (playerId pid) {
					return (
						(
							order.destinationFilter is null
							|| order.destinationFilter(pid)
						)
						&& playerOrderMask(pid, order)
					);
				};

				foreach (pid, ref bsw; iterPlayerStreams) {
					if (mask(pid)) {
						bsw(true /* event */);
						bsw(cast(uint)target);
						log.trace("EventWriter :: serializing an Order.");
						writeEvent(&bsw, order);
					}
				}
			}
		} else {
			if (auto wish = cast(Wish)evt) {
				foreach (pid, ref bsw; iterPlayerStreams) {
					bsw(true /* event */);
					bsw(cast(uint)target);
					log.trace("EventWriter :: serializing a Wish.");
					writeEvent(&bsw, wish);
				}
			}
		}
	}
}
