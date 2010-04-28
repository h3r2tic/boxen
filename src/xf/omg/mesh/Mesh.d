module xf.omg.mesh.Mesh;

private {
	import xf.omg.mesh.Log;
	import xf.utils.Meta : createFructIterator;
	import xf.utils.Memory;
	import tango.stdc.stdlib : alloca;
	import tango.text.convert.Format;
	import Array = tango.core.Array;
	
	import tango.util.container.HashMap;
}



typedef uint hedgeI	= uint.max;
typedef uint vertexI	= uint.max;
typedef uint faceI		= uint.max;



struct HEdge {
	HEdge* nextFaceHEdge(Mesh mesh) {
		return &mesh._hedges[nfhi];
	}
	
	
	void nextFaceHEdge(Mesh mesh, HEdge* x) {
		nfhi = cast(hedgeI)(x - mesh._hedges.ptr);
	}
	
	
	HEdge* nextEdgeHEdge(Mesh mesh) {
		return &mesh._hedges[nehi & 0x7fffffff];
	}


	void nextEdgeHEdge(Mesh mesh, HEdge* x) {
		nehi = cast(hedgeI)(x - mesh._hedges.ptr);
	}
	
	
	bool isNextEdgeHEdgeOpposite() {
		return 0 == (nehi & 0x80000000);
	}
	

	void setNextEdgeHEdgeOpposite(bool val) {
		if (val) {
			nehi &= ~0x80000000;
		} else {
			nehi |= 0x80000000;
		}
	}
	
	
	char[] toString() {
		return Format("vtx={},face={}", vi, fi);
	}

	
	Face* face(Mesh mesh) {
		return &mesh._faces[fi];
	}
	
	
	public {
		vertexI	vi;		// vertex index
	}
	
	package {
		faceI		fi;			// face index
		hedgeI	nfhi;		// next hedge in a face
		hedgeI	nehi;		// next hedge in an edge
	}
}


struct Face {
	hedgeI	fhi;		// first hedge index
}


class Mesh {
	alias HashMap!(vertexI, hedgeI, Container.hash, Container.reap, Container.Malloc) V2HMap;
	
	Face[]		_faces;
	HEdge[]	_hedges;
	
	
	// TODO
	hedgeI addHEdge(HEdge h) {
		_hedges ~= h;
		return cast(hedgeI)(_hedges.length - 1);
	}
	
	
	// TODO
	faceI addFace(hedgeI firstHEdge) {
		_faces ~= Face(firstHEdge);
		return cast(faceI)(_faces.length - 1);
	}
	
	
	HEdge* hedge(hedgeI i) {
		return &_hedges[i];
	}
	
	
	hedgeI hedgeIdx(HEdge* h) {
		return cast(hedgeI)(h - _hedges.ptr);
	}
	
	
	Face* face(faceI i) {
		return &_faces[i];
	}
	
	
	faceI faceIdx(Face* f) {
		return cast(faceI)(f - _faces.ptr);
	}
	
	
	uint numFaces() {
		return _faces.length;
	}
	
	
	uint numHEdges() {
		return _hedges.length;
	}
	
	
	static Mesh fromTriList(int[] indices) {
		assert (indices.length > 0);
		assert (indices.length % 3 == 0);

		auto m = new Mesh;
		
		for (int i = 0; i < indices.length; i += 3) {
			vertexI vi0 = cast(vertexI)indices[i+0];
			vertexI vi1 = cast(vertexI)indices[i+1];
			vertexI vi2 = cast(vertexI)indices[i+2];
			
			hedgeI hi0 = m.addHEdge(HEdge(vi0));
			hedgeI hi1 = m.addHEdge(HEdge(vi1));
			hedgeI hi2 = m.addHEdge(HEdge(vi2));
			
			auto h0 = m.hedge(hi0);
			auto h1 = m.hedge(hi1);
			auto h2 = m.hedge(hi2);
			
			auto fi = m.addFace(hi0);
			
			h0.fi = fi;
			h0.nfhi = hi1;
			h0.nehi = hi0;
			h0.setNextEdgeHEdgeOpposite = false;
			
			h1.fi = fi;
			h1.nfhi = hi2;
			h1.nehi = hi1;
			h1.setNextEdgeHEdgeOpposite = false;

			h2.fi = fi;
			h2.nfhi = hi0;
			h2.nehi = hi2;
			h2.setNextEdgeHEdgeOpposite = false;
		}
		
		return m;
	}
	
	
	// unsafe when the hedges change
	private int _edgeHEdges(HEdge* first, int delegate(ref HEdge*, ref bool opposite) dg) {
		bool opposite = first.isNextEdgeHEdgeOpposite;
		for (HEdge* cur = first.nextEdgeHEdge(this); cur != first; cur = cur.nextEdgeHEdge(this)) {
			if (auto r = dg(cur, opposite)) {
				return r;
			}
			opposite ^= cur.isNextEdgeHEdgeOpposite;
		}
		return 0;
	}
	mixin createFructIterator!(`edgeHEdges`);


	// unsafe when the hedges change
	// BUG: doesn't work properly with edge/corner faces (need to walk the ring in the other direction too, since there's no full ring)
	private int _hedgeRing(HEdge* first, int delegate(ref HEdge*) dg) {
		if (auto r = dg(first)) {
			return r;
		}
		
		if (first.isNextEdgeHEdgeOpposite) {
			for (HEdge* cur = first.nextEdgeHEdge(this).nextFaceHEdge(this); cur != first; cur = cur.nextEdgeHEdge(this).nextFaceHEdge(this)) {
				if (auto r = dg(cur)) {
					return r;
				}
				if (!cur.isNextEdgeHEdgeOpposite) {
					break;
				}
			}
		}
		return 0;
	}
	mixin createFructIterator!(`hedgeRing`);


	// safe when hedges change
	private int _faceHEdges(Face* face, int delegate(ref HEdge*) dg) {
		auto first = face.fhi;
		auto val = &this._hedges[first];
		if (auto r = dg(val)) {
			return r;
		}
		
		for (hedgeI cur = this.hedge(first).nfhi; cur != first; cur = this.hedge(cur).nfhi) {
			val = &this._hedges[cur];
			if (auto r = dg(val)) {
				return r;
			}
		}
		return 0;
	}
	mixin createFructIterator!(`faceHEdges`);
	
	
	private void findHEdgesPerVertex(V2HMap v2hi, hedgeI[] nvhi) {
		foreach (hi_, h; _hedges) {
			auto hi = cast(hedgeI)hi_;
			if (v2hi.containsKey(h.vi)) {
				// connect using nvhi
				hedgeI fvhi = v2hi[h.vi];
				nvhi[hi] = nvhi[fvhi];
				nvhi[fvhi] = hi;
				//meshLog.trace("another hedge using vertex {} : {}", h.vi, hi);
			} else {
				v2hi[h.vi] = hi;
				//meshLog.trace("first hedge using vertex {} : {}", h.vi, hi);
			}
		}
		
		// link loose ends to create cycles
		foreach (vi, hi; v2hi) {
			auto last = hi;
			while (nvhi[last] != hedgeI.init) {
				last = nvhi[last];
			}
			nvhi[last] = hi;
		}
		
		// create self-referencing cycles for the rest
		foreach (i, ref hi; nvhi) {
			if (hedgeI.init == hi) {
				hi = cast(hedgeI)i;
			}
		}
		
		// nvhi is circular now
	}
	
	
	private void findHEdgesSharingVertices(V2HMap v2hi, hedgeI[] nvhi, void delegate(vertexI idx, void delegate(vertexI) adjIter) adjLookup, bool[] done) {
		auto nvhiIter = (hedgeI i) { return nvhi[i]; };
		
		foreach (hi_, ref nhi; nvhi) {
			if (done[hi_]) {
				continue;		// done
			}
			auto hi = cast(hedgeI)hi_;
			
			auto vi = hedge(hi).vi;
			adjLookup(vi, (vertexI adjVi) {
				auto adjHi = v2hi[adjVi];
				mergeCircular(hi, adjHi, nvhiIter, (hedgeI i, hedgeI next) { nvhi[i] = next; });
			});

			iterCircular(hi, nvhiIter, (hedgeI i) {
				//meshLog.trace("done[{}] = true", i);
				done[i] = true;
			});
			
			/+meshLog.trace("HEdges starting at vertex {}: {}", hedge(hi).vi, {
				char[] res;
				iterCircular(hi, nvhiIter, (hedgeI i) {
					done[i] = true;
					res ~= Format(" {}", i);
				});
				return res;
			}());+/
		}
	}
	
	
	void computeAdjacency(void delegate(vertexI idx, void delegate(vertexI) adjIter) adjLookup) {
		hedgeI[] nvhi;
		nvhi.alloc(_hedges.length);
		scope (exit) nvhi.free();
		assert (nvhi[0] == uint.max);
		scope v2hi = new V2HMap;
		auto nvhiIter = (hedgeI i) { return nvhi[i]; };

		bool[] done;
		done.alloc(_hedges.length);
		scope (exit) done.free();
		
		findHEdgesPerVertex(v2hi, nvhi);
		findHEdgesSharingVertices(v2hi, nvhi, adjLookup, done);
		done[] = false;
		
		// TODO: same direction adjacency for non-manifolds
		
		foreach (vi1, hi1_; v2hi) {
			// find all hedges going out from vi1
			iterCircular(hi1_, nvhiIter, (hedgeI hi1) {
				if (!done[hi1]) {
					//done[hi1] = true;
					
					auto h1 = hedge(hi1);
					auto hi2_ = h1.nfhi;
					
					// find all hedges going out from the target of h1
					iterCircular(hi2_, nvhiIter, (hedgeI hi2) {
						auto h2 = hedge(hi2);
						if (!done[hi2]) {
							auto vi2 = h2.vi;
							
							// if the hedge returns to vi1, we've got adjacency
							auto hi3_ = h2.nfhi;
							auto h3_ = hedge(hi3_);
							auto h3 = v2hi[h3_.vi];
							
							if (h3 == hi1_) {
								//done[hi2] = true;
								
								// adjacency!
								//meshLog.trace("HEdge({}) is adjacent to HEdge({})", *h1, *h2);
								mergeCircular(hi1, hi2,
									(hedgeI i) {
										return hedgeIdx(hedge(i).nextEdgeHEdge(this));
									},
									(hedgeI i, hedgeI next) {
										hedge(i).nextEdgeHEdge(this, hedge(next));
										hedge(i).setNextEdgeHEdgeOpposite(true);
									}
								);
							}
						}
					});
				}
			});
		}
	}
	
	
	hedgeI esplit(HEdge* hinit, float t, vertexI delegate(vertexI, vertexI, float) interpAndAdd) {
		uint numEdgeHEdges = 1;
		foreach (eh, op; edgeHEdges(hinit)) {
			++numEdgeHEdges;
		}
		struct OrientedHEdge {
			hedgeI	idx;
			bool		opposite;
			vertexI	nvi;
			hedgeI	nhi;
			union {
				struct {
					vertexI	v0;
					vertexI	v1;
				}
				static assert (4 == vertexI.sizeof);
				ulong		key;
			}
		}
		
		mixin (lightweightArray(`OrientedHEdge`, `orientedHEdges`, `numEdgeHEdges`));
		foreach (eh, op; edgeHEdges(hinit)) {
			orientedHEdges[--numEdgeHEdges] = OrientedHEdge(hedgeIdx(eh), op);
		}
		orientedHEdges[--numEdgeHEdges] = OrientedHEdge(hedgeIdx(hinit), false);
		assert (0 == numEdgeHEdges);
		
		foreach (ref oe; orientedHEdges) {
			if (oe.opposite) {
				oe.v0 = hedge(oe.idx).nextFaceHEdge(this).vi;
				oe.v1 = hedge(oe.idx).vi;
			} else {
				oe.v0 = hedge(oe.idx).vi;
				oe.v1 = hedge(oe.idx).nextFaceHEdge(this).vi;
			}
		}
		
		Array.sort(orientedHEdges, (ref OrientedHEdge a, ref OrientedHEdge b) { return a.key < b.key; });
		
		OrientedHEdge* prev = null;
		foreach (ref oe; orientedHEdges) {
			if (prev !is null && prev.key == oe.key) {
				oe.nvi = prev.nvi;
			} else {
				prev = &oe;
				oe.nvi = interpAndAdd(oe.v0, oe.v1, oe.opposite ? 1.f - t : t);
			}
		}
		
		foreach (ref oe; orientedHEdges) {
			assert (oe.nvi != vertexI.init);
			oe.nhi = addHEdge(HEdge(oe.nvi));
			auto h = hedge(oe.idx);
			auto nh = hedge(oe.nhi);
			nh.fi = h.fi;
			nh.nfhi = h.nfhi;
			h.nfhi = oe.nhi;
		}
		
		void connectEdges(OrientedHEdge oe, OrientedHEdge oen) {
			auto h = hedge(oe.idx);
			auto nh = hedge(oe.nhi);
			
			if (oen.opposite != oe.opposite) {
				h.nextEdgeHEdge(this, hedge(oen.nhi));
				nh.nextEdgeHEdge(this, hedge(oen.idx));
				h.setNextEdgeHEdgeOpposite(true);
				nh.setNextEdgeHEdgeOpposite(true);
			} else {
				h.nextEdgeHEdge(this, hedge(oen.idx));
				nh.nextEdgeHEdge(this, hedge(oen.nhi));
				h.setNextEdgeHEdgeOpposite(false);
				nh.setNextEdgeHEdgeOpposite(false);
			}
		}
		
		foreach (oei, ref oe; orientedHEdges[0..$-1]) {
			auto oen = orientedHEdges[oei+1];
			connectEdges(oe, oen);
		}
		connectEdges(orientedHEdges[$-1], orientedHEdges[0]);
		
		return orientedHEdges[0].nhi;
	}
}


// HACK: assumes 200 bytes of stack space is available
char[] lightweightArray(char[] type, char[] name, char[] len) {
	return `
		bool		free_`~name~`_ = (`~len~`) * `~type~`.sizeof > 200;
		`~type~`[]	`~name~` = (cast(`~type~`*)alloca(free_`~name~`_ ? 0 : (`~len~`) * `~type~`.sizeof))[0..(`~len~`)];
		if (free_`~name~`_) {
			`~name~` = null;
			`~name~`.alloc((`~len~`));
		}
		scope (exit) if (free_`~name~`_) {
			`~name~`.free();
		}`;
}


void mergeCircular(I)(I as, I bs, I delegate(I) getNext, void delegate(I, I) setNext) {
	if (as == bs) return;
	
	bool proceed = true;
	
	I findEnd(I start, I failOut) {
		I end = start;
		I next;
		while ((next = getNext(end)) != start) {
			end = next;
			if (failOut == next) {
				proceed = false;
				break;
			}
		}
		return end;
	}
	
	I ae = findEnd(as, bs);
	
	if (proceed) {
		I be = findEnd(bs, as);

		if (proceed) {
			
			assert (ae != bs);
			assert (be != as);
			/+if (ae == bs) return;
			if (be == as) return;+/
			
			setNext(ae, bs);
			setNext(be, as);
		}
	}
}


void iterCircular(I)(I start, I delegate(I) getNext, void delegate(I) dg) {
	dg(start);
	for (I it = getNext(start); it != start; it = getNext(it)) {
		dg(it);
	}
}
