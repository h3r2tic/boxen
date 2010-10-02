module xf.utils.SimpleCamera;

private {
	import xf.input.Input;
	import xf.core.JobHub;
	import xf.omg.core.CoordSys;
	import xf.omg.core.LinearAlgebra : mat4, vec3, vec3fi, vec2, quat;
	import xf.omg.core.Misc : exp, min, max, abs;
	import xf.utils.Log;
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
		this.rot = quat.yRotation(this.yaw) * quat.xRotation(this.pitch);
		
		jobHub.addRepeatableJob(&update, updateFrequency);
	}
	
	
	private void update() {
		float seconds = 1.0f / this.updateFrequency;
		//vec3 move = vec3.zero;

		float accel = seconds * 3.5;
		bool zeroz = true, zerox = true, zeroy = true;
		
		if (keyboard.keyDown(this.FwdKey)) {
			move.z -= movementSpeed.z * accel;
			zeroz = false;
		}
		if (keyboard.keyDown(this.BckKey)) {
			move.z += movementSpeed.z * accel;
			zeroz = false;
		}
		if (keyboard.keyDown(this.LeftKey)) {
			move.x -= movementSpeed.x * accel;
			zerox = false;
		}
		if (keyboard.keyDown(this.RightKey)) {
			move.x += movementSpeed.x * accel;
			zerox = false;
		}
		if (keyboard.keyDown(this.UpKey)) {
			move.y += movementSpeed.y * accel;
			zeroy = false;
		}
		if (keyboard.keyDown(this.DownKey)) {
			move.y -= movementSpeed.y * accel;
			zeroy = false;
		}

		if (move.z > movementSpeed.z) move.z = movementSpeed.z;
		if (move.z < -movementSpeed.z) move.z = -movementSpeed.z;
		if (move.x > movementSpeed.x) move.x = movementSpeed.x;
		if (move.x < -movementSpeed.x) move.x = -movementSpeed.x;
		if (move.y > movementSpeed.y) move.y = movementSpeed.y;
		if (move.y < -movementSpeed.y) move.y = -movementSpeed.y;

		if (zeroz) move.z = 0;
		if (zerox) move.x = 0;
		if (zeroy) move.y = 0;
		
		if (keyboard.keyDown(KeySym.bracketleft)) {
			this.movementSpeed *= 1.0f / exp(seconds);
		}
		if (keyboard.keyDown(KeySym.bracketright)) {
			this.movementSpeed *= exp(seconds);
		}

		float angularDrift = 0.4f;

		{
			float t = min(1.0f, max(0.0f, 0.02*exp(seconds)));
			moveSpeed = moveSpeed * (1.0f-t) + (1.f - angularDrift) * move * t;
			driftMoveSpeed = driftMoveSpeed * (1.0f-t) + angularDrift * rot.xform(move) * t;
			pos += rot.xform(moveSpeed * seconds);
			pos += driftMoveSpeed * seconds;
		}
		{
			float t = min(1.0f, max(0.0f, 0.02*exp(seconds)));
			vec2 m = mouseSpeed * t;
			mouseSpeed -= m;
			pitch -= m.y * mouseSensitivity.y;
			yaw -= m.x * mouseSensitivity.x;
			rot = quat.yRotation(yaw) * quat.xRotation(pitch);
			rot.normalize();
		}

		if (move != move.zero) {
			utilsLog.info("camera pos: {} pitch: {} yaw: {}", this.pos, this.pitch, this.yaw);
		}
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
			this.outer.mouseSpeed += i.move;
			/+if (i.move != i.move.zero) {
				utilsLog.info("camera pitch: {}, yaw: {}", this.outer.pitch, this.outer.yaw);
			}+/
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

		vec3	move = vec3.zero;
		vec3	moveSpeed = vec3.zero;
		vec3	driftMoveSpeed = vec3.zero;
		vec2	mouseSpeed = vec2.zero;

		version (SimpleCameraQwerty) {
			const KeySym FwdKey = KeySym.w;
			const KeySym BckKey = KeySym.s;
			const KeySym LeftKey = KeySym.a;
			const KeySym RightKey = KeySym.d;
			const KeySym UpKey = KeySym.e;
			const KeySym DownKey = KeySym.q;
		} else {	// Colemak :D
			const KeySym FwdKey = KeySym.w;
			const KeySym BckKey = KeySym.r;
			const KeySym LeftKey = KeySym.a;
			const KeySym RightKey = KeySym.s;
			const KeySym UpKey = KeySym.f;
			const KeySym DownKey = KeySym.q;
		}
		
		SimpleKeyboardReader	keyboard;
	}
}
