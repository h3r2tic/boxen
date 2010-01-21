module xf.img.Image;

private {
	import
		xf.Common,
		xf.omg.core.LinearAlgebra;
		
	import tango.text.convert.Format;
}


struct Image {
	enum ColorLayout : u8 {
		Unknown,
		R,
		RG,
		RGB,
		RGBA
	}

	enum ColorSpace : u8 {
		Linear,
		sRGB
	}
	
	enum DataType : u8 {
		Unknown,
		U8,
		I8,
		U16,
		I16,
		F16,
		F32,
		F64
	}
	
	
	static cstring enumToString(ColorLayout e) {
		switch (e) {
			case ColorLayout.Unknown:	return "Unknown";
			case ColorLayout.R:		return "R";
			case ColorLayout.RG:	return "RG";
			case ColorLayout.RGB:	return "RGB";
			case ColorLayout.RGBA:	return "RGBA";
			default: assert (false);
		}
	}
	
	static cstring enumToString(ColorSpace e) {
		switch (e) {
			case ColorSpace.Linear:	return "linear";
			case ColorSpace.sRGB:	return "sRGB";
			default: assert (false);
		}
	}

	static cstring enumToString(DataType e) {
		switch (e) {
			case DataType.Unknown: return "Unknown";
			case DataType.U8: return "u8";
			case DataType.I8: return "i8";
			case DataType.U16: return "u16";
			case DataType.I16: return "i16";
			case DataType.F16: return "f16";
			case DataType.F32: return "f32";
			case DataType.F64: return "f64";
			default: assert (false);
		}
	}

	
	public {
		void delegate(Image*) _disposalFunc;

		/// scanlines aligned to 4 bytes
		u8[]		data;
		
		u32			width;
		u32			height;
		u32			scanLineBytes;
		ColorLayout	colorLayout;
		ColorSpace	colorSpace;
		DataType	dataType;
		u8			loaderFlags;
	}
	
	
	cstring toString() {
		return Format(
			"Image {}x{} {}x{} ({})",
			width,
			height,
			enumToString(colorLayout),
			enumToString(dataType),
			enumToString(colorSpace)
		);
	}
	
	
	bool valid() {
		return data.ptr !is null;
	}
	
	
	vec2i size() {
		return vec2i(width, height);
	}
	
	
	word bytesPerChannel() {
		switch (dataType) {
			case DataType.U8:	return 1;
			case DataType.I8:	return 1;
			case DataType.U16:	return 2;
			case DataType.I16:	return 2;
			case DataType.F16:	return 2;
			case DataType.F32:	return 4;
			case DataType.F64:	return 8;
			default: assert (false);
		}
	}
	
	uword bitsPerChannel() {
		return bytesPerChannel * 8;
	}
	
	
	word channelsPerPixel() {
		switch (colorLayout) {
			case ColorLayout.R:		return 1;
			case ColorLayout.RG:	return 2;
			case ColorLayout.RGB:	return 3;
			case ColorLayout.RGBA:	return 4;
			default: assert (false);
		}
	}
	

	uword bytesPerPixel() {
		return bytesPerChannel * channelsPerPixel;
	}
	
	uword bitsPerPixel() {
		return bitsPerChannel * channelsPerPixel;
	}


	void dispose() {
		if (_disposalFunc) {
			_disposalFunc(this);
			_disposalFunc = null;
		}
	}
}


struct ImageRequest {
	Image.ColorLayout	colorLayout	= Image.ColorLayout.RGBA;
	Image.DataType		dataType	= Image.DataType.U8;
}
