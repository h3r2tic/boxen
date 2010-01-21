module xf.img.Image;

private {
	import
		xf.Common,
		xf.omg.core.LinearAlgebra;
}


struct Image {
	enum ColorLayout : u8 {
		Unknown,
		R,
		RG,
		RGB,
		RGBA,
		BGR,
		BGRA,
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
	
	
	public {
		u8[]		data;
		u32			width;
		u32			height;
		ColorLayout	colorLayout;
		DataType	dataType;
		u16			loaderFlags;
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
			case ColorLayout.BGR:	return 3;
			case ColorLayout.BGRA:	return 4;
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
	
	private {
		void delegate(Image*) _disposalFunc;
	}
}


struct ImageRequest {
	Image.ColorLayout	colorLayout	= Image.ColorLayout.RGBA;
	Image.DataType		dataType	= Image.DataType.U8;
}
