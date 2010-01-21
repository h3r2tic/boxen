module Main;

import
	xf.Common,
	xf.test.Common;

import
	freeimage.FreeImage,
	freeimage.FreeImageLoader;

import
	tango.stdc.stringz,
	tango.stdc.stdio,
	tango.io.device.FileMap,
	tango.io.device.File;



FIBITMAP* loadImage(ubyte[] data, cstring fileName = null, int flag = 0) {
	FREE_IMAGE_FORMAT fif = FIF_UNKNOWN;

	final mem = FreeImage_OpenMemory(data.ptr, data.length);

	// check the file signature and deduce its format
	// (the second argument is currently not used by FreeImage)
	fif = FreeImage_GetFileTypeFromMemory(mem);

	if (FIF_UNKNOWN == fif && fileName !is null) {
		char[512] buf = void;

		// no signature ?
		// try to guess the file format from the file extension
		fif = FreeImage_GetFIFFromFilename(
			toStringz(fileName, buf[])
		);
	}

	// check that the plugin has reading capabilities ...
	if ((fif != FIF_UNKNOWN) && FreeImage_FIFSupportsReading(fif)) {
		FIBITMAP *dib = FreeImage_LoadFromMemory(fif, mem, flag);
		return dib;
	}

	return null;
}


void main() {
	FreeImage.load();
	FreeImage_Initialise();

	printf("FreeImage version: %s\n", FreeImage_GetVersion());
	puts(FreeImage_GetCopyrightMessage());

	final fname = "Lena.jpg";
	scope fileData = new MappedFile(fname, File.ReadShared);
	scope (exit) fileData.close();

	final img = loadImage(fileData.map, fname);

	if (img !is null) {
		printf("Successfully loaded %.*s.\n", fname);
		FreeImage_Unload(img);
	} else {
		printf("Could not load%.*s\n.", fname);
	}

	FreeImage_DeInitialise();
}

