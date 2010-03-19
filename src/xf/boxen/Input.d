module xf.boxen.Input;

private {
	import xf.input.Input;
	import xf.input.KeySym;
	import xf.omg.core.LinearAlgebra : vec2;
}



struct PlayerInput {
	byte thrust;
	byte strafe;
	vec2 rot = vec2.zero;
	bool shoot;
	bool use;
	mixin MInput;
}

byte maxThrust = 127;


class PlayerInputMap : InputConverter {
	class Map : InputReader {
		bool	keys[KeySym];
		bool	joyFire = false;
		
		void onInput(KeyboardInput* i) {
			keys[i.keySym] = i.type == i.type.Down ? true : false;
		}
		
		void onInput(MouseInput* i) {
			PlayerInput pinput;
			pinput.rot.x -= i.move.x;
			pinput.rot.y -= i.move.y;
			if ((i.buttons & i.buttons.Left) && i.type.ButtonDown == i.type) {
				pinput.shoot = true;
			}
			outgoing << pinput;
			outgoing.dispatchOne();
		}

		bool keyDown(KeySym k) {
			if (auto s = k in keys) {
				return *s;
			} else {
				return false;
			}
		}
		
		bool keyDown(char k) {
			return keyDown(cast(KeySym)k);
		}

		void feedKeyboardInput() {
			PlayerInput pinput;
			if (keyDown('i'))	pinput.thrust -= maxThrust;
			if (keyDown('k'))	pinput.thrust += maxThrust;
			if (keyDown('j'))	pinput.strafe -= maxThrust;
			if (keyDown('l'))	pinput.strafe += maxThrust;
			
			if (keyDown('e')) {
				pinput.use = true;
				keys[KeySym.e] = false;
			}
			
			outgoing << pinput;
			outgoing.dispatchOne();
		}
		
		this() {
			registerReader!(KeyboardInput)(&this.onInput);
			//registerReader!(MouseInput)(&this.onInput);
		}
	}
	
	
	void update() {
		map.feedKeyboardInput();
	}


	this(InputChannel incoming) {
		super(incoming);
		incoming.addReader(this.map = new Map);
	}
	
	
	private Map map;
}


class PlayerInputSampler : InputReader {
	void onInput(PlayerInput* inp) {
		byte abs(byte a) { return a > 0 ? a : -a; }
		if (abs(inp.thrust) > abs(input.thrust)) input.thrust = inp.thrust;
		if (abs(inp.strafe) > abs(input.strafe)) input.strafe = inp.strafe;
		input.rot += inp.rot;
		input.use |= inp.use;
		input.shoot |= inp.shoot;
	}


	this() {
		registerReader!(PlayerInput)(&this.onInput);
		outgoing = new InputChannel;
	}
	
	
	void sample() {
		outgoing << input;
		outgoing.dispatchOne();
		input = input.init;
	}
	

	PlayerInput	input;
	InputChannel	outgoing;
}
