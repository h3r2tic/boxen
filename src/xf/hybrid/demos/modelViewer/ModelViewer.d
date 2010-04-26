module ModelViewer;

private {
	import xf.hybrid.Hybrid;
	import xf.hybrid.backend.GL;
	import xf.hybrid.Common;
	import xf.hybrid.CustomWidget;

	import xf.loader.scene.Hme;
	import xf.loader.scene.model.Node;
	import xf.loader.scene.model.Mesh;
	import xf.loader.scene.model.Scene;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	import xf.omg.core.Misc;
	import xf.dog.Dog;

	import tango.core.Thread;
	import tango.util.log.Trace;
}


class ViewportControls : CustomWidget {
	mixin(defineProperties("float zoom, float x, float y, float z"));
	mixin MWidget;
}


void main() {
	version (DontMountExtra) {} else gui.vfsMountDir(`../../`);
	scope cfg = loadHybridConfig(`./ModelViewer.cfg`);
    scope renderer = new Renderer;
    
    SceneView[4] views;
    views[0] = new SceneView(
		CoordSys(vec3fi.zero, quat.xRotation(-45)), false, false);
		
    views[1] = new SceneView(
		CoordSys(vec3fi.zero, quat.identity), true, true);
		
    views[2] = new SceneView(
		CoordSys(vec3fi.zero, quat.xRotation(-90)), true, true);
		
    views[3] = new SceneView(
		CoordSys(vec3fi.zero, quat.yRotation(90)), true, true);

	gui.begin(cfg);
	with (ViewportControls(`main.view0ctrl`)) {
		y = 1;
		z = 1;
	}
	gui.end();

    bool programRunning = true;
    while (programRunning) {
        gui.begin(cfg).push(`main`);
            if (gui().getProperty!(bool)("frame.closeClicked")) {
                programRunning = false;
            }
            
            if (Button(`loadButton`).clicked) {
            	char[] path = Input(`pathInput`).text;
            	try {
					scope loader = new HmeLoader;
					loader.load(path);
					foreach (v; views) {
						v.scene = loader.scene;
					}
				} catch (Exception e) {
					Trace.formatln("Cannot load the scene: {}", e.toString);
				}
            }
            
            if (Button(`unloadButton`).clicked) {
				foreach (v; views) {
					v.scene = null;
				}
            }

            foreach (i, c; ['0', '1', '2', '3']) {
            	GLViewport(`view`~c).renderingHandler = &views[i].draw;
            	
				auto ctrl = ViewportControls(`view`~c~`ctrl`);
				views[i].coordSys.origin = vec3fi[ctrl.x, ctrl.y, ctrl.z];
				views[i].zoom = ctrl.zoom;
            }
        gui.pop.end();
        gui.render(renderer);
        Thread.yield();
    }
}


class SceneView {
	CoordSys	coordSys;
	CoordSys	objCS = CoordSys.identity;
	bool			ortho;
	Scene		scene;
	Light[]		lights;
	bool			wireframe;
	float			zoom = 0.f;
	
	static class Light {
		this (vec3 from, vec3 col, int lightId) {
			this.lightId = lightId;
			this.col = vec4(col.x, col.y, col.z, 0);
			this.from = vec4(from.x, from.y, from.z, 1);
		}

		void use(GL gl) {
			int lightId = GL_LIGHT0 + this.lightId;
			gl.Lightfv(lightId, GL_DIFFUSE, &col.x);
			gl.Lightfv(lightId, GL_POSITION, &from.x);
			gl.Enable(lightId);
		}

		int	lightId;
		vec4	col, from;
	}

	
	this (CoordSys coordSys, bool ortho, bool wireframe) {
		this.coordSys = coordSys;
		this.ortho = ortho;
		this.wireframe = wireframe;
		
		lights ~= new Light(vec3(0, 1, 1),	vec3(0.4, 0.5, 0.4), 0);
		lights ~= new Light(vec3(1, 1, 0),	vec3(0.4, 0.4, 0.7), 1);
		lights ~= new Light(vec3(-1, 1, -1),	vec3(0.8, 0.8, 0.4), 2);
		lights ~= new Light(vec3(0, -1, 0),	vec3(0.2, 0.5, 0.2), 3);
	}

	
	void draw(vec2i size, GL gl) {
		if (scene is null) {
			return;
		}
		
		gl.MatrixMode(GL_PROJECTION);
		gl.LoadIdentity();
		float aspect = cast(float)size.x / size.y;
		if (ortho) {
			float scale = pow(2, -zoom);
			gl.Ortho(scale*-aspect, scale*aspect, scale*-1, scale*1, -100, 100);
		} else {
			float fov = 90.f * pow(2, -zoom);
			gl.gluPerspective(fov, aspect, 0.1f, 100.f);
		}
		gl.MatrixMode(GL_MODELVIEW);		
		gl.LoadIdentity();
		
		gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		CoordSys viewCS = coordSys.inverse;
		gl.LoadMatrixf(viewCS.toMatrix.ptr);
		
		foreach (l; lights) {
			l.use(gl);
		}
		
		if (wireframe) {
			gl.PolygonMode(GL_FRONT_AND_BACK, GL_LINE);
		} else {
			gl.PolygonMode(GL_FRONT_AND_BACK, GL_FILL);
		}
		
		gl.withState(GL_DEPTH_TEST).withState(GL_LIGHTING) in {
			foreach (node; scene.nodes) {
				renderNode(gl, node, objCS);
			}
		};
	}
	
	void renderNode(GL gl, Node node, CoordSys cs) {
		foreach (n; &node.filterChildren!(Node)) {
			renderNode(gl, n, cs);
		}

		foreach (m; &node.filterChildren!(Mesh)) {
			renderMesh(gl, m, cs);
		}
	}

	void renderMesh(GL gl, Mesh mesh, CoordSys cs) {
		gl.PushMatrix();
		gl.MultMatrixf((cs in mesh.localCS).toMatrix.ptr);
		
		gl.immediate(GL_TRIANGLES, {
			gl.Color4f(1, 1, 1, 1);
			
			foreach (i; mesh.indices) {
				if (mesh.normals.length > 0) {
					gl.Normal3fv(mesh.normals[i].ptr);
				}
				
				gl.Vertex(mesh.positions[i]);
			}
		});
		
		gl.PopMatrix();
	}
}

void Vertex(V)(GL gl, V v) {
	static if (2 == V.dim) gl.Vertex2f(v.x, v.y);
	else static if (3 == V.dim) gl.Vertex3f(v.x, v.y, v.z);
	else static if (4 == V.dim) gl.Vertex4f(v.x, v.y, v.z, v.w);
}
