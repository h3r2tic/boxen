module xf.img.FreeImageLoader;

private {
	import
		xf.img.Image,
		xf.img.Loader,
		xf.img.Log : log = imgLog, error = imgError;
	
	import
		xf.Common,
		xf.mem.MainHeap,
		xf.omg.core.LinearAlgebra;

	import
		freeimage.FreeImage,
		freeimage.FreeImageLoader;

	import
		tango.stdc.stringz,
		tango.stdc.stdio,
		tango.io.model.IConduit,
		tango.io.device.FileMap,
		tango.io.device.File,
		tango.io.FilePath,
		tango.io.vfs.model.Vfs,
		tango.core.Exception : VfsException;
}



class FreeImageLoader : Loader {
	override Image load(cstring filename, ImageRequest* req = null) {
		Image result;
		
		/+// TODO: generalize this
		ilEnable(IL_ORIGIN_SET);
		ilOriginFunc(IL_ORIGIN_LOWER_LEFT);
		
		Image result = new Image;
		
		ILuint ilId;
		{
			void[] rawData = loadDataFromFile(filename);
			if (rawData is null) {
				// TODO: log
				return null;
			}
			
			ilGenImages(1, &ilId);
			ilBindImage(ilId);
			ilLoadL(IL_TYPE_UNKNOWN, &rawData[0], rawData.length);
			delete rawData;
		}
		
		result.dataFormat = DataFormat.Byte;
		
		uint w			= ilGetInteger(IL_IMAGE_WIDTH);
		uint h			= ilGetInteger(IL_IMAGE_HEIGHT);
		uint channels	= 0;
		uint bytesPerChannel = 1;

		switch (ilGetInteger(IL_IMAGE_FORMAT)) {
			case IL_BGRA:
			case IL_RGBA:
				channels = 4;
				break;
				
			case IL_BGR:
			case IL_RGB:
				channels = 3;
				break;
				
			case IL_LUMINANCE:
				channels = 1;
				break;
		}
		
		switch (ilGetInteger(IL_IMAGE_TYPE)) {
			case IL_UNSIGNED_BYTE:
				break;
				
			case IL_UNSIGNED_SHORT:
				bytesPerChannel = 2;
				result.dataFormat = DataFormat.Short;
				break;
		}
		
		if (req !is null) {
			auto ilImgType = IL_UNSIGNED_BYTE;
			
			switch (req.dataFormat) {
				case DataFormat.Byte:
				case DataFormat.SignedByte:
					bytesPerChannel = 1;
					break;

				case DataFormat.Short:
					bytesPerChannel = 2;
					ilImgType = IL_UNSIGNED_SHORT;
					break;
					
				case DataFormat.Float:
					assert (false, "TODO: DataFormat.Float");
			}
			
			result.dataFormat = req.dataFormat;
			
			switch (req.imageFormat) {
				case ImageFormat.RGBA:
					channels = 4;
					break;
				case ImageFormat.RGB:
					channels = 3;
					break;
				case ImageFormat.Grayscale:
					channels = 1;
					break;
			}
			
			if (4 == channels) {
				ilConvertImage(IL_RGBA, ilImgType);				
			} else if (1 == channels) {
				ilConvertImage(IL_LUMINANCE, ilImgType);
			} else {
				ilConvertImage(IL_RGB, ilImgType);
			}
		}
		
		switch (channels) {
			case 4:
				result.imageFormat = ImageFormat.RGBA;
				break;
			case 3:
				result.imageFormat = ImageFormat.RGB;
				break;
			case 1:
				result.imageFormat = ImageFormat.Grayscale;
				break;
			default:
				throw new Exception(Format("Unsupported image channel count: {}", channels));
		}

		ImagePlane imgPlane = new ImagePlane;

		{
			ubyte[] tmp = (cast(ubyte*)ilGetData())[0 .. w * h * channels * bytesPerChannel];
			imgPlane.data.alloc(tmp.length);
			imgPlane.data[] = tmp[];
		}
		ilDeleteImages(1, &ilId);

		
		imgPlane.opaque	= true;
		imgPlane.source	= filename;
		imgPlane.width		= w;
		imgPlane.height		= h;
		imgPlane.depth		= 1;
		
		// check if the image is opaque
		if (4 == channels) {
			assert (imgPlane.data.length);
			assert (1 == bytesPerChannel, "TODO: opaque check for 16 bit-per-channel images");
			
			foreach (uint i, ubyte a; cast(ubyte[])imgPlane.data) {
				if (i & 3 != 3) continue;		// only check alpha
				if (a != 255) {
					imgPlane.opaque = false;
					break;
				}
			}
		}
		
		result.planes ~= imgPlane;+/
		return result;
	}


	override void useVfs(VfsFolder vfs) {
		this.vfs = vfs;
	}
	
	
	this() {
		if (FreeImage_Initialise is null) {
			FreeImage.load();
			FreeImage_Initialise();
		}
	}
	
	
	protected {
		VfsFolder vfs;
		

		bool loadDataFromStream(
			InputStream src,
			void delegate(u8[] data) sink
		) {
			final fsize_ = src.seek(0, InputStream.Anchor.End);
			src.seek(0, InputStream.Anchor.Begin);
			
			if (fsize_ < 0) {
				error("InputStream.seek(0, End) returned {}", fsize_);
			}
			
			uword fsize = cast(uword)fsize_;
			
			void* buffer = mainThreadHeap.allocRaw(fsize);
			scope (exit) {
				mainThreadHeap.freeRaw(buffer);
			}
			
			src.read(buffer[0..fsize]);
			sink((cast(u8*)buffer)[0..fsize]);
			
			return true;
		}
		
		
		bool loadDataFromFile(
			cstring path,
			void delegate(u8[] data) sink
		) {
			if (vfs) {
				try {
					auto file = vfs.file(path);
					if (file.exists) {
						auto stream = file.input();
						if (stream) {
							scope (exit) stream.close();
							
							return loadDataFromStream(
								stream,
								sink
							);
						} else {
							log.error(
								"Could not open an input stream for the vfs file"
								" '{}'.", path
							);
						}
					} else {
						log.error("Image file not found in vfs: '{}'.", path);
					}
				} catch (VfsException e) {
					log.error(
						"A vfs exception occured while loading an image: {}",
						e.toString
					);
				}

				return false;
			} else {
				if (!FilePath(path).exists) {
					log.error("Image file not found: '{}'.", path);
					return false;
				}

				scope fileData = new MappedFile(path, File.ReadShared);
				scope (exit) fileData.close();

				sink(fileData.map());
				return true;
			}
		}
	}
}
