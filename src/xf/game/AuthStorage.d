/**
	Efficient storage for physical contacts between objects. The stored data type for one contact is an uint,
	which is meant to represent a packed 24-bit object id and the remaining ticks for this contact to persist.
	
	Internally, each object has an associated ContactBin instance with max 7 external contacts. It also stores
	a flag to be used for traversing this data and a length. The structure fits nicely in 32 bytes, which is small enough
	to fit within any modern CPU's cache line (64B on a Core2). In the rare event of 7 contacts not being enough,
	auxiliary space is referenced from a global pool to form a chunked linked list with 31 items per chunk.
	
	Contact bins support the insertion of new items, iteration, removal and updating in a few specialized versions.
	
	The total storage is completely pre-allocated at program startup to the size of 1MB.
*/

module xf.boxen.game.ContactStorage;


private const int numInitialBins = 8;
private const int numInitialRefs = numInitialBins - 1;
private const int numAuxBins = 32;
private const int numAuxRefs = numAuxBins - 1;



struct ContactBin {
	private {
		uint[numInitialBins]	_bins;
		const uint					_visitedFlag = 0x8000_0000;
	}

	bool readVisitedFlag() {
		return (_bins[0] & _visitedFlag) != 0;
	}

	void setVisitedFlag() {
		_bins[0] |= _visitedFlag;
	}

	void unsetVisitedFlag() {
		_bins[0] &= ~_visitedFlag;
	}

	uint length() {
		return _bins[0] & 0xffff;
	}

	int opApply(int delegate(ref uint) dg) {
		uint len = _bins[0] & 0xffff;

		if (len > numInitialRefs) {
			foreach (ref b; _bins[1..numInitialBins]) {
				if (auto res = dg(b)) {
					return res;
				}
			}

			len -= numInitialRefs;
			uint auxIdx = (_bins[0] >> 16) & 0x7fff;
nextAuxId:
			uint[] aux = auxBinStorage[auxIdx]._bins;
			//Stdout.formatln("aux = {}", aux);

			if (len > numAuxRefs) {
				foreach (ref b; aux[0..numAuxRefs]) {
					if (auto res = dg(b)) {
						return res;
					}
				}

				auxIdx = aux[numAuxRefs];
				assert (auxIdx != 0);
				len -= numAuxRefs;
				goto nextAuxId;
			} else {
				foreach (ref b; aux[0..len]) {
					if (auto res = dg(b)) {
						return res;
					}
				}
			}
		} else {
			foreach (ref b; _bins[1..len+1]) {
				if (auto res = dg(b)) {
					return res;
				}
			}
		}

		return 0;
	}

	void iterOrAdd(bool delegate(ref uint) dg, uint newItem) {
		uint len = _bins[0] & 0xffff;

		if (len > numInitialRefs) {
			foreach (ref b; _bins[1..numInitialBins]) {
				if (dg(b)) {
					return;
				}
			}

			len -= numInitialRefs;
			uint auxIdx = (_bins[0] >> 16) & 0x7fff;
nextAuxId:
			uint[] aux = auxBinStorage[auxIdx]._bins;

			if (len > numAuxRefs) {
				foreach (ref b; aux[0..numAuxRefs]) {
					if (dg(b)) {
						return;
					}
				}

				auxIdx = aux[numAuxRefs];
				assert (auxIdx != 0);
				len -= numAuxRefs;
				goto nextAuxId;
			} else {
				foreach (ref b; aux[0..len]) {
					if (dg(b)) {
						return;
					}
				}

				// failed to find it, add it
				(cast(ContactAuxBin*)aux.ptr).add(newItem, len);
				++*cast(ushort*)&_bins[0];
			}
		} else {
			foreach (ref b; _bins[1..len+1]) {
				if (dg(b)) {
					return;
				}
			}

			// failed to find it, add it
			add(newItem);
		}
	}

	void add(uint item) {
		assert (item != 0);
		uint auxId = void;

		uint len = cast(uint)*cast(ushort*)&_bins[0];
		if (len < numInitialRefs) {
			_bins[++len] = item;
			_bins[0] &= ~0x0000_ffff;
			_bins[0] |= len;
		} else {
			uint auxIdx = (_bins[0] >> 16) & 0x7fff;
			if (0 == auxIdx) {
				auxIdx = getAuxBinStorage();
				_bins[0] |= auxIdx << 16;
			}

			auxBinStorage[auxIdx].add(item, len-numInitialRefs);
			++len;
			*cast(ushort*)&_bins[0] = cast(ushort)len;
		}
	}

	// return true to remove
	void updateRemove(bool delegate(ref uint) dg) {
		uint len = _bins[0] & 0xffff;
		uint newLen = len;

		uint* newItems = cast(uint*)alloca(len * uint.sizeof);
		uint* nextItem = newItems;

		bool anyRemoved = false;

		foreach (ref item; *this) {
			if (dg(item)) {
				anyRemoved = true;
				--newLen;
			} else {
				*nextItem++ = item;
			}
		}

		if (!anyRemoved) {
			return;
		}

		*cast(ushort*)&_bins[0] = cast(ushort)newLen;

		void releaseAux(uint auxIdx, uint len) {
			if (len > numAuxRefs) {
				releaseAux(auxBinStorage[auxIdx]._bins[numAuxRefs], len - numAuxRefs);
			}
			.relaseAuxBinStorage(auxIdx);
			auxBinStorage[auxIdx]._bins[numAuxRefs] = 0;
		}

		if (newLen <= numInitialRefs) {
			uint auxIdx = (_bins[0] >> 16) & 0x7fff;
			if (auxIdx != 0) {
				assert (len > numInitialRefs);
				releaseAux(auxIdx, len - numInitialRefs);
				_bins[0] &= 0x8000_ffff;
			}
			_bins[1..newLen+1] = newItems[0..newLen];
		} else {
			_bins[1..numInitialRefs+1] = newItems[0..numInitialRefs];
			newItems += numInitialRefs;
			len -= numInitialRefs;
			newLen -= numInitialRefs;

			uint auxIdx = (_bins[0] >> 16) & 0x7fff;

nextAuxIdx:
			assert (auxIdx != 0);
			uint[] aux = auxBinStorage[auxIdx]._bins;

			if (newLen <= numAuxRefs) {
				aux[0..newLen] = newItems[0..newLen];
				if (len > numAuxRefs) {
					releaseAux(aux[numAuxRefs], len - numAuxRefs);
				}
			} else {
				aux[0..numAuxRefs] = newItems[0..numAuxRefs];
				newItems += numAuxRefs;
				len -= numAuxRefs;
				newLen -= numAuxRefs;
				auxIdx = aux[numAuxRefs];
				goto nextAuxIdx;
			}
		}
	}
}


private uint getAuxBinStorage() {
	synchronized (auxBinAllocMutex) {
		//Stdout.formatln("getAuxBinStorage");
		uint res = nextFreeAuxBin;
		assert (res != uint.max, "WTF, Out of aux bins D:");
		assert (res != 0);
		nextFreeAuxBin = auxBinStorage[res]._bins[0];
		return res;
	}
}


private void relaseAuxBinStorage(uint idx) {
	assert (idx != 0);

	synchronized (auxBinAllocMutex) {
		//Stdout.formatln("relaseAuxBinStorage");
		auxBinStorage[idx]._bins[0] = nextFreeAuxBin;
		nextFreeAuxBin = idx;
	}
}


private struct ContactAuxBin {
	private {
		// when unused, the first item contains the index of the next free aux bin
		uint[numAuxBins]	_bins;
	}

	void add(uint item, uint taken) {
		if (taken < numAuxRefs) {
			_bins[taken] = item;
			return;
		} else if (taken == numAuxRefs) {
			_bins[$-1] = getAuxBinStorage();
		}

		auxBinStorage[_bins[$-1]].add(item, taken - numAuxRefs);
	}
}


private ContactAuxBin[]	auxBinStorage;
private ContactBin[]		binStorage;
private uint			nextFreeAuxBin;
private Object			auxBinAllocMutex;


private extern (C) extern {
	void* malloc(size_t);
	void* alloca(size_t);
}


static this() {
	const size_t halfSize = 512 * 1024;
	void* chunk = malloc(halfSize * 2);
	auxBinStorage = cast(ContactAuxBin[])chunk[0..halfSize];
	binStorage = cast(ContactBin[])chunk[halfSize..halfSize*2];

	auxBinAllocMutex = new Object;

	// yea, yea, one is wasted...
	nextFreeAuxBin = 1;

	foreach (i, ref ab; auxBinStorage[0..$-1]) {
		ab._bins[0] = i+1;
	}
	auxBinStorage[$-1]._bins[0] = uint.max;
}


unittest { new class {
	import tango.io.Stdout;
	import tango.core.tools.TraceExceptions;

	this() {
		Stdout.formatln("Testing xf.boxen.ContactStorage...");

		void doTest() {
			auto bs = &binStorage[0];

			uint[] input;
			uint[] oddInput;

			for (int i = 1; i <= 40; ++i) {
				bs.add(i);
				input ~= i;
				if (i % 2 == 1) oddInput ~= i;
			}

			input ~= 666;
			bs.iterOrAdd((ref uint i) {
				return false;
			}, 666);

			uint[] output;
			foreach (i; *bs) {
				output ~= i;
			}

//				Stdout.formatln("Output: {}", output);

			assert (input == output);


			bs.updateRemove((ref uint i) {
				return i % 2 == 0;
			});

			output = null;
			foreach (i; *bs) {
				output ~= i;
			}
			assert (oddInput == output);

			for (int i = 1; i < 1000; ++i) {
				oddInput ~= i;
				bs.add(i);
			}

			output = null;
			foreach (i; *bs) {
				output ~= i;
			}

//				Stdout.formatln("Output: {}", output);
			assert (oddInput == output);

			bs.updateRemove((ref uint i) { return true; });
			assert (0 == bs.length);
			assert (1 == nextFreeAuxBin);
		}

		binStorage[0].setVisitedFlag();
		doTest();
		assert (true == binStorage[0].readVisitedFlag());

		binStorage[0].unsetVisitedFlag();
		doTest();
		assert (false == binStorage[0].readVisitedFlag());

	}
}; }

