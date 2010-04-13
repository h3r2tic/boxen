module xf.utils.SimpleCamera;

private {
	import xf.input.Input;
	import xf.core.JobHub;
	import xf.omg.core.CoordSys;
	import xf.omg.core.LinearAlgebra : mat4, vec3, vec3fi, vec2, quat;
	import xf.omg.core.Misc : exp;
}



class SimpleCamera {
	this(vec3 pos, float pitch, float yaw, InputChannel ch, int updateFrequency = 200) {
		keyboard = new SimpleKeyboardReader(ch);
		auto mouse = this.new MouseReader;
		ch.addReader(mouse);
		this.pos = pos;
		this.pitch = pitch;
		this.yaw = yaw;
		this.updateFrequency = updateFrequency;
		
		jobHub.addRepeatableJob(&update, updateFrequency);
	}
	
	
	private void update() {
		float seconds = 1.0f / this.updateFrequency;
		vec3 move = vec3.zero;
		
		if (keyboard.keyDown(KeySym.w)) {
			move.z -= 1.f * movementSpeed.z;
		}
		if (keyboard.keyDown(KeySym.s)) {
			move.z += 1.f * movementSpeed.z;
		}
		if (keyboard.keyDown(KeySym.a)) {
			move.x -= 1.f * movementSpeed.x;
		}
		if (keyboard.keyDown(KeySym.d)) {
			move.x += 1.f * movementSpeed.x;
		}
		if (keyboard.keyDown(KeySym.bracketleft)) {
			this.movementSpeed *= 1.0f / exp(seconds);
		}
		if (keyboard.keyDown(KeySym.bracketright)) {
			this.movementSpeed *= exp(seconds);
		}
		
		pos += rot.xform(move) * seconds;
	}
	
	
	mat4 getMatrix() {
		quat r = rot.inverse;
		vec3 p = r.xform(-pos);
		auto res = r.toMatrix!(4, 4)();
		res.setTranslation(p);
		return res;
	}
	
	
	vec3 position() {
		return pos;
	}
	
	
	quat orientation() {
		return rot;
	}


	CoordSys coordSys() {
		return CoordSys(vec3fi.from(pos), rot);
	}
	

	class MouseReader : InputReader {
		void handle(MouseInput* i) {
			this.outer.pitch -= i.move.y * mouseSensitivity.y;
			this.outer.yaw -= i.move.x * mouseSensitivity.x;
			this.outer.rot = quat.yRotation(this.outer.yaw) * quat.xRotation(this.outer.pitch);
		}
	   
		this() {
			registerReader!(MouseInput)(&this.handle);
		}
	}
	
	
	public {
		vec2	mouseSensitivity = { x: 0.2f, y: 0.2f };
		vec3	movementSpeed = { x: 3.0f, y: 3.0f, z: 3.0f };
	}
	
	private {
		float	pitch = 0.f;
		float	yaw = 0.f;
		vec3	pos = vec3.zero;
		quat	rot = quat.identity;
		int		updateFrequency;
		
		SimpleKeyboardReader	keyboard;
	}
}
