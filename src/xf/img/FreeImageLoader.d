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
	override Image load(cstring path, ImageRequest* req = null) {
		Image result;
		
		loadDataFromFile(path,
		(u8[] imgData) {
			auto dib = loadFIBITMAP(imgData, path);
			if (dib is null) {
				error("FreeImage returned a null bitmap");
			}

			scope (exit) {
				FreeImage_Unload(dib);
			}
			
			if (FreeImage_GetPalette(dib)) {
				bool transparent = FreeImage_GetTransparencyCount(dib) > 0;
				FIBITMAP* dib2;
				
				if (transparent) {
					dib2 = FreeImage_ConvertTo32Bits(dib);
					if (dib2 is null) {
						error("FreeImage_ConvertTo32Bits failed");
					}
				} else {
					dib2 = FreeImage_ConvertTo24Bits(dib);
					if (dib2 is null) {
						error("FreeImage_ConvertTo24Bits failed");
					}
				}
				
				FreeImage_Unload(dib);
				dib = dib2;
			}
			
			bool flipRB = false;
			
			final itype = FreeImage_GetImageType(dib);
			switch (itype) {
				case FIT_BITMAP: {
					result.dataType = Image.DataType.U8;

					word bits = FreeImage_GetBPP(dib);
					switch (bits) {
						case 1:
						case 4: {
							final dib2 = FreeImage_ConvertToGreyscale(dib);
							if (dib2 is null) {
								error("FreeImage_ConvertTo8Bits failed");
							}
							FreeImage_Unload(dib);
							dib = dib2;
							bits = 8;
						}	// fall through
						
						case 8: {
							result.colorLayout = Image.ColorLayout.R;
						} break;

						case 16: {
							final dib2 = FreeImage_ConvertTo24Bits(dib);
							if (dib2 is null) {
								error("FreeImage_ConvertTo24Bits failed");
							}
							FreeImage_Unload(dib);
							dib = dib2;
						}	// fall through

						case 24: {
							result.colorLayout = Image.ColorLayout.RGB;
							flipRB = true;
						} break;

						case 32: {
							result.colorLayout = Image.ColorLayout.RGBA;
							flipRB = true;
						} break;
						
						default: {
							error(
								"FreeImage_GetBPP returned {}. We don't like that",
								bits
							);
						} break;
					}
					
					result.colorSpace = Image.ColorSpace.sRGB;
				} break;
				
				// TODO: are the other formats BGR[A] as well or plain RGB[A]?
				// TODO: are 16 bit uint and int types usually sRGB or linear?
				
				case FIT_UINT16: {
					result.colorLayout = Image.ColorLayout.R;
					result.dataType = Image.DataType.U16;
					result.colorSpace = Image.ColorSpace.Linear;
				} break;

				case FIT_INT16: {
					result.colorLayout = Image.ColorLayout.R;
					result.dataType = Image.DataType.I16;
					result.colorSpace = Image.ColorSpace.Linear;
				} break;

				case FIT_RGB16: {
					result.colorLayout = Image.ColorLayout.RGB;
					result.dataType = Image.DataType.U16;
					result.colorSpace = Image.ColorSpace.Linear;
				} break;

				case FIT_RGBA16: {
					result.colorLayout = Image.ColorLayout.RGBA;
					result.dataType = Image.DataType.U16;
					result.colorSpace = Image.ColorSpace.Linear;
				} break;

				case FIT_FLOAT: {
					result.colorLayout = Image.ColorLayout.R;
					result.dataType = Image.DataType.F32;
					result.colorSpace = Image.ColorSpace.Linear;
				} break;

				case FIT_DOUBLE: {
					result.colorLayout = Image.ColorLayout.R;
					result.dataType = Image.DataType.F64;
					result.colorSpace = Image.ColorSpace.Linear;
				} break;

				case FIT_RGBF: {
					result.colorLayout = Image.ColorLayout.RGB;
					result.dataType = Image.DataType.F32;
					result.colorSpace = Image.ColorSpace.Linear;
				} break;
				
				case FIT_RGBAF: {
					result.colorLayout = Image.ColorLayout.RGBA;
					result.dataType = Image.DataType.F32;
					result.colorSpace = Image.ColorSpace.Linear;
				} break;

				default: {
					error("FreeImage reports an unsupported image type: {}", itype);
				}
			}
			
			result.width = FreeImage_GetWidth(dib);
			result.height = FreeImage_GetHeight(dib);
			result.scanLineBytes = FreeImage_GetPitch(dib);
			assert (result.scanLineBytes % 4 == 0);
			
			result._disposalFunc = &this.disposeImage;
			
			word totalSize = result.height * result.scanLineBytes;
			log.trace("Total size for image: {} bytes.", totalSize);
			
			result.data =
				(cast(u8*)mainHeap.allocRaw(totalSize))[0..totalSize];
				
			if (flipRB) {
				assert (Image.DataType.U8 == result.dataType);
				
				switch (result.colorLayout) {
					case Image.ColorLayout.RGB: {
						u8* d = result.data.ptr;
						u8* s = FreeImage_GetBits(dib);

						for (int y = 0; y < result.height; ++y) {
							assert (s is FreeImage_GetScanLine(dib, y));
							u8* dend = d + result.scanLineBytes;
							
							assert (
								dend
								is
								result.data.ptr + result.scanLineBytes * (y+1)
							);
							
							assert (dend <= result.data.ptr + totalSize);
							for (; d+2 < dend; d += 3, s += 3) {
								d[0] = s[2];
								d[1] = s[1];
								d[2] = s[0];
							}
							
							d = cast(u8*)((cast(uword)d + 3) & ~cast(uword)3);
							s = cast(u8*)((cast(uword)s + 3) & ~cast(uword)3);
						}
					} break;


					case Image.ColorLayout.RGBA: {
						u8* d = result.data.ptr;
						u8* dend = result.data.ptr + totalSize;
						u8* s = FreeImage_GetBits(dib);
						
						for (; d != dend; d += 4, s += 4) {
							d[0] = s[2];
							d[1] = s[1];
							d[2] = s[0];
							d[3] = s[3];
						}
					} break;
					
					default: assert (false);
				}
			} else {
				result.data[] = FreeImage_GetBits(dib)[0..totalSize];
			}
			
			log.info("Loaded {} from {}", result, path);
		});
		
		return result;
	}
	
	
	void disposeImage(Image* img) {
		if (img.data.ptr) {
			mainHeap.freeRaw(img.data.ptr);
			img.data = null;
		}
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
		
		
		FIBITMAP* loadFIBITMAP(u8[] data, cstring fileName) {
			FREE_IMAGE_FORMAT fif = FIF_UNKNOWN;

			final mem = FreeImage_OpenMemory(data.ptr, data.length);

			// check the file signature and deduce its format
			// (the second argument is currently not used by FreeImage)
			fif = FreeImage_GetFileTypeFromMemory(mem);

			if (FIF_UNKNOWN == fif && fileName !is null) {
				log.warn(
					"Could not recognize image type from its header"
					" for file '{}'.", fileName
				);
				
				char[128] buf = void;

				// no signature ?
				// try to guess the file format from the file extension
				fif = FreeImage_GetFIFFromFilename(
					toStringz(fileName, buf[])
				);
			}

			// check that the plugin has reading capabilities ...
			if ((fif != FIF_UNKNOWN) && FreeImage_FIFSupportsReading(fif)) {
				FIBITMAP *dib = FreeImage_LoadFromMemory(fif, mem);
				return dib;
			}

			log.error("Could not recognize image type for file '{}'.", fileName);
			return null;
		}
				

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
