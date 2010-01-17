module xf.utils.Log;

public {
	import tango.util.log.model.ILogger : ILogger;
}


char[] createLoggerMixin(char[] name) {
	return `
		private __thread ILogger _`~name~`_inst;

		ILogger `~name~`() {
			if (_`~name~`_inst is null) {
				_`~name~`_inst = _xf_createLogger("`~name~`");
			}
				
			return _`~name~`_inst;
		}
	`;
}


extern (C) extern ILogger _xf_createLogger(char[] name);


mixin(createLoggerMixin("utilsLog"));
