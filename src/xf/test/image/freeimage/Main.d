module Main;

import xf.test.Common;

import freeimage.FreeImage;
import freeimage.FreeImageLoader;

import tango.stdc.stringz;
import tango.stdc.stdio;


void main() {
	FreeImage.load();
	FreeImage_Initialise();

	printf("FreeImage version: %s\n", FreeImage_GetVersion());
	puts(FreeImage_GetCopyrightMessage());
}

