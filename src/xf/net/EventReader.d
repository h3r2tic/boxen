module xf.net.EventReader;

private {
	import xf.Common;
	import xf.game.Event;
	import xf.game.Defs;
	import xf.net.ControlEvents;
	import xf.net.Misc : readTick;
	import xf.net.Log : log = netLog, error = netError;
	import xf.utils.BitStream;
	import xf.utils.HardwareTimer;
}



class EventReader {
	bool delegate(playerId, Wish)
			playerWishMask;

	void delegate(tick)
			rollbackTimeToTick;


	bool readEvent(playerId pid, BitStreamReader* bs) {
		assert (playerWishMask !is null);
		assert (rollbackTimeToTick !is null);
		
		
		//printf("receiveEvent"\n);
		tick evtTargetTick = readTick(bs);

		version (Server) {
			Event evt = readEventOr(bs, EventType.Wish, {
				log.error("Client {} tried to send an invalid event. Kicking.", pid);
				KickPlayer(pid).delayed(5);
			});
			if (evt is null) return false;
			
			if (!playerWishMask(pid, cast(Wish)evt)) {
				log.warn("Wish blocked: {}", evt.classinfo.name);
				return true;
			} else {
				//log.trace("Received a Wish: {}.", evt.classinfo.name);
			}
			
			with (cast(Wish)evt) {
				wishOrigin = pid;
				//eventTargetTick = evtTargetTick;

				// TODO: move this to the low level server into net events
				receptionTimeMillis = cast(uint)(hardwareTimer.timeMicros / 1000);
			}
			
			if (evtTargetTick < timeHub.currentTick) {
				//log.trace("Wish targeted at {} arrived too late. currentTick: {}", evtTargetTick, timeHub.currentTick);
			}
			
			evt.atTick(evtTargetTick);
		} else {
			Event evt = readEventOr(bs, EventType.Order, {
				throw new Exception(`Received an invalid event from the server`);
			});

			//log.trace("Event for tick {}", evtTargetTick);
			// NOTE: changed < from the original netcode to <=
			if (evtTargetTick <= timeHub.currentTick) {
				log.info("# evtTargetTick <= timeHub.currentTick");
				if ((cast(Order)evt).strictTiming) {
					rollbackTimeToTick(evtTargetTick);
				} else {
					//log.trace("Immediately handling an Order: {}.", evt.classinfo.name);
					evt.eventTargetTick = evtTargetTick;
					// TODO: is this valid? perviously only control ImmediateEvents would be executed like this
					evt.handle();
					return true;
				}
			}
			
			if (cast(ImmediateEvent)evt) {
				debug log.trace("handling the control event");
				evt.handle();
			} else {
				//log.trace("Received an Order: {}.", evt.classinfo.name);
				//debug log.trace("submitting the {}...", evt.classinfo.name);
				evt.atTick(evtTargetTick);
			}
		}
		
		return true;
	}
}
