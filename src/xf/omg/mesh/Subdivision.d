module xf.omg.mesh.Subdivision;

private {
	import xf.omg.mesh.Mesh;
	import xf.omg.mesh.Logging;
	import xf.utils.data.BitSet : DynamicBitSet;
	
	import tango.util.container.Container : Container;
	import tango.util.container.CircularList;
	import tango.text.convert.Format;
	import tango.util.Convert;
}



class Subdivider {
	bool delegate(vertexI, vertexI)				shouldSubdivideEdge;
	vertexI delegate(vertexI, vertexI, float)	interpAndAdd;
	
	
	void subdivide(Mesh mesh) {
		struct QueueItem {
			faceI	fi;
			uint	numNewHEdges;
		}
		
		scope queue		= new CircularList!(QueueItem, Container.reap, Container.Chunk);
		scope enqueued	= new DynamicBitSet;
		scope isInterp	= new DynamicBitSet;		
		void processFace(Face* face) {
			// HACK: assumes triangles
			uint numTotalVerts;
			{
				uint numOrigVerts;
				foreach (h; mesh.faceHEdges(face)) {
					++numTotalVerts;
					if (!isInterp.isSet(mesh.hedgeIdx(h))) {
						++numOrigVerts;
					}
				}
				meshLog.trace("hedges: {}", {
					char[] res;
					foreach (h; mesh.faceHEdges(face)) {
						res ~= Format(" {}({})", mesh.hedgeIdx(h), h.vi);
					}
					return res;
				}());
				assert (3 == numOrigVerts, `only triangular meshes supported at the moment; got: ` ~ to!(char[])(numOrigVerts) ~ ` (total=` ~ to!(char[])(numTotalVerts) ~ `)`);
				assert (numTotalVerts <= 6);
			}
			
			
			hedgeI[6]	triHEdges;
			uint			numTriHEdges;
			uint			firstSubdiv;
			uint			numPreSub;
			
			uint			maxPreSub;
			
			meshLog.tab;
			foreach (h; mesh.faceHEdges(face)) {
				auto hi = mesh.hedgeIdx(h);
				meshLog.trace("hi = {}", hi);
				triHEdges[numTriHEdges++] = hi;
				
				// we only want non-subdivided hedges here
				if (isInterp.isSet(hi)) {
					if (0 == firstSubdiv) {
						firstSubdiv = numTriHEdges-1;
					}
					continue;
				}
				
				bool		nextSubdiv = false;
				hedgeI	nextHEdge;
				
				if (isInterp.isSet(h.nfhi)) {
					nextSubdiv	= true;
					nextHEdge		= h.nfhi;
					// already subdivided
					
					++numPreSub;
					maxPreSub = maxPreSub > h.nfhi ? maxPreSub : h.nfhi;
				} else if (shouldSubdivideEdge(h.vi, h.nextFaceHEdge(mesh).vi)) {
					// subdivide
					
					uint hedgesBefore = mesh.numHEdges;
					mesh.esplit(h, .5f, interpAndAdd);
					uint hedgesAfter = mesh.numHEdges;
					
					isInterp.resize(mesh.numHEdges);
					
					for (uint i = hedgesBefore; i < hedgesAfter; ++i) {
						isInterp.set(i);

						auto nfaceI = mesh.hedge(cast(hedgeI)i).fi;
						auto nface = mesh.face(nfaceI);
						if (nface !is face) {
							if (!enqueued.isSet(nfaceI)) {
								meshLog.trace("enqueue {}, 0 due to adj hedge split", nfaceI);
								queue.append(QueueItem(nfaceI, 0));
								enqueued.set(nfaceI);
							} else {
								meshLog.trace("NOT enqueued {}, 0 despite adj hedge split", nfaceI);
							}
						} else {
							assert (false == nextSubdiv);
							nextSubdiv	= true;
							nextHEdge		= cast(hedgeI)i;
							meshLog.trace("enqueue null, 1 due to local hedge split", nfaceI);
							queue.append(QueueItem(faceI.init, 1));
						}
					}
				} else {
					// this hedge goes as a whole
				}
			}
			meshLog.utab;
			
			assert (numTotalVerts - 3 == numPreSub, to!(char[])(numTotalVerts - 3) ~ " != " ~ to!(char[])(numPreSub));

			
			assert (numTriHEdges >= 3 && numTriHEdges <= 6, `tris only, ktnx; got: ` ~ to!(char[])(numTriHEdges));
			if (numTriHEdges > 3) {
				assert (firstSubdiv > 0);
			}
			
			if (3 == numTriHEdges) {
				// no subdivision for you, sad face
			} else {
				subdivTriangle(mesh, face, triHEdges[0..numTriHEdges], firstSubdiv, isInterp, (faceI fi, uint numH) {
					enqueued.resize(mesh.numFaces);
					assert (!enqueued.isSet(fi));

					meshLog.trace("enqueue {}, {} due to tri split", fi, numH);
					queue.append(QueueItem(fi, numH));
					enqueued.set(fi);
				});
			}
		}
	
		scope processed = new DynamicBitSet;
		
		enqueued.resize(mesh.numFaces);
		isInterp.resize(mesh.numHEdges);
		processed.resize(mesh.numFaces);
		
		for (faceI i = 0; i < mesh.numFaces; ++i) {
			if (processed.isSet(i)) {
				continue;
			}
			
			queue.append(QueueItem(i, 0));
			enqueued.set(i);
			
			while (!queue.isEmpty) {
				meshLog.trace("queue ={}", {
					char[] res;
					foreach (q; queue) {
						res ~= Format(" ({},{})", q.fi, q.numNewHEdges);
					}
					return res;
				}());
				
				auto head = queue.removeHead();

				if (faceI.init != head.fi) {
					enqueued.clear(head.fi);
					processed.resize(mesh.numFaces);
					processed.set(head.fi);
					processFace(mesh.face(head.fi));
				}
			}
		}
	}
	
	
	void subdivTriangle(Mesh mesh, Face* face, hedgeI[] triHEdges, uint firstSubdiv, DynamicBitSet isInterp, void delegate(faceI, uint) enqueue) {
		hedgeI hedge(uint i) {
			return triHEdges[(i+firstSubdiv) % triHEdges.length];
		}
		
		assert (isInterp.isSet(hedge(0)));
		meshLog.trace("rotated hedges:", {
			char[] res;
			for (int i = 0; i < triHEdges.length; ++i) {
				res ~= Format(" {}", hedge(i));
			}
			return res;
		}());
		
		hedgeI rh, lh;
		bool rhnew	= isInterp.isSet(rh = hedge(2));
		bool lhnew		= isInterp.isSet(lh = hedge(rhnew ? 4 : 3));

		foreach (h; mesh.faceHEdges(face)) {
			auto hi = mesh.hedgeIdx(h);
			isInterp.clear(hi);
		}
		
		bool faceReused = false;
		void mkTri(hedgeI h0i, hedgeI h0op, hedgeI h1i, hedgeI h1op, hedgeI h2i, hedgeI h2op) {
			faceI fi;
			if (faceReused) {
				fi = mesh.addFace(h0i);
			} else {
				face.fhi = h0i;
				faceReused = true;
				fi = mesh.faceIdx(face);
			}
			
			meshLog.trace("mktri {} : {} {} {}", fi, h0i, h1i, h2i);

			auto h0 = mesh.hedge(h0i);
			auto h1 = mesh.hedge(h1i);
			auto h2 = mesh.hedge(h2i);
			
			h0.fi = fi;
			h1.fi = fi;
			h2.fi = fi;
			
			assert (h0i != h1i);
			assert (h0i != h2i);
			assert (h1i != h2i);
			
			h0.nfhi = h1i;
			h1.nfhi = h2i;
			h2.nfhi = h0i;
			
			uint numNew;
			if (h0op != hedgeI.init) { h0.nehi = h0op; h0.setNextEdgeHEdgeOpposite(true); ++numNew; }
			if (h1op != hedgeI.init) { h1.nehi = h1op; h1.setNextEdgeHEdgeOpposite(true); ++numNew; }
			if (h2op != hedgeI.init) { h2.nehi = h2op; h2.setNextEdgeHEdgeOpposite(true); ++numNew; }
			
			enqueue(fi, numNew);
		}
		
		hedgeI mkHEdge(hedgeI base) {
			return mesh.addHEdge(HEdge(mesh.hedge(base).vi));
		}
		
		if (lhnew && rhnew) {
			meshLog.trace("lhnew && rhnew");
			assert (6 == triHEdges.length);
			// 4 tris
			hedgeI rTriH		= mkHEdge(hedge(2));
			hedgeI tTriH		= mkHEdge(hedge(4));
			hedgeI lTriH		= mkHEdge(hedge(0));
			hedgeI mTriH0	= mkHEdge(hedge(0));
			hedgeI mTriH1	= mkHEdge(hedge(2));
			hedgeI mTriH2	= mkHEdge(hedge(4));
			isInterp.resize(mesh.numHEdges);
			
			mkTri(hedge(0), hedgeI.init, hedge(1), hedgeI.init, rTriH, mTriH0);
			mkTri(hedge(2), hedgeI.init, hedge(3), hedgeI.init, tTriH, mTriH1);
			mkTri(hedge(4), hedgeI.init, hedge(5), hedgeI.init, lTriH, mTriH2);
			
			mkTri(mTriH0, rTriH, mTriH1, tTriH, mTriH2, lTriH);
		} else if (rhnew && !lhnew) {
			meshLog.trace("rhnew");
			assert (5 == triHEdges.length);
			// tri on right, quad on left
			hedgeI rTriH		= mkHEdge(hedge(2));
			hedgeI mTriH0	= mkHEdge(hedge(0));
			hedgeI mTriH2	= mkHEdge(hedge(3));
			hedgeI lTriH		= mkHEdge(hedge(0));
			isInterp.resize(mesh.numHEdges);
			
			mkTri(hedge(0), hedgeI.init, hedge(1), hedgeI.init, rTriH, mTriH0);
			mkTri(mTriH0, rTriH, hedge(2), hedgeI.init, mTriH2, lTriH);
			mkTri(lTriH, mTriH2, hedge(3), hedgeI.init, hedge(4), hedgeI.init);
		} else if (!rhnew && lhnew) {
			meshLog.trace("lhnew");
			assert (5 == triHEdges.length);
			// quad on right, tri on left
			hedgeI rTriH		= mkHEdge(hedge(2));
			hedgeI mTriH0	= mkHEdge(hedge(0));
			hedgeI mTriH2	= mkHEdge(hedge(3));
			hedgeI lTriH		= mkHEdge(hedge(0));
			isInterp.resize(mesh.numHEdges);
			
			mkTri(hedge(0), hedgeI.init, hedge(1), hedgeI.init, rTriH, mTriH0);
			mkTri(mTriH0, rTriH, hedge(2), hedgeI.init, mTriH2, lTriH);
			mkTri(lTriH, mTriH2, hedge(3), hedgeI.init, hedge(4), hedgeI.init);
		} else {
			meshLog.trace("nup");
			assert (4 == triHEdges.length);
			// tri on right, tri on left			
			hedgeI rTriH	= mkHEdge(hedge(2));
			hedgeI lTriH	= mkHEdge(hedge(0));
			isInterp.resize(mesh.numHEdges);
			
			mkTri(hedge(0), hedgeI.init, hedge(1), hedgeI.init, rTriH, lTriH);
			mkTri(lTriH, rTriH, hedge(2), hedgeI.init, hedge(3), hedgeI.init);
		}
	}
}
