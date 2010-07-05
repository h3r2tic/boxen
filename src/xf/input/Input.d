module xf.input.Input;

private {
	import xf.input.KeySym;
	import xf.omg.core.LinearAlgebra : vec2i;
	import xf.mem.ChunkQueue;
}

public {
	alias xf.input.KeySym.KeySym KeySym;
}



alias ubyte InputType;
InputType	_lastInputType = 0;
TypeInfo[]	_inputTypeInfos;


template MInput() {
	static InputType _inputTypeId;

	static this() {
		_inputTypeId = ._lastInputType++;
		._inputTypeInfos ~= typeid(typeof(*this));
	}
}


struct KeyboardInput {
	enum Type {
		Down,
		Up
	}
	
	enum Modifiers {
		NONE 	= 0x0000,
		LSHIFT	= 0x0001,
		RSHIFT	= 0x0002,
		LCTRL	= 0x0040,
		RCTRL	= 0x0080,
		LALT	= 0x0100,
		RALT	= 0x0200,
		LMETA	= 0x0400,
		RMETA	= 0x0800,
		NUM		= 0x1000,
		CAPS	= 0x2000,
		MODE	= 0x4000,
	
		CTRL	= LCTRL		|	RCTRL,
		SHIFT	= LSHIFT	|	RSHIFT,
		ALT		= LALT		|	RALT,
		META	= LMETA		|	RMETA
	}
	
	Modifiers	modifiers;
	KeySym		keySym;
	dchar		unicode;
	Type		type;
	
	mixin MInput;
}


struct MouseInput {
	enum Button {
		Left		= 1,
		Middle		= 2,
		Right		= 4,
		WheelUp		= 8,
		WheelDown	= 16,
		WheelLeft	= 32,
		WheelRight	= 64,
	}

	enum Type {
		Move,
		ButtonUp,
		ButtonDown
	}

	vec2i	position;
	vec2i	move;
	vec2i	global;
	Button	buttons;
	Type	type;

	mixin MInput;
}


bool isWheelInput(MouseInput.Button bttn) {
	switch (bttn) {
		case MouseInput.Button.WheelUp:
		case MouseInput.Button.WheelDown:
		case MouseInput.Button.WheelLeft:
		case MouseInput.Button.WheelRight:
			return true;
		default:
			return false;
	}
}


struct JoystickInput {
	float[6]	axes;
	uint		buttons;
	int			pov;
	
	mixin MInput;
}


struct TimeInput {
	ulong micros;
	
	mixin MInput;
}


class InputReader {
	this() {
		typeReaders.length = ._lastInputType;
	}
	
	
	void process(InputType inputType, void[] input) {
		assert (inputType >= 0 && inputType < typeReaders.length);

		if (typeReaders[inputType] !is null) {
			typeReaders[inputType](input.ptr);
		}
	}


	bool handlesInput(InputType inputType) {
		return
				inputType >= 0
			&&	inputType < typeReaders.length
			&&	typeReaders[inputType] !is null;
	}


	protected {
		void delegate(void*)[] typeReaders;
		
		final void registerReader(T)(void delegate(T*) rdr) {
			assert (rdr !is null);
			typeReaders[T._inputTypeId] = cast(void delegate(void*))rdr;
		}
	}
}


class SimpleKeyboardReader : InputReader {
	private import tango.stdc.stdio : printf;
	
	void keyInput(KeyboardInput* i) {
		if (i.type.Down == i.type) {
			//printf("key down\n");
			keyState[i.keySym] = true;
		} else {
			//printf("key up\n");
			keyState[i.keySym] = false;
		}
	}
	
	bool keyDown(KeySym sym) {
		if (auto k = sym in keyState) return *k;
		else return false;
	}
	
	void setKeyState(KeySym sym, bool state) {
		if (state) {
			keyState[sym] = true;
		} else {
			if (auto k = sym in keyState) {
				*k = false;
			}
		}
	}
	
	this(InputChannel chan) {
		registerReader!(KeyboardInput)(&this.keyInput);
		chan.addReader(this);
	}
	
	private {
		bool[KeySym] keyState;
	}
}


/+class MouseReader : InputReader {
	void foo(MouseInput* i) {
		// do anything with the input
//		writefln("got a mouse input, button = ", i.button);
	}


	this() {
		registerReader!(MouseInput)(&this.foo);
	}
}


class TimeReader : InputReader {
	void foo(TimeInput* i) {
		// do anything with the input
		//("got a time tick: ", i.tick);
	}
	
	
	this() {
		registerReader!(TimeInput)(&this.foo);
	}
}+/


class InputChannel {
	enum { inputAlignment = 1 }


	void addReader(InputReader r) {
		readers ~= r;
	}
	
	
	void opShl(T)(T newInput) {
		void*	inputData = queue.pushBack(InputType.sizeof + T.sizeof, inputAlignment);
		*cast(InputType*)inputData = T._inputTypeId;

		void*	inputPtr = inputData+InputType.sizeof;
		memcpy(inputPtr, &newInput, T.sizeof);
	}
	
	
	bool empty() {
		return queue.isEmpty();
	}
	
	
	void dispatchOne() {
		void*		inputData = queue.front(inputAlignment);
		InputType	inputType = *cast(InputType*)inputData;

		void*		inputPtr = inputData+InputType.sizeof;
		TypeInfo	inputTI = _inputTypeInfos[inputType];
		
		foreach (reader; readers) {
			reader.process(inputType, inputPtr[0..inputTI.tsize]);
		}

		queue.popFront(inputData, InputType.sizeof + inputTI.tsize);
	}
	

	void dispatchAll() {
		while (!empty) {
			dispatchOne();
		}
	}


	this() {
		queue.initialize();
	}


	private {
		ScratchFIFO		queue;
		InputReader[]	readers;
	}
}


// could e.g. convert from keyboard input to player input (player actions)
class InputConverter {
	InputChannel incoming;
	InputChannel outgoing;
	
	
	this(InputChannel incoming) {
		this.incoming = incoming;
		outgoing = new InputChannel;
	}
	
	
	void dispatchOne() {
		incoming.dispatchOne();
		outgoing.dispatchOne();
	}
	
	
	bool empty() {
		return incoming.empty;
	}

	// arbitary readers and writers connected to channels, readers from 'incoming' will write to 'outgoing'
}





/+void main() {
	InputChannel channel = new InputChannel;

	KeyboardInput kinput;
	kinput.key = 'w';	

	MouseInput minput;
	minput.button = 2;

	TimeInput tinput;
	tinput.tick = 123456789;

	KeyboardReader keyboard = new KeyboardReader;
	MouseReader mouse = new MouseReader;
	TimeReader timer = new TimeReader;
	PlayerReader player = new PlayerReader;

	channel.readers ~= keyboard;
	channel.readers ~= mouse;
	channel.readers ~= timer;

	channel << kinput;
	channel << tinput;
	channel << minput;

	while (!channel.empty) {
		channel.dispatchOne();
	}



	auto playerMap = new PlayerInputMap;
	playerMap.outgoing.readers ~= player;
	playerMap.incoming << minput;
	playerMap.incoming << kinput;


	while (!playerMap.empty) {
		playerMap.dispatchOne();
	}
}+/

