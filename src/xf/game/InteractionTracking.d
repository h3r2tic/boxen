module xf.game.InteractionTracking;

private {
	import xf.havok.Havok;
}


hkpContactListener			contactListener;
hkpCharacterProxyListener	charProxyListener;


extern (C) extern void boxen_processGameObjInteraction(void*, void*);


void initialize(hkpWorld world) {
	DContactListener conListenerWrapper;
	conListenerWrapper.thisptr = null;		// TODO not needed at all? simplify the bridge.
	conListenerWrapper.process = &cf_process;
	.contactListener =
		EntityContactListener(conListenerWrapper)._as_hkpContactListener;

	DCharacterProxyListener charProxyListenerWrapper;
	charProxyListenerWrapper.thisptr = null;		// TODO not needed at all? simplify the bridge.
	charProxyListenerWrapper.charChar = &cf_charChar;
	charProxyListenerWrapper.charBody = &cf_charBody;
	.charProxyListener =
		CharacterProxyListener(charProxyListenerWrapper)._as_hkpCharacterProxyListener;

	world.markForWrite();
	world.addContactListener(contactListener);
	world.unmarkForWrite();
}


private {
	extern (C) void cf_process(void*, hkpRigidBody a, hkpRigidBody b) {
		final o1 = cast(void*)a.getUserData();
		final o2 = cast(void*)b.getUserData();
		if (o1 && o2 && o1 !is o2) {
			boxen_processGameObjInteraction(o1, o2);
		}
	}

	extern (C) void cf_charChar(void* thisptr, hkpCharacterProxy a, hkpCharacterProxy b) {
		final o1 = cast(void*)a.getShapePhantom().getUserData();
		final o2 = cast(void*)b.getShapePhantom().getUserData();
		if (o1 && o2 && o1 !is o2) {
			boxen_processGameObjInteraction(o1, o2);
		}
	}

	extern (C) void cf_charBody(void* thisptr, hkpCharacterProxy a, hkpRigidBody b) {
		final o1 = cast(void*)a.getShapePhantom().getUserData();
		final o2 = cast(void*)b.getUserData();
		if (o1 && o2 && o1 !is o2) {
			boxen_processGameObjInteraction(o1, o2);
		}
	}	
}
