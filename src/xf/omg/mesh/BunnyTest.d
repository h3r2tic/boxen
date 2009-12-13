module xf.omg.mesh.BunnyTest;

private {
	import xf.omg.mesh.Mesh;
	import xf.omg.mesh.Subdivision;
	import xf.omg.mesh.Logging;
	import xf.rt.BunnyData;
	
	import tango.time.StopWatch;
	import xf.omg.core.LinearAlgebra;
	import xf.dog.Dog;
}



void main() {
	int[]		tris	= bunnyTriangles;
	vec3[]	pos	= cast(vec3[])bunnyVertices.dup;
	
	auto m = Mesh.fromTriList(tris);
	m.computeAdjacency((vertexI idx, void delegate(vertexI) adjIter) {});

	auto sub = new Subdivider;
	sub.shouldSubdivideEdge = (vertexI a, vertexI b) {
		float dist = (pos[a] - pos[b]).length;
		meshLog.trace("dist = {}", dist);
		return dist * pos[a].z > .05f;
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
	meshLog.msg("Mesh subdivided in {} ms; Faces: {}", elapsed.stop * 1000, m.numFaces);

	
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
	
	float yRot = 70.f;
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
			
			yRot += 0.2f;
			mat4 transform = mat4.translation(vec3(0, 0, -1.2)) * mat4.yRotation(yRot);
			gl.MultMatrixf(transform.ptr);
			
			vec3 faceCenter(Face* f) {
				vec3 c = vec3.zero;
				int cnt = 0;
				foreach (fh; m.faceHEdges(f)) {
					++cnt;
					c += pos[fh.vi];
				}
				c *= 1f / cnt;
				return c;
			}
			
			bool frontFacing(Face* f) {
				vec3[3] v;
				int vi;
				foreach (fh; m.faceHEdges(f)) {
					v[vi++] = transform * pos[fh.vi];
				}
				auto norm = cross(v[1]-v[0], v[2]-v[0]).normalized;
				return dot(norm, v[0]) < 0;
			}

			gl.Color3f(.2, .2, .2);
			gl.Begin(GL_TRIANGLES); {
				uint faces = m.numFaces;
				for (int i = 0; i < faces; ++i) {
					auto face = m.face(cast(faceI)i);
					if (!frontFacing(face)) continue;
					int hedges = 0;
					foreach (fh; m.faceHEdges(face)) {
						++hedges;
						auto v0 = fh.vi;
						gl.Vertex3fv(pos[v0].ptr);
					}
					assert (3 == hedges);
				}
			} gl.End();
			
			gl.Color3f(1, 1, 1);
			gl.Begin(GL_LINES); {
				uint faces = m.numFaces;
				for (int i = 0; i < faces; ++i) {
					auto face = m.face(cast(faceI)i);
					if (!frontFacing(face)) continue;
					foreach (fh; m.faceHEdges(face)) {
						auto v0 = fh.vi;
						auto v1 = fh.nextFaceHEdge(m).vi;
						
						gl.Vertex3fv(pos[v0].ptr);
						gl.Vertex3fv(pos[v1].ptr);
					}
				}
			} gl.End();


			gl.Begin(GL_LINES); {
				uint faces = m.numFaces;
				for (int i = 0; i < faces; ++i) {
					auto face = m.face(cast(faceI)i);
					if (!frontFacing(face)) continue;
					auto c1 = faceCenter(face);
					
					foreach (fh; m.faceHEdges(face)) {
						foreach (eh, op; m.edgeHEdges(fh)) {
							if (op) {
								gl.Color3f(0, 1, 0);
							} else {
								gl.Color3f(1, 0, 0);
							}
							
							auto c2 = faceCenter(eh.face(m));
							gl.Vertex3fv(c1.ptr);
							gl.Vertex3fv(c2.ptr);
						}
					}
				}
			} gl.End();

			gl.Begin(GL_POINTS); {
				uint faces = m.numFaces;
				for (int i = 0; i < faces; ++i) {
					auto face = m.face(cast(faceI)i);
					if (!frontFacing(face)) continue;
					auto c1 = faceCenter(face);
					gl.Color3f(0, 0, 1);
					gl.Vertex3fv(c1.ptr);
				}
			} gl.End();

			gl.Begin(GL_POINTS); {
				uint faces = m.numFaces;
				for (int i = 0; i < faces; ++i) {
					auto face = m.face(cast(faceI)i);
					if (!frontFacing(face)) continue;
					auto first = m.hedge(face.fhi);
					
					vec3 c = vec3.zero;
					uint num = 0;
					foreach (hr; m.hedgeRing(first)) {
						c += pos[hr.nextFaceHEdge(m).vi];
						++num;
					}
					c *= (1f / num);
					gl.Color3f(1, 0, 0);
					gl.Vertex3fv(c.ptr);
				}
			} gl.End();
		};

		context.update().show();
	}
}
