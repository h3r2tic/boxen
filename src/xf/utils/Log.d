module xf.utils.Log;

private {
	import xf.Common;
}

public {
	import tango.util.log.model.ILogger : ILogger;
}


cstring createLoggerMixin(cstring name) {
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


extern (C) extern ILogger _xf_createLogger(cstring name);
