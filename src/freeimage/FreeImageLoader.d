module freeimage.FreeImageLoader;

private import
	freeimage.FreeImage,
	tango.sys.SharedLib;


struct FreeImage {
	static void load() {
		version (Windows) {
			auto library = SharedLib.load("FreeImage.dll");
		} else {
			static assert (false, "TODO");
		}

		void loadSymbol(void** sym, char* name) {
			*sym = library.getSymbol(name);
		}


		loadSymbol(cast(void**)&FreeImage_AcquireMemory, "_FreeImage_AcquireMemory@12");
		loadSymbol(cast(void**)&FreeImage_AdjustBrightness, "_FreeImage_AdjustBrightness@12");
		loadSymbol(cast(void**)&FreeImage_AdjustColors, "_FreeImage_AdjustColors@32");
		loadSymbol(cast(void**)&FreeImage_AdjustContrast, "_FreeImage_AdjustContrast@12");
		loadSymbol(cast(void**)&FreeImage_AdjustCurve, "_FreeImage_AdjustCurve@12");
		loadSymbol(cast(void**)&FreeImage_AdjustGamma, "_FreeImage_AdjustGamma@12");
		loadSymbol(cast(void**)&FreeImage_Allocate, "_FreeImage_Allocate@24");
		loadSymbol(cast(void**)&FreeImage_AllocateEx, "_FreeImage_AllocateEx@36");
		loadSymbol(cast(void**)&FreeImage_AllocateExT, "_FreeImage_AllocateExT@40");
		loadSymbol(cast(void**)&FreeImage_AllocateT, "_FreeImage_AllocateT@28");
		loadSymbol(cast(void**)&FreeImage_AppendPage, "_FreeImage_AppendPage@8");
		loadSymbol(cast(void**)&FreeImage_ApplyColorMapping, "_FreeImage_ApplyColorMapping@24");
		loadSymbol(cast(void**)&FreeImage_ApplyPaletteIndexMapping, "_FreeImage_ApplyPaletteIndexMapping@20");
		loadSymbol(cast(void**)&FreeImage_Clone, "_FreeImage_Clone@4");
		loadSymbol(cast(void**)&FreeImage_CloneMetadata, "_FreeImage_CloneMetadata@8");
		loadSymbol(cast(void**)&FreeImage_CloneTag, "_FreeImage_CloneTag@4");
		loadSymbol(cast(void**)&FreeImage_CloseMemory, "_FreeImage_CloseMemory@4");
		loadSymbol(cast(void**)&FreeImage_CloseMultiBitmap, "_FreeImage_CloseMultiBitmap@8");
		loadSymbol(cast(void**)&FreeImage_ColorQuantize, "_FreeImage_ColorQuantize@8");
		loadSymbol(cast(void**)&FreeImage_ColorQuantizeEx, "_FreeImage_ColorQuantizeEx@20");
		loadSymbol(cast(void**)&FreeImage_Composite, "_FreeImage_Composite@16");
		loadSymbol(cast(void**)&FreeImage_ConvertFromRawBits, "_FreeImage_ConvertFromRawBits@36");
		loadSymbol(cast(void**)&FreeImage_ConvertLine16_555_To16_565, "_FreeImage_ConvertLine16_555_To16_565@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine16_565_To16_555, "_FreeImage_ConvertLine16_565_To16_555@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine16To24_555, "_FreeImage_ConvertLine16To24_555@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine16To24_565, "_FreeImage_ConvertLine16To24_565@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine16To32_555, "_FreeImage_ConvertLine16To32_555@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine16To32_565, "_FreeImage_ConvertLine16To32_565@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine16To4_555, "_FreeImage_ConvertLine16To4_555@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine16To4_565, "_FreeImage_ConvertLine16To4_565@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine16To8_555, "_FreeImage_ConvertLine16To8_555@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine16To8_565, "_FreeImage_ConvertLine16To8_565@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine1To16_555, "_FreeImage_ConvertLine1To16_555@16");
		loadSymbol(cast(void**)&FreeImage_ConvertLine1To16_565, "_FreeImage_ConvertLine1To16_565@16");
		loadSymbol(cast(void**)&FreeImage_ConvertLine1To24, "_FreeImage_ConvertLine1To24@16");
		loadSymbol(cast(void**)&FreeImage_ConvertLine1To32, "_FreeImage_ConvertLine1To32@16");
		loadSymbol(cast(void**)&FreeImage_ConvertLine1To4, "_FreeImage_ConvertLine1To4@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine1To8, "_FreeImage_ConvertLine1To8@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine24To16_555, "_FreeImage_ConvertLine24To16_555@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine24To16_565, "_FreeImage_ConvertLine24To16_565@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine24To32, "_FreeImage_ConvertLine24To32@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine24To4, "_FreeImage_ConvertLine24To4@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine24To8, "_FreeImage_ConvertLine24To8@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine32To16_555, "_FreeImage_ConvertLine32To16_555@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine32To16_565, "_FreeImage_ConvertLine32To16_565@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine32To24, "_FreeImage_ConvertLine32To24@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine32To4, "_FreeImage_ConvertLine32To4@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine32To8, "_FreeImage_ConvertLine32To8@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine4To16_555, "_FreeImage_ConvertLine4To16_555@16");
		loadSymbol(cast(void**)&FreeImage_ConvertLine4To16_565, "_FreeImage_ConvertLine4To16_565@16");
		loadSymbol(cast(void**)&FreeImage_ConvertLine4To24, "_FreeImage_ConvertLine4To24@16");
		loadSymbol(cast(void**)&FreeImage_ConvertLine4To32, "_FreeImage_ConvertLine4To32@16");
		loadSymbol(cast(void**)&FreeImage_ConvertLine4To8, "_FreeImage_ConvertLine4To8@12");
		loadSymbol(cast(void**)&FreeImage_ConvertLine8To16_555, "_FreeImage_ConvertLine8To16_555@16");
		loadSymbol(cast(void**)&FreeImage_ConvertLine8To16_565, "_FreeImage_ConvertLine8To16_565@16");
		loadSymbol(cast(void**)&FreeImage_ConvertLine8To24, "_FreeImage_ConvertLine8To24@16");
		loadSymbol(cast(void**)&FreeImage_ConvertLine8To32, "_FreeImage_ConvertLine8To32@16");
		loadSymbol(cast(void**)&FreeImage_ConvertLine8To4, "_FreeImage_ConvertLine8To4@16");
		loadSymbol(cast(void**)&FreeImage_ConvertTo16Bits555, "_FreeImage_ConvertTo16Bits555@4");
		loadSymbol(cast(void**)&FreeImage_ConvertTo16Bits565, "_FreeImage_ConvertTo16Bits565@4");
		loadSymbol(cast(void**)&FreeImage_ConvertTo24Bits, "_FreeImage_ConvertTo24Bits@4");
		loadSymbol(cast(void**)&FreeImage_ConvertTo32Bits, "_FreeImage_ConvertTo32Bits@4");
		loadSymbol(cast(void**)&FreeImage_ConvertTo4Bits, "_FreeImage_ConvertTo4Bits@4");
		loadSymbol(cast(void**)&FreeImage_ConvertTo8Bits, "_FreeImage_ConvertTo8Bits@4");
		loadSymbol(cast(void**)&FreeImage_ConvertToGreyscale, "_FreeImage_ConvertToGreyscale@4");
		loadSymbol(cast(void**)&FreeImage_ConvertToRawBits, "_FreeImage_ConvertToRawBits@32");
		loadSymbol(cast(void**)&FreeImage_ConvertToRGBF, "_FreeImage_ConvertToRGBF@4");
		loadSymbol(cast(void**)&FreeImage_ConvertToStandardType, "_FreeImage_ConvertToStandardType@8");
		loadSymbol(cast(void**)&FreeImage_ConvertToType, "_FreeImage_ConvertToType@12");
		loadSymbol(cast(void**)&FreeImage_Copy, "_FreeImage_Copy@20");
		loadSymbol(cast(void**)&FreeImage_CreateICCProfile, "_FreeImage_CreateICCProfile@12");
		loadSymbol(cast(void**)&FreeImage_CreateTag, "_FreeImage_CreateTag@0");
		loadSymbol(cast(void**)&FreeImage_DeInitialise, "_FreeImage_DeInitialise@0");
		loadSymbol(cast(void**)&FreeImage_DeletePage, "_FreeImage_DeletePage@8");
		loadSymbol(cast(void**)&FreeImage_DeleteTag, "_FreeImage_DeleteTag@4");
		loadSymbol(cast(void**)&FreeImage_DestroyICCProfile, "_FreeImage_DestroyICCProfile@4");
		loadSymbol(cast(void**)&FreeImage_Dither, "_FreeImage_Dither@8");
		loadSymbol(cast(void**)&FreeImage_EnlargeCanvas, "_FreeImage_EnlargeCanvas@28");
		loadSymbol(cast(void**)&FreeImage_FIFSupportsExportBPP, "_FreeImage_FIFSupportsExportBPP@8");
		loadSymbol(cast(void**)&FreeImage_FIFSupportsExportType, "_FreeImage_FIFSupportsExportType@8");
		loadSymbol(cast(void**)&FreeImage_FIFSupportsICCProfiles, "_FreeImage_FIFSupportsICCProfiles@4");
		loadSymbol(cast(void**)&FreeImage_FIFSupportsReading, "_FreeImage_FIFSupportsReading@4");
		loadSymbol(cast(void**)&FreeImage_FIFSupportsWriting, "_FreeImage_FIFSupportsWriting@4");
		loadSymbol(cast(void**)&FreeImage_FillBackground, "_FreeImage_FillBackground@12");
		loadSymbol(cast(void**)&FreeImage_FindCloseMetadata, "_FreeImage_FindCloseMetadata@4");
		loadSymbol(cast(void**)&FreeImage_FindFirstMetadata, "_FreeImage_FindFirstMetadata@12");
		loadSymbol(cast(void**)&FreeImage_FindNextMetadata, "_FreeImage_FindNextMetadata@8");
		loadSymbol(cast(void**)&FreeImage_FlipHorizontal, "_FreeImage_FlipHorizontal@4");
		loadSymbol(cast(void**)&FreeImage_FlipVertical, "_FreeImage_FlipVertical@4");
		loadSymbol(cast(void**)&FreeImage_GetAdjustColorsLookupTable, "_FreeImage_GetAdjustColorsLookupTable@32");
		loadSymbol(cast(void**)&FreeImage_GetBackgroundColor, "_FreeImage_GetBackgroundColor@8");
		loadSymbol(cast(void**)&FreeImage_GetBits, "_FreeImage_GetBits@4");
		loadSymbol(cast(void**)&FreeImage_GetBlueMask, "_FreeImage_GetBlueMask@4");
		loadSymbol(cast(void**)&FreeImage_GetBPP, "_FreeImage_GetBPP@4");
		loadSymbol(cast(void**)&FreeImage_GetChannel, "_FreeImage_GetChannel@8");
		loadSymbol(cast(void**)&FreeImage_GetColorsUsed, "_FreeImage_GetColorsUsed@4");
		loadSymbol(cast(void**)&FreeImage_GetColorType, "_FreeImage_GetColorType@4");
		loadSymbol(cast(void**)&FreeImage_GetComplexChannel, "_FreeImage_GetComplexChannel@8");
		loadSymbol(cast(void**)&FreeImage_GetCopyrightMessage, "_FreeImage_GetCopyrightMessage@0");
		loadSymbol(cast(void**)&FreeImage_GetDIBSize, "_FreeImage_GetDIBSize@4");
		loadSymbol(cast(void**)&FreeImage_GetDotsPerMeterX, "_FreeImage_GetDotsPerMeterX@4");
		loadSymbol(cast(void**)&FreeImage_GetDotsPerMeterY, "_FreeImage_GetDotsPerMeterY@4");
		loadSymbol(cast(void**)&FreeImage_GetFIFCount, "_FreeImage_GetFIFCount@0");
		loadSymbol(cast(void**)&FreeImage_GetFIFDescription, "_FreeImage_GetFIFDescription@4");
		loadSymbol(cast(void**)&FreeImage_GetFIFExtensionList, "_FreeImage_GetFIFExtensionList@4");
		loadSymbol(cast(void**)&FreeImage_GetFIFFromFilename, "_FreeImage_GetFIFFromFilename@4");
		loadSymbol(cast(void**)&FreeImage_GetFIFFromFilenameU, "_FreeImage_GetFIFFromFilenameU@4");
		loadSymbol(cast(void**)&FreeImage_GetFIFFromFormat, "_FreeImage_GetFIFFromFormat@4");
		loadSymbol(cast(void**)&FreeImage_GetFIFFromMime, "_FreeImage_GetFIFFromMime@4");
		loadSymbol(cast(void**)&FreeImage_GetFIFMimeType, "_FreeImage_GetFIFMimeType@4");
		loadSymbol(cast(void**)&FreeImage_GetFIFRegExpr, "_FreeImage_GetFIFRegExpr@4");
		loadSymbol(cast(void**)&FreeImage_GetFileType, "_FreeImage_GetFileType@8");
		loadSymbol(cast(void**)&FreeImage_GetFileTypeFromHandle, "_FreeImage_GetFileTypeFromHandle@12");
		loadSymbol(cast(void**)&FreeImage_GetFileTypeFromMemory, "_FreeImage_GetFileTypeFromMemory@8");
		loadSymbol(cast(void**)&FreeImage_GetFileTypeU, "_FreeImage_GetFileTypeU@8");
		loadSymbol(cast(void**)&FreeImage_GetFormatFromFIF, "_FreeImage_GetFormatFromFIF@4");
		loadSymbol(cast(void**)&FreeImage_GetGreenMask, "_FreeImage_GetGreenMask@4");
		loadSymbol(cast(void**)&FreeImage_GetHeight, "_FreeImage_GetHeight@4");
		loadSymbol(cast(void**)&FreeImage_GetHistogram, "_FreeImage_GetHistogram@12");
		loadSymbol(cast(void**)&FreeImage_GetICCProfile, "_FreeImage_GetICCProfile@4");
		loadSymbol(cast(void**)&FreeImage_GetImageType, "_FreeImage_GetImageType@4");
		loadSymbol(cast(void**)&FreeImage_GetInfo, "_FreeImage_GetInfo@4");
		loadSymbol(cast(void**)&FreeImage_GetInfoHeader, "_FreeImage_GetInfoHeader@4");
		loadSymbol(cast(void**)&FreeImage_GetLine, "_FreeImage_GetLine@4");
		loadSymbol(cast(void**)&FreeImage_GetLockedPageNumbers, "_FreeImage_GetLockedPageNumbers@12");
		loadSymbol(cast(void**)&FreeImage_GetMetadata, "_FreeImage_GetMetadata@16");
		loadSymbol(cast(void**)&FreeImage_GetMetadataCount, "_FreeImage_GetMetadataCount@8");
		loadSymbol(cast(void**)&FreeImage_GetPageCount, "_FreeImage_GetPageCount@4");
		loadSymbol(cast(void**)&FreeImage_GetPalette, "_FreeImage_GetPalette@4");
		loadSymbol(cast(void**)&FreeImage_GetPitch, "_FreeImage_GetPitch@4");
		loadSymbol(cast(void**)&FreeImage_GetPixelColor, "_FreeImage_GetPixelColor@16");
		loadSymbol(cast(void**)&FreeImage_GetPixelIndex, "_FreeImage_GetPixelIndex@16");
		loadSymbol(cast(void**)&FreeImage_GetRedMask, "_FreeImage_GetRedMask@4");
		loadSymbol(cast(void**)&FreeImage_GetScanLine, "_FreeImage_GetScanLine@8");
		loadSymbol(cast(void**)&FreeImage_GetTagCount, "_FreeImage_GetTagCount@4");
		loadSymbol(cast(void**)&FreeImage_GetTagDescription, "_FreeImage_GetTagDescription@4");
		loadSymbol(cast(void**)&FreeImage_GetTagID, "_FreeImage_GetTagID@4");
		loadSymbol(cast(void**)&FreeImage_GetTagKey, "_FreeImage_GetTagKey@4");
		loadSymbol(cast(void**)&FreeImage_GetTagLength, "_FreeImage_GetTagLength@4");
		loadSymbol(cast(void**)&FreeImage_GetTagType, "_FreeImage_GetTagType@4");
		loadSymbol(cast(void**)&FreeImage_GetTagValue, "_FreeImage_GetTagValue@4");
		loadSymbol(cast(void**)&FreeImage_GetTransparencyCount, "_FreeImage_GetTransparencyCount@4");
		loadSymbol(cast(void**)&FreeImage_GetTransparencyTable, "_FreeImage_GetTransparencyTable@4");
		loadSymbol(cast(void**)&FreeImage_GetTransparentIndex, "_FreeImage_GetTransparentIndex@4");
		loadSymbol(cast(void**)&FreeImage_GetVersion, "_FreeImage_GetVersion@0");
		loadSymbol(cast(void**)&FreeImage_GetWidth, "_FreeImage_GetWidth@4");
		loadSymbol(cast(void**)&FreeImage_HasBackgroundColor, "_FreeImage_HasBackgroundColor@4");
		loadSymbol(cast(void**)&FreeImage_Initialise, "_FreeImage_Initialise@4");
		loadSymbol(cast(void**)&FreeImage_InsertPage, "_FreeImage_InsertPage@12");
		loadSymbol(cast(void**)&FreeImage_Invert, "_FreeImage_Invert@4");
		loadSymbol(cast(void**)&FreeImage_IsLittleEndian, "_FreeImage_IsLittleEndian@0");
		loadSymbol(cast(void**)&FreeImage_IsPluginEnabled, "_FreeImage_IsPluginEnabled@4");
		loadSymbol(cast(void**)&FreeImage_IsTransparent, "_FreeImage_IsTransparent@4");
		loadSymbol(cast(void**)&FreeImage_JPEGCrop, "_FreeImage_JPEGCrop@24");
		loadSymbol(cast(void**)&FreeImage_JPEGCropU, "_FreeImage_JPEGCropU@24");
		loadSymbol(cast(void**)&FreeImage_JPEGTransform, "_FreeImage_JPEGTransform@16");
		loadSymbol(cast(void**)&FreeImage_JPEGTransformU, "_FreeImage_JPEGTransformU@16");
		loadSymbol(cast(void**)&FreeImage_Load, "_FreeImage_Load@12");
		loadSymbol(cast(void**)&FreeImage_LoadFromHandle, "_FreeImage_LoadFromHandle@16");
		loadSymbol(cast(void**)&FreeImage_LoadFromMemory, "_FreeImage_LoadFromMemory@12");
		loadSymbol(cast(void**)&FreeImage_LoadMultiBitmapFromMemory, "_FreeImage_LoadMultiBitmapFromMemory@12");
		loadSymbol(cast(void**)&FreeImage_LoadU, "_FreeImage_LoadU@12");
		loadSymbol(cast(void**)&FreeImage_LockPage, "_FreeImage_LockPage@8");
		loadSymbol(cast(void**)&FreeImage_LookupSVGColor, "_FreeImage_LookupSVGColor@16");
		loadSymbol(cast(void**)&FreeImage_LookupX11Color, "_FreeImage_LookupX11Color@16");
		loadSymbol(cast(void**)&FreeImage_MakeThumbnail, "_FreeImage_MakeThumbnail@12");
		loadSymbol(cast(void**)&FreeImage_MovePage, "_FreeImage_MovePage@12");
		loadSymbol(cast(void**)&FreeImage_MultigridPoissonSolver, "_FreeImage_MultigridPoissonSolver@8");
		loadSymbol(cast(void**)&FreeImage_OpenMemory, "_FreeImage_OpenMemory@8");
		loadSymbol(cast(void**)&FreeImage_OpenMultiBitmap, "_FreeImage_OpenMultiBitmap@24");
		loadSymbol(cast(void**)&FreeImage_OpenMultiBitmapFromHandle, "_FreeImage_OpenMultiBitmapFromHandle@16");
		loadSymbol(cast(void**)&FreeImage_Paste, "_FreeImage_Paste@20");
		loadSymbol(cast(void**)&FreeImage_PreMultiplyWithAlpha, "_FreeImage_PreMultiplyWithAlpha@4");
		loadSymbol(cast(void**)&FreeImage_ReadMemory, "_FreeImage_ReadMemory@16");
		loadSymbol(cast(void**)&FreeImage_RegisterExternalPlugin, "_FreeImage_RegisterExternalPlugin@20");
		loadSymbol(cast(void**)&FreeImage_RegisterLocalPlugin, "_FreeImage_RegisterLocalPlugin@20");
		loadSymbol(cast(void**)&FreeImage_Rescale, "_FreeImage_Rescale@16");
		loadSymbol(cast(void**)&FreeImage_Rotate, "_FreeImage_Rotate@16");
		loadSymbol(cast(void**)&FreeImage_RotateClassic, "_FreeImage_RotateClassic@12");
		loadSymbol(cast(void**)&FreeImage_RotateEx, "_FreeImage_RotateEx@48");
		loadSymbol(cast(void**)&FreeImage_Save, "_FreeImage_Save@16");
		loadSymbol(cast(void**)&FreeImage_SaveToHandle, "_FreeImage_SaveToHandle@20");
		loadSymbol(cast(void**)&FreeImage_SaveToMemory, "_FreeImage_SaveToMemory@16");
		loadSymbol(cast(void**)&FreeImage_SaveU, "_FreeImage_SaveU@16");
		loadSymbol(cast(void**)&FreeImage_SeekMemory, "_FreeImage_SeekMemory@12");
		loadSymbol(cast(void**)&FreeImage_SetBackgroundColor, "_FreeImage_SetBackgroundColor@8");
		loadSymbol(cast(void**)&FreeImage_SetChannel, "_FreeImage_SetChannel@12");
		loadSymbol(cast(void**)&FreeImage_SetComplexChannel, "_FreeImage_SetComplexChannel@12");
		loadSymbol(cast(void**)&FreeImage_SetDotsPerMeterX, "_FreeImage_SetDotsPerMeterX@8");
		loadSymbol(cast(void**)&FreeImage_SetDotsPerMeterY, "_FreeImage_SetDotsPerMeterY@8");
		loadSymbol(cast(void**)&FreeImage_SetMetadata, "_FreeImage_SetMetadata@16");
		loadSymbol(cast(void**)&FreeImage_SetOutputMessage, "_FreeImage_SetOutputMessage@4");
		loadSymbol(cast(void**)&FreeImage_SetOutputMessageStdCall, "_FreeImage_SetOutputMessageStdCall@4");
		loadSymbol(cast(void**)&FreeImage_SetPixelColor, "_FreeImage_SetPixelColor@16");
		loadSymbol(cast(void**)&FreeImage_SetPixelIndex, "_FreeImage_SetPixelIndex@16");
		loadSymbol(cast(void**)&FreeImage_SetPluginEnabled, "_FreeImage_SetPluginEnabled@8");
		loadSymbol(cast(void**)&FreeImage_SetTagCount, "_FreeImage_SetTagCount@8");
		loadSymbol(cast(void**)&FreeImage_SetTagDescription, "_FreeImage_SetTagDescription@8");
		loadSymbol(cast(void**)&FreeImage_SetTagID, "_FreeImage_SetTagID@8");
		loadSymbol(cast(void**)&FreeImage_SetTagKey, "_FreeImage_SetTagKey@8");
		loadSymbol(cast(void**)&FreeImage_SetTagLength, "_FreeImage_SetTagLength@8");
		loadSymbol(cast(void**)&FreeImage_SetTagType, "_FreeImage_SetTagType@8");
		loadSymbol(cast(void**)&FreeImage_SetTagValue, "_FreeImage_SetTagValue@8");
		loadSymbol(cast(void**)&FreeImage_SetTransparencyTable, "_FreeImage_SetTransparencyTable@12");
		loadSymbol(cast(void**)&FreeImage_SetTransparent, "_FreeImage_SetTransparent@8");
		loadSymbol(cast(void**)&FreeImage_SetTransparentIndex, "_FreeImage_SetTransparentIndex@8");
		loadSymbol(cast(void**)&FreeImage_SwapColors, "_FreeImage_SwapColors@16");
		loadSymbol(cast(void**)&FreeImage_SwapPaletteIndices, "_FreeImage_SwapPaletteIndices@12");
		loadSymbol(cast(void**)&FreeImage_TagToString, "_FreeImage_TagToString@12");
		loadSymbol(cast(void**)&FreeImage_TellMemory, "_FreeImage_TellMemory@4");
		loadSymbol(cast(void**)&FreeImage_Threshold, "_FreeImage_Threshold@8");
		loadSymbol(cast(void**)&FreeImage_TmoDrago03, "_FreeImage_TmoDrago03@20");
		loadSymbol(cast(void**)&FreeImage_TmoFattal02, "_FreeImage_TmoFattal02@20");
		loadSymbol(cast(void**)&FreeImage_TmoReinhard05, "_FreeImage_TmoReinhard05@20");
		loadSymbol(cast(void**)&FreeImage_TmoReinhard05Ex, "_FreeImage_TmoReinhard05Ex@36");
		loadSymbol(cast(void**)&FreeImage_ToneMapping, "_FreeImage_ToneMapping@24");
		loadSymbol(cast(void**)&FreeImage_Unload, "_FreeImage_Unload@4");
		loadSymbol(cast(void**)&FreeImage_UnlockPage, "_FreeImage_UnlockPage@12");
		loadSymbol(cast(void**)&FreeImage_WriteMemory, "_FreeImage_WriteMemory@16");
		loadSymbol(cast(void**)&FreeImage_ZLibCompress, "_FreeImage_ZLibCompress@16");
		loadSymbol(cast(void**)&FreeImage_ZLibCRC32, "_FreeImage_ZLibCRC32@12");
		loadSymbol(cast(void**)&FreeImage_ZLibGUnzip, "_FreeImage_ZLibGUnzip@16");
		loadSymbol(cast(void**)&FreeImage_ZLibGZip, "_FreeImage_ZLibGZip@16");
		loadSymbol(cast(void**)&FreeImage_ZLibUncompress, "_FreeImage_ZLibUncompress@16");
		loadSymbol(cast(void**)&FreeImage_OutputMessageProc, "FreeImage_OutputMessageProc");
	}
}

