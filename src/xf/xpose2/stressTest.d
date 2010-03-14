module xf.xpose2.stressTest;

private {
	import xf.loader.scene.Hme;
	import xf.loader.scene.model.Node;
	import xf.loader.scene.model.Mesh;
	import xf.loader.scene.model.Scene;
	import xf.omg.core.Fixed;
	import xf.omg.core.LinearAlgebra;
	import xf.omg.core.CoordSys;
	
	import xf.xpose2.Expose;
	import xf.xpose2.Serialization;

	import tango.time.StopWatch;
	
	import Path = tango.io.Path;
}

public {
	alias Scene HmeScene;
	alias Node HmeNode;
	alias Mesh HmeMesh;
}


struct fixedWrap {
	mixin(xpose2(`fixed`, `store`));
	mixin xposeSerialization!(`fixed`);
}

struct vec2Wrap {
	mixin(xpose2(`vec2`, `x|y`));
	mixin xposeSerialization!(`vec2`);
}

struct vec3Wrap {
	mixin(xpose2(`vec3`, `x|y|z`));
	mixin xposeSerialization!(`vec3`);
}

struct quatWrap {
	mixin(xpose2(`quat`, `x|y|z|w`));
	mixin xposeSerialization!(`quat`);
}

struct vec3fiWrap {
	mixin(xpose2(`vec3fi`, `x|y|z`));
	mixin xposeSerialization!(`vec3fi`);
}

struct CoordSysWrap {
	mixin(xpose2(`CoordSys`, `origin|rotation`));
	mixin xposeSerialization!(`CoordSys`);
}

struct HmeSceneWrap {
	mixin(xpose2(`HmeScene`, `nodes`));
	mixin xposeSerialization!(`HmeScene`);
}

struct HmeNodeWrap {
	mixin(xpose2(`HmeNode`, `coordSys|children|meshes|name`));
	mixin xposeSerialization!(`HmeNode`);
}

struct HmeMeshWrap {
	static void unserialize(HmeMesh mesh, Unserializer s) {
		{
			size_t len;
			s(len);
			mesh.allocPositions(len);
			foreach (ref p; mesh.positions) s(p);
		}
		{
			size_t len;
			s(len);
			mesh.allocNormals(len);
			foreach (ref p; mesh.normals) s(p);
		}
		{
			size_t len;
			s(len);
			mesh.allocIndices(len);
			foreach (ref p; mesh.indices) s(p);
		}
	}
	static void serialize(HmeMesh mesh, Serializer s) {
		s(mesh.positions.length);
		foreach (p; mesh.positions) s(p);
		s(mesh.normals.length);
		foreach (p; mesh.normals) s(p);
		s(mesh.indices.length);
		foreach (p; mesh.indices) s(p);
	}

	mixin xposeSerialization!(`HmeMesh`, `serialize`, `unserialize`);
}



Scene unserial() {
	scope u = new Unserializer("tank.scene");
	auto res = u.get!(HmeScene);
	u.close;
	return res;
}

void main() {
	StopWatch timer;
	timer.start;
	for (int i = 0; i < 10; ++i) {
		auto scene = unserial();
		delete scene;
	}
	auto elapsed = timer.stop;
	Stdout.formatln("Unserialized in {} sec", elapsed);
}
