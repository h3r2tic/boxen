module xf.utils.Error;


char[] createErrorMixin(char[] excName, char[] excFuncName) {
	return `
		private static import tango.text.convert.Format;


		class `~excName~` : Exception {
			this (char[] msg) {
				super(msg);
			}
		}

		void `~excFuncName~`(char[] fmt, ...) {
			char[256] buffer;
			char[] msg = tango.text.convert.Format.Format.vprint(buffer, fmt, _arguments, _argptr);
			throw new `~excName~`(msg.dup);
		}
	`;
}


mixin(createErrorMixin("UtilsException", "utilsError"));
