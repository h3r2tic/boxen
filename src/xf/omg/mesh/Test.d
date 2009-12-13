module xf.omg.mesh.Test;

private {
	import xf.omg.mesh.Mesh;
	import xf.omg.mesh.Subdivision;
	import xf.omg.mesh.Logging;
	import tango.time.StopWatch;
	import xf.omg.core.LinearAlgebra;
	import xf.dog.Dog;
}




void printMesh(Mesh m) {
	uint faces = m.numFaces;
	for (int i = 0; i < faces; ++i) {
		auto face = m.face(cast(faceI)i);
		meshLog.info("Face({}) {}:", m.faceIdx(face), i);
		meshLog.tab;
		foreach (fh; m.faceHEdges(face)) {
			meshLog.info("HEdge(idx={}{})", m.hedgeIdx(fh), *fh);
			meshLog.tab;
			foreach (eh, opposite; m.edgeHEdges(fh)) {
				meshLog.info("adj:HEdge({}) {}", *eh, opposite ? "opposite" : "");
			}
			meshLog.utab;
		}
		meshLog.utab;
	}
}



void main() {
	auto m = Mesh.fromTriList([0, 1, 2,   2, 3, 0,  1, 0, 4]);
	//auto m = Mesh.fromTriList([0, 1, 2,   3, 4, 5]);
	vec2[] pos = [
		vec2(0, 0),
		vec2(1, 0),
		vec2(1, 1),
		vec2(0, 1),
		vec2(0.5, -1.5)
	];
	
	m.computeAdjacency((vertexI idx, void delegate(vertexI) adjIter) {
		// TODO
		/+switch (idx) {
			case 2: adjIter(3); break;
			case 3: adjIter(2); break;
			case 5: adjIter(0); break;
			case 0: adjIter(5); break;
			default: break;
		}+/
	});
	
	printMesh(m);
	
	auto sub = new Subdivider;
	sub.shouldSubdivideEdge = (vertexI a, vertexI b) {
		float dist = (pos[a] - pos[b]).length;
		meshLog.trace("dist = {}", dist);
		return dist * (pos[a].y + pos[b].y) > .1f;
		//return dist > .1f;
	};
	sub.interpAndAdd = (vertexI a, vertexI b, float t) {
		auto va = pos[a];
		auto vb = pos[b];
		auto vi = va * (1.f - t) + vb * t;
		pos ~= vi;
		meshLog.info("subdiv {}, {} -> {}", a, b, pos.length - 1);
		return cast(vertexI)(pos.length - 1);
	};
	
	StopWatch elapsed;
	elapsed.start;
	sub.subdivide(m);
	meshLog.msg("Mesh subdivided in {} ms", elapsed.stop * 1000);
	
	printMesh(m);


	auto context = GLWindow();
	context
		.title("xf.omg.mesh test")
		.width(640)
		.height(480)
	.create();
	
	use (context) in (GL gl) {
		gl.MatrixMode(GL_PROJECTION);
		gl.LoadIdentity();
		gl.gluPerspective(90.f, 1.333f, 0.1f, 100.f);
		gl.MatrixMode(GL_MODELVIEW);
	};
	
	while (context.created) {
		use(context) in (GL gl) {
			gl.Clear(GL_COLOR_BUFFER_BIT);
			gl.LoadIdentity();
			
			gl.Enable(GL_LINE_SMOOTH);
			gl.Enable(GL_POINT_SMOOTH);
			gl.Enable(GL_BLEND);
			gl.BlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
			gl.LineWidth(1);
			gl.PointSize(4);
			
			gl.Translatef(-.5f, 0, -1.1);
			
			vec2 faceCenter(Face* f) {
				vec2 c = vec2.zero;
				int cnt = 0;
				foreach (fh; m.faceHEdges(f)) {
					++cnt;
					c += pos[fh.vi];
				}
				c *= 1f / cnt;
				return c;
			}

			gl.Color3f(.2, .2, .2);
			gl.Begin(GL_TRIANGLES); {
				uint faces = m.numFaces;
				for (int i = 0; i < faces; ++i) {
					auto face = m.face(cast(faceI)i);
					int hedges = 0;
					foreach (fh; m.faceHEdges(face)) {
						++hedges;
						auto v0 = fh.vi;
						gl.Vertex2fv(pos[v0].ptr);
					}
					assert (3 == hedges);
				}
			} gl.End();
			
			gl.Color3f(1, 1, 1);
			gl.Begin(GL_LINES); {
				uint faces = m.numFaces;
				for (int i = 0; i < faces; ++i) {
					auto face = m.face(cast(faceI)i);
					foreach (fh; m.faceHEdges(face)) {
						auto v0 = fh.vi;
						auto v1 = fh.nextFaceHEdge(m).vi;
						
						gl.Vertex2fv(pos[v0].ptr);
						gl.Vertex2fv(pos[v1].ptr);
					}
				}
			} gl.End();


			gl.Begin(GL_LINES); {
				uint faces = m.numFaces;
				for (int i = 0; i < faces; ++i) {
					auto face = m.face(cast(faceI)i);
					auto c1 = faceCenter(face);
					
					foreach (fh; m.faceHEdges(face)) {
						foreach (eh, op; m.edgeHEdges(fh)) {
							if (op) {
								gl.Color3f(0, 1, 0);
							} else {
								gl.Color3f(1, 0, 0);
							}
							
							auto c2 = faceCenter(eh.face(m));
							gl.Vertex2fv(c1.ptr);
							gl.Vertex2fv(c2.ptr);
						}
					}
				}
			} gl.End();

			gl.Begin(GL_POINTS); {
				uint faces = m.numFaces;
				for (int i = 0; i < faces; ++i) {
					auto face = m.face(cast(faceI)i);
					auto c1 = faceCenter(face);
					gl.Color3f(0, 0, 1);
					gl.Vertex2fv(c1.ptr);
				}
			} gl.End();
		};

		context.update().show();
	}
}
