// ==========================================================
// FreeImage 3
//
// Design and implementation by
// - Floris van den Berg (flvdberg@wxs.nl)
// - Hervé Drolon (drolon@infonie.fr)
//
// Contributors:
// - Adam Gates (radad@xoasis.com)
// - Alex Kwak
// - Alexander Dymerets (sashad@te.net.ua)
// - Detlev Vendt (detlev.vendt@brillit.de)
// - Jan L. Nauta (jln@magentammt.com)
// - Jani Kajala (janik@remedy.fi)
// - Juergen Riecker (j.riecker@gmx.de)
// - Karl-Heinz Bussian (khbussian@moss.de)
// - Laurent Rocher (rocherl@club-internet.fr)
// - Luca Piergentili (l.pierge@terra.es)
// - Machiel ten Brinke (brinkem@uni-one.nl)
// - Markus Loibl (markus.loibl@epost.de)
// - Martin Weber (martweb@gmx.net)
// - Matthias Wandel (mwandel@rim.net)
// - Michal Novotny (michal@etc.cz)
// - Petr Pytelka (pyta@lightcomp.com)
// - Riley McNiff (rmcniff@marexgroup.com)
// - Ryan Rubley (ryan@lostreality.org)
// - Volker Gärtner (volkerg@gmx.at)
//
// This file is part of FreeImage 3
//
// COVERED CODE IS PROVIDED UNDER THIS LICENSE ON AN "AS IS" BASIS, WITHOUT WARRANTY
// OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, WITHOUT LIMITATION, WARRANTIES
// THAT THE COVERED CODE IS FREE OF DEFECTS, MERCHANTABLE, FIT FOR A PARTICULAR PURPOSE
// OR NON-INFRINGING. THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE COVERED
// CODE IS WITH YOU. SHOULD ANY COVERED CODE PROVE DEFECTIVE IN ANY RESPECT, YOU (NOT
// THE INITIAL DEVELOPER OR ANY OTHER CONTRIBUTOR) ASSUME THE COST OF ANY NECESSARY
// SERVICING, REPAIR OR CORRECTION. THIS DISCLAIMER OF WARRANTY CONSTITUTES AN ESSENTIAL
// PART OF THIS LICENSE. NO USE OF ANY COVERED CODE IS AUTHORIZED HEREUNDER EXCEPT UNDER
// THIS DISCLAIMER.
//
// Use at your own risk!
// ==========================================================

// Header converted to D by Tomasz Stachowiak

module freeimage.FreeImage;

struct FIBITMAP { void *data; };
struct FIMULTIBITMAP { void *data; };
alias int BOOL;
alias ubyte BYTE;
alias ushort WORD;
alias uint DWORD;
alias int LONG;

struct RGBQUAD{
align(1):

  BYTE rgbBlue;
  BYTE rgbGreen;
  BYTE rgbRed;

  BYTE rgbReserved;
}

struct RGBTRIPLE{
align(1):

  BYTE rgbtBlue;
  BYTE rgbtGreen;
  BYTE rgbtRed;

}

struct BITMAPINFOHEADER{
  DWORD biSize;
  LONG biWidth;
  LONG biHeight;
  WORD biPlanes;
  WORD biBitCount;
  DWORD biCompression;
  DWORD biSizeImage;
  LONG biXPelsPerMeter;
  LONG biYPelsPerMeter;
  DWORD biClrUsed;
  DWORD biClrImportant;
}

struct BITMAPINFO{
  BITMAPINFOHEADER bmiHeader;
  RGBQUAD bmiColors[1];
}

struct FIRGB16{
align(1):
 WORD red;
 WORD green;
 WORD blue;
}

struct FIRGBA16{
align(1):
 WORD red;
 WORD green;
 WORD blue;
 WORD alpha;
}

struct FIRGBF{
align(1):
 float red;
 float green;
 float blue;
}

struct FIRGBAF{
align(1):
 float red;
 float green;
 float blue;
 float alpha;
}

struct FICOMPLEX{
align(1):

 double r;

    double i;
}

struct FIICCPROFILE {
 WORD flags;
 DWORD size;
 void *data;
}

typedef int FREE_IMAGE_FORMAT; enum : FREE_IMAGE_FORMAT {
 FIF_UNKNOWN = -1,
 FIF_BMP = 0,
 FIF_ICO = 1,
 FIF_JPEG = 2,
 FIF_JNG = 3,
 FIF_KOALA = 4,
 FIF_LBM = 5,
 FIF_IFF = FIF_LBM,
 FIF_MNG = 6,
 FIF_PBM = 7,
 FIF_PBMRAW = 8,
 FIF_PCD = 9,
 FIF_PCX = 10,
 FIF_PGM = 11,
 FIF_PGMRAW = 12,
 FIF_PNG = 13,
 FIF_PPM = 14,
 FIF_PPMRAW = 15,
 FIF_RAS = 16,
 FIF_TARGA = 17,
 FIF_TIFF = 18,
 FIF_WBMP = 19,
 FIF_PSD = 20,
 FIF_CUT = 21,
 FIF_XBM = 22,
 FIF_XPM = 23,
 FIF_DDS = 24,
 FIF_GIF = 25,
 FIF_HDR = 26,
 FIF_FAXG3 = 27,
 FIF_SGI = 28,
 FIF_EXR = 29,
 FIF_J2K = 30,
 FIF_JP2 = 31,
 FIF_PFM = 32,
 FIF_PICT = 33,
 FIF_RAW = 34
}

typedef int FREE_IMAGE_TYPE; enum : FREE_IMAGE_TYPE {
 FIT_UNKNOWN = 0,
 FIT_BITMAP = 1,
 FIT_UINT16 = 2,
 FIT_INT16 = 3,
 FIT_UINT32 = 4,
 FIT_INT32 = 5,
 FIT_FLOAT = 6,
 FIT_DOUBLE = 7,
 FIT_COMPLEX = 8,
 FIT_RGB16 = 9,
 FIT_RGBA16 = 10,
 FIT_RGBF = 11,
 FIT_RGBAF = 12
}

typedef int FREE_IMAGE_COLOR_TYPE; enum : FREE_IMAGE_COLOR_TYPE {
 FIC_MINISWHITE = 0,
    FIC_MINISBLACK = 1,
    FIC_RGB = 2,
    FIC_PALETTE = 3,
 FIC_RGBALPHA = 4,
 FIC_CMYK = 5
}

typedef int FREE_IMAGE_QUANTIZE; enum : FREE_IMAGE_QUANTIZE {
    FIQ_WUQUANT = 0,
    FIQ_NNQUANT = 1
}

typedef int FREE_IMAGE_DITHER; enum : FREE_IMAGE_DITHER {
    FID_FS = 0,
 FID_BAYER4x4 = 1,
 FID_BAYER8x8 = 2,
 FID_CLUSTER6x6 = 3,
 FID_CLUSTER8x8 = 4,
 FID_CLUSTER16x16= 5,
 FID_BAYER16x16 = 6
}

typedef int FREE_IMAGE_JPEG_OPERATION; enum : FREE_IMAGE_JPEG_OPERATION {
 FIJPEG_OP_NONE = 0,
 FIJPEG_OP_FLIP_H = 1,
 FIJPEG_OP_FLIP_V = 2,
 FIJPEG_OP_TRANSPOSE = 3,
 FIJPEG_OP_TRANSVERSE = 4,
 FIJPEG_OP_ROTATE_90 = 5,
 FIJPEG_OP_ROTATE_180 = 6,
 FIJPEG_OP_ROTATE_270 = 7
}

typedef int FREE_IMAGE_TMO; enum : FREE_IMAGE_TMO {
    FITMO_DRAGO03 = 0,
 FITMO_REINHARD05 = 1,
 FITMO_FATTAL02 = 2
}

typedef int FREE_IMAGE_FILTER; enum : FREE_IMAGE_FILTER {
 FILTER_BOX = 0,
 FILTER_BICUBIC = 1,
 FILTER_BILINEAR = 2,
 FILTER_BSPLINE = 3,
 FILTER_CATMULLROM = 4,
 FILTER_LANCZOS3 = 5
}

typedef int FREE_IMAGE_COLOR_CHANNEL; enum : FREE_IMAGE_COLOR_CHANNEL {
 FICC_RGB = 0,
 FICC_RED = 1,
 FICC_GREEN = 2,
 FICC_BLUE = 3,
 FICC_ALPHA = 4,
 FICC_BLACK = 5,
 FICC_REAL = 6,
 FICC_IMAG = 7,
 FICC_MAG = 8,
 FICC_PHASE = 9
}
typedef int FREE_IMAGE_MDTYPE; enum : FREE_IMAGE_MDTYPE {
 FIDT_NOTYPE = 0,
 FIDT_BYTE = 1,
 FIDT_ASCII = 2,
 FIDT_SHORT = 3,
 FIDT_LONG = 4,
 FIDT_RATIONAL = 5,
 FIDT_SBYTE = 6,
 FIDT_UNDEFINED = 7,
 FIDT_SSHORT = 8,
 FIDT_SLONG = 9,
 FIDT_SRATIONAL = 10,
 FIDT_FLOAT = 11,
 FIDT_DOUBLE = 12,
 FIDT_IFD = 13,
 FIDT_PALETTE = 14
}

typedef int FREE_IMAGE_MDMODEL; enum : FREE_IMAGE_MDMODEL {
 FIMD_NODATA = -1,
 FIMD_COMMENTS = 0,
 FIMD_EXIF_MAIN = 1,
 FIMD_EXIF_EXIF = 2,
 FIMD_EXIF_GPS = 3,
 FIMD_EXIF_MAKERNOTE = 4,
 FIMD_EXIF_INTEROP = 5,
 FIMD_IPTC = 6,
 FIMD_XMP = 7,
 FIMD_GEOTIFF = 8,
 FIMD_ANIMATION = 9,
 FIMD_CUSTOM = 10
}

struct FIMETADATA { void *data; };

struct FITAG { void *data; };

alias void* fi_handle;
extern (System) alias uint  function(void *buffer, uint size, uint count, fi_handle handle) FI_ReadProc;
extern (System) alias uint  function(void *buffer, uint size, uint count, fi_handle handle) FI_WriteProc;
extern (System) alias int  function(fi_handle handle, ptrdiff_t offset, int origin) FI_SeekProc;
extern (System) alias ptrdiff_t  function(fi_handle handle) FI_TellProc;

struct FreeImageIO {
align(1):
 FI_ReadProc read_proc;
    FI_WriteProc write_proc;
    FI_SeekProc seek_proc;
    FI_TellProc tell_proc;
}

struct FIMEMORY { void *data; };
extern (System) alias  char * function() FI_FormatProc;
extern (System) alias  char * function() FI_DescriptionProc;
extern (System) alias  char * function() FI_ExtensionListProc;
extern (System) alias  char * function() FI_RegExprProc;
extern (System) alias void * function(FreeImageIO *io, fi_handle handle, BOOL read) FI_OpenProc;
extern (System) alias void  function(FreeImageIO *io, fi_handle handle, void *data) FI_CloseProc;
extern (System) alias int  function(FreeImageIO *io, fi_handle handle, void *data) FI_PageCountProc;
extern (System) alias int  function(FreeImageIO *io, fi_handle handle, void *data) FI_PageCapabilityProc;
extern (System) alias FIBITMAP * function(FreeImageIO *io, fi_handle handle, int page, int flags, void *data) FI_LoadProc;
extern (System) alias BOOL  function(FreeImageIO *io, FIBITMAP *dib, fi_handle handle, int page, int flags, void *data) FI_SaveProc;
extern (System) alias BOOL  function(FreeImageIO *io, fi_handle handle) FI_ValidateProc;
extern (System) alias  char * function() FI_MimeProc;
extern (System) alias BOOL  function(int bpp) FI_SupportsExportBPPProc;
extern (System) alias BOOL  function(FREE_IMAGE_TYPE type) FI_SupportsExportTypeProc;
extern (System) alias BOOL  function() FI_SupportsICCProfilesProc;

struct Plugin {
 FI_FormatProc format_proc;
 FI_DescriptionProc description_proc;
 FI_ExtensionListProc extension_proc;
 FI_RegExprProc regexpr_proc;
 FI_OpenProc open_proc;
 FI_CloseProc close_proc;
 FI_PageCountProc pagecount_proc;
 FI_PageCapabilityProc pagecapability_proc;
 FI_LoadProc load_proc;
 FI_SaveProc save_proc;
 FI_ValidateProc validate_proc;
 FI_MimeProc mime_proc;
 FI_SupportsExportBPPProc supports_export_bpp_proc;
 FI_SupportsExportTypeProc supports_export_type_proc;
 FI_SupportsICCProfilesProc supports_icc_profiles_proc;
}

extern (System) alias void  function(Plugin *plugin, int format_id) FI_InitProc;
extern (System) {

void   function(BOOL load_local_plugins_only = 0) FreeImage_Initialise;
void   function() FreeImage_DeInitialise;

char *  function() FreeImage_GetVersion;
char *  function() FreeImage_GetCopyrightMessage;

extern (System) alias void  function(FREE_IMAGE_FORMAT fif,  char *msg) FreeImage_OutputMessageFunction;
extern (System) alias void  function(FREE_IMAGE_FORMAT fif,  char *msg) FreeImage_OutputMessageFunctionStdCall;

void   function(FreeImage_OutputMessageFunctionStdCall omf) FreeImage_SetOutputMessageStdCall;
void   function(FreeImage_OutputMessageFunction omf) FreeImage_SetOutputMessage;
extern (C) void   function(int fif,  char *fmt, ...) FreeImage_OutputMessageProc;

FIBITMAP *  function(int width, int height, int bpp, uint red_mask = 0, uint green_mask = 0, uint blue_mask = 0) FreeImage_Allocate;
FIBITMAP *  function(FREE_IMAGE_TYPE type, int width, int height, int bpp = 8, uint red_mask = 0, uint green_mask = 0, uint blue_mask = 0) FreeImage_AllocateT;
FIBITMAP *   function(FIBITMAP *dib) FreeImage_Clone;
void   function(FIBITMAP *dib) FreeImage_Unload;

FIBITMAP *  function(FREE_IMAGE_FORMAT fif,  char *filename, int flags = 0) FreeImage_Load;
FIBITMAP *  function(FREE_IMAGE_FORMAT fif,  wchar *filename, int flags = 0) FreeImage_LoadU;
FIBITMAP *  function(FREE_IMAGE_FORMAT fif, FreeImageIO *io, fi_handle handle, int flags = 0) FreeImage_LoadFromHandle;
BOOL   function(FREE_IMAGE_FORMAT fif, FIBITMAP *dib,  char *filename, int flags = 0) FreeImage_Save;
BOOL   function(FREE_IMAGE_FORMAT fif, FIBITMAP *dib,  wchar *filename, int flags = 0) FreeImage_SaveU;
BOOL   function(FREE_IMAGE_FORMAT fif, FIBITMAP *dib, FreeImageIO *io, fi_handle handle, int flags = 0) FreeImage_SaveToHandle;

FIMEMORY *  function(BYTE *data = null, DWORD size_in_bytes = 0) FreeImage_OpenMemory;
void   function(FIMEMORY *stream) FreeImage_CloseMemory;
FIBITMAP *  function(FREE_IMAGE_FORMAT fif, FIMEMORY *stream, int flags = 0) FreeImage_LoadFromMemory;
BOOL   function(FREE_IMAGE_FORMAT fif, FIBITMAP *dib, FIMEMORY *stream, int flags = 0) FreeImage_SaveToMemory;
ptrdiff_t   function(FIMEMORY *stream) FreeImage_TellMemory;
BOOL   function(FIMEMORY *stream, ptrdiff_t offset, int origin) FreeImage_SeekMemory;
BOOL   function(FIMEMORY *stream, BYTE **data, DWORD *size_in_bytes) FreeImage_AcquireMemory;
uint   function(void *buffer, uint size, uint count, FIMEMORY *stream) FreeImage_ReadMemory;
uint   function( void *buffer, uint size, uint count, FIMEMORY *stream) FreeImage_WriteMemory;
FIMULTIBITMAP *  function(FREE_IMAGE_FORMAT fif, FIMEMORY *stream, int flags = 0) FreeImage_LoadMultiBitmapFromMemory;

FREE_IMAGE_FORMAT   function(FI_InitProc proc_address,  char *format = null,  char *description = null,  char *extension = null,  char *regexpr = null) FreeImage_RegisterLocalPlugin;
FREE_IMAGE_FORMAT   function( char *path,  char *format = null,  char *description = null,  char *extension = null,  char *regexpr = null) FreeImage_RegisterExternalPlugin;
int   function() FreeImage_GetFIFCount;
int   function(FREE_IMAGE_FORMAT fif, BOOL enable) FreeImage_SetPluginEnabled;
int   function(FREE_IMAGE_FORMAT fif) FreeImage_IsPluginEnabled;
FREE_IMAGE_FORMAT   function( char *format) FreeImage_GetFIFFromFormat;
FREE_IMAGE_FORMAT   function( char *mime) FreeImage_GetFIFFromMime;
char *  function(FREE_IMAGE_FORMAT fif) FreeImage_GetFormatFromFIF;
char *  function(FREE_IMAGE_FORMAT fif) FreeImage_GetFIFExtensionList;
char *  function(FREE_IMAGE_FORMAT fif) FreeImage_GetFIFDescription;
char *  function(FREE_IMAGE_FORMAT fif) FreeImage_GetFIFRegExpr;
char *  function(FREE_IMAGE_FORMAT fif) FreeImage_GetFIFMimeType;
FREE_IMAGE_FORMAT   function( char *filename) FreeImage_GetFIFFromFilename;
FREE_IMAGE_FORMAT   function( wchar *filename) FreeImage_GetFIFFromFilenameU;
BOOL   function(FREE_IMAGE_FORMAT fif) FreeImage_FIFSupportsReading;
BOOL   function(FREE_IMAGE_FORMAT fif) FreeImage_FIFSupportsWriting;
BOOL   function(FREE_IMAGE_FORMAT fif, int bpp) FreeImage_FIFSupportsExportBPP;
BOOL   function(FREE_IMAGE_FORMAT fif, FREE_IMAGE_TYPE type) FreeImage_FIFSupportsExportType;
BOOL   function(FREE_IMAGE_FORMAT fif) FreeImage_FIFSupportsICCProfiles;

FIMULTIBITMAP *   function(FREE_IMAGE_FORMAT fif,  char *filename, BOOL create_new, BOOL read_only, BOOL keep_cache_in_memory = 0, int flags = 0) FreeImage_OpenMultiBitmap;
FIMULTIBITMAP *   function(FREE_IMAGE_FORMAT fif, FreeImageIO *io, fi_handle handle, int flags = 0) FreeImage_OpenMultiBitmapFromHandle;
BOOL   function(FIMULTIBITMAP *bitmap, int flags = 0) FreeImage_CloseMultiBitmap;
int   function(FIMULTIBITMAP *bitmap) FreeImage_GetPageCount;
void   function(FIMULTIBITMAP *bitmap, FIBITMAP *data) FreeImage_AppendPage;
void   function(FIMULTIBITMAP *bitmap, int page, FIBITMAP *data) FreeImage_InsertPage;
void   function(FIMULTIBITMAP *bitmap, int page) FreeImage_DeletePage;
FIBITMAP *   function(FIMULTIBITMAP *bitmap, int page) FreeImage_LockPage;
void   function(FIMULTIBITMAP *bitmap, FIBITMAP *data, BOOL changed) FreeImage_UnlockPage;
BOOL   function(FIMULTIBITMAP *bitmap, int target, int source) FreeImage_MovePage;
BOOL   function(FIMULTIBITMAP *bitmap, int *pages, int *count) FreeImage_GetLockedPageNumbers;

FREE_IMAGE_FORMAT   function( char *filename, int size = 0) FreeImage_GetFileType;
FREE_IMAGE_FORMAT   function( wchar *filename, int size = 0) FreeImage_GetFileTypeU;
FREE_IMAGE_FORMAT   function(FreeImageIO *io, fi_handle handle, int size = 0) FreeImage_GetFileTypeFromHandle;
FREE_IMAGE_FORMAT   function(FIMEMORY *stream, int size = 0) FreeImage_GetFileTypeFromMemory;

FREE_IMAGE_TYPE   function(FIBITMAP *dib) FreeImage_GetImageType;

BOOL   function() FreeImage_IsLittleEndian;
BOOL   function( char *szColor, BYTE *nRed, BYTE *nGreen, BYTE *nBlue) FreeImage_LookupX11Color;
BOOL   function( char *szColor, BYTE *nRed, BYTE *nGreen, BYTE *nBlue) FreeImage_LookupSVGColor;

BYTE *  function(FIBITMAP *dib) FreeImage_GetBits;
BYTE *  function(FIBITMAP *dib, int scanline) FreeImage_GetScanLine;

BOOL   function(FIBITMAP *dib, uint x, uint y, BYTE *value) FreeImage_GetPixelIndex;
BOOL   function(FIBITMAP *dib, uint x, uint y, RGBQUAD *value) FreeImage_GetPixelColor;
BOOL   function(FIBITMAP *dib, uint x, uint y, BYTE *value) FreeImage_SetPixelIndex;
BOOL   function(FIBITMAP *dib, uint x, uint y, RGBQUAD *value) FreeImage_SetPixelColor;

uint   function(FIBITMAP *dib) FreeImage_GetColorsUsed;
uint   function(FIBITMAP *dib) FreeImage_GetBPP;
uint   function(FIBITMAP *dib) FreeImage_GetWidth;
uint   function(FIBITMAP *dib) FreeImage_GetHeight;
uint   function(FIBITMAP *dib) FreeImage_GetLine;
uint   function(FIBITMAP *dib) FreeImage_GetPitch;
uint   function(FIBITMAP *dib) FreeImage_GetDIBSize;
RGBQUAD *  function(FIBITMAP *dib) FreeImage_GetPalette;

uint   function(FIBITMAP *dib) FreeImage_GetDotsPerMeterX;
uint   function(FIBITMAP *dib) FreeImage_GetDotsPerMeterY;
void   function(FIBITMAP *dib, uint res) FreeImage_SetDotsPerMeterX;
void   function(FIBITMAP *dib, uint res) FreeImage_SetDotsPerMeterY;

BITMAPINFOHEADER *  function(FIBITMAP *dib) FreeImage_GetInfoHeader;
BITMAPINFO *  function(FIBITMAP *dib) FreeImage_GetInfo;
FREE_IMAGE_COLOR_TYPE   function(FIBITMAP *dib) FreeImage_GetColorType;

uint   function(FIBITMAP *dib) FreeImage_GetRedMask;
uint   function(FIBITMAP *dib) FreeImage_GetGreenMask;
uint   function(FIBITMAP *dib) FreeImage_GetBlueMask;

uint   function(FIBITMAP *dib) FreeImage_GetTransparencyCount;
BYTE *   function(FIBITMAP *dib) FreeImage_GetTransparencyTable;
void   function(FIBITMAP *dib, BOOL enabled) FreeImage_SetTransparent;
void   function(FIBITMAP *dib, BYTE *table, int count) FreeImage_SetTransparencyTable;
BOOL   function(FIBITMAP *dib) FreeImage_IsTransparent;
void   function(FIBITMAP *dib, int index) FreeImage_SetTransparentIndex;
int   function(FIBITMAP *dib) FreeImage_GetTransparentIndex;

BOOL   function(FIBITMAP *dib) FreeImage_HasBackgroundColor;
BOOL   function(FIBITMAP *dib, RGBQUAD *bkcolor) FreeImage_GetBackgroundColor;
BOOL   function(FIBITMAP *dib, RGBQUAD *bkcolor) FreeImage_SetBackgroundColor;

FIICCPROFILE *  function(FIBITMAP *dib) FreeImage_GetICCProfile;
FIICCPROFILE *  function(FIBITMAP *dib, void *data, ptrdiff_t size) FreeImage_CreateICCProfile;
void   function(FIBITMAP *dib) FreeImage_DestroyICCProfile;

void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine1To4;
void   function(BYTE *target, BYTE *source, int width_in_pixels, RGBQUAD *palette) FreeImage_ConvertLine8To4;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine16To4_555;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine16To4_565;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine24To4;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine32To4;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine1To8;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine4To8;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine16To8_555;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine16To8_565;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine24To8;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine32To8;
void   function(BYTE *target, BYTE *source, int width_in_pixels, RGBQUAD *palette) FreeImage_ConvertLine1To16_555;
void   function(BYTE *target, BYTE *source, int width_in_pixels, RGBQUAD *palette) FreeImage_ConvertLine4To16_555;
void   function(BYTE *target, BYTE *source, int width_in_pixels, RGBQUAD *palette) FreeImage_ConvertLine8To16_555;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine16_565_To16_555;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine24To16_555;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine32To16_555;
void   function(BYTE *target, BYTE *source, int width_in_pixels, RGBQUAD *palette) FreeImage_ConvertLine1To16_565;
void   function(BYTE *target, BYTE *source, int width_in_pixels, RGBQUAD *palette) FreeImage_ConvertLine4To16_565;
void   function(BYTE *target, BYTE *source, int width_in_pixels, RGBQUAD *palette) FreeImage_ConvertLine8To16_565;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine16_555_To16_565;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine24To16_565;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine32To16_565;
void   function(BYTE *target, BYTE *source, int width_in_pixels, RGBQUAD *palette) FreeImage_ConvertLine1To24;
void   function(BYTE *target, BYTE *source, int width_in_pixels, RGBQUAD *palette) FreeImage_ConvertLine4To24;
void   function(BYTE *target, BYTE *source, int width_in_pixels, RGBQUAD *palette) FreeImage_ConvertLine8To24;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine16To24_555;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine16To24_565;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine32To24;
void   function(BYTE *target, BYTE *source, int width_in_pixels, RGBQUAD *palette) FreeImage_ConvertLine1To32;
void   function(BYTE *target, BYTE *source, int width_in_pixels, RGBQUAD *palette) FreeImage_ConvertLine4To32;
void   function(BYTE *target, BYTE *source, int width_in_pixels, RGBQUAD *palette) FreeImage_ConvertLine8To32;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine16To32_555;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine16To32_565;
void   function(BYTE *target, BYTE *source, int width_in_pixels) FreeImage_ConvertLine24To32;

FIBITMAP *  function(FIBITMAP *dib) FreeImage_ConvertTo4Bits;
FIBITMAP *  function(FIBITMAP *dib) FreeImage_ConvertTo8Bits;
FIBITMAP *  function(FIBITMAP *dib) FreeImage_ConvertToGreyscale;
FIBITMAP *  function(FIBITMAP *dib) FreeImage_ConvertTo16Bits555;
FIBITMAP *  function(FIBITMAP *dib) FreeImage_ConvertTo16Bits565;
FIBITMAP *  function(FIBITMAP *dib) FreeImage_ConvertTo24Bits;
FIBITMAP *  function(FIBITMAP *dib) FreeImage_ConvertTo32Bits;
FIBITMAP *  function(FIBITMAP *dib, FREE_IMAGE_QUANTIZE quantize) FreeImage_ColorQuantize;
FIBITMAP *  function(FIBITMAP *dib, FREE_IMAGE_QUANTIZE quantize = FIQ_WUQUANT, int PaletteSize = 256, int ReserveSize = 0, RGBQUAD *ReservePalette = null) FreeImage_ColorQuantizeEx;
FIBITMAP *  function(FIBITMAP *dib, BYTE T) FreeImage_Threshold;
FIBITMAP *  function(FIBITMAP *dib, FREE_IMAGE_DITHER algorithm) FreeImage_Dither;

FIBITMAP *  function(BYTE *bits, int width, int height, int pitch, uint bpp, uint red_mask, uint green_mask, uint blue_mask, BOOL topdown = 0) FreeImage_ConvertFromRawBits;
void   function(BYTE *bits, FIBITMAP *dib, int pitch, uint bpp, uint red_mask, uint green_mask, uint blue_mask, BOOL topdown = 0) FreeImage_ConvertToRawBits;

FIBITMAP *  function(FIBITMAP *dib) FreeImage_ConvertToRGBF;

FIBITMAP *  function(FIBITMAP *src, BOOL scale_linear = 1) FreeImage_ConvertToStandardType;
FIBITMAP *  function(FIBITMAP *src, FREE_IMAGE_TYPE dst_type, BOOL scale_linear = 1) FreeImage_ConvertToType;

FIBITMAP *  function(FIBITMAP *dib, FREE_IMAGE_TMO tmo, double first_param = 0, double second_param = 0) FreeImage_ToneMapping;
FIBITMAP *  function(FIBITMAP *src, double gamma = 2.2, double exposure = 0) FreeImage_TmoDrago03;
FIBITMAP *  function(FIBITMAP *src, double intensity = 0, double contrast = 0) FreeImage_TmoReinhard05;
FIBITMAP *  function(FIBITMAP *src, double intensity = 0, double contrast = 0, double adaptation = 1, double color_correction = 0) FreeImage_TmoReinhard05Ex;

FIBITMAP *  function(FIBITMAP *src, double color_saturation = 0.5, double attenuation = 0.85) FreeImage_TmoFattal02;

DWORD   function(BYTE *target, DWORD target_size, BYTE *source, DWORD source_size) FreeImage_ZLibCompress;
DWORD   function(BYTE *target, DWORD target_size, BYTE *source, DWORD source_size) FreeImage_ZLibUncompress;
DWORD   function(BYTE *target, DWORD target_size, BYTE *source, DWORD source_size) FreeImage_ZLibGZip;
DWORD   function(BYTE *target, DWORD target_size, BYTE *source, DWORD source_size) FreeImage_ZLibGUnzip;
DWORD   function(DWORD crc, BYTE *source, DWORD source_size) FreeImage_ZLibCRC32;

FITAG *  function() FreeImage_CreateTag;
void   function(FITAG *tag) FreeImage_DeleteTag;
FITAG *  function(FITAG *tag) FreeImage_CloneTag;

char *  function(FITAG *tag) FreeImage_GetTagKey;
char *  function(FITAG *tag) FreeImage_GetTagDescription;
WORD   function(FITAG *tag) FreeImage_GetTagID;
FREE_IMAGE_MDTYPE   function(FITAG *tag) FreeImage_GetTagType;
DWORD   function(FITAG *tag) FreeImage_GetTagCount;
DWORD   function(FITAG *tag) FreeImage_GetTagLength;
void *  function(FITAG *tag) FreeImage_GetTagValue;

BOOL   function(FITAG *tag,  char *key) FreeImage_SetTagKey;
BOOL   function(FITAG *tag,  char *description) FreeImage_SetTagDescription;
BOOL   function(FITAG *tag, WORD id) FreeImage_SetTagID;
BOOL   function(FITAG *tag, FREE_IMAGE_MDTYPE type) FreeImage_SetTagType;
BOOL   function(FITAG *tag, DWORD count) FreeImage_SetTagCount;
BOOL   function(FITAG *tag, DWORD length) FreeImage_SetTagLength;
BOOL   function(FITAG *tag,  void *value) FreeImage_SetTagValue;

FIMETADATA *  function(FREE_IMAGE_MDMODEL model, FIBITMAP *dib, FITAG **tag) FreeImage_FindFirstMetadata;
BOOL   function(FIMETADATA *mdhandle, FITAG **tag) FreeImage_FindNextMetadata;
void   function(FIMETADATA *mdhandle) FreeImage_FindCloseMetadata;

BOOL   function(FREE_IMAGE_MDMODEL model, FIBITMAP *dib,  char *key, FITAG *tag) FreeImage_SetMetadata;
BOOL   function(FREE_IMAGE_MDMODEL model, FIBITMAP *dib,  char *key, FITAG **tag) FreeImage_GetMetadata;

uint   function(FREE_IMAGE_MDMODEL model, FIBITMAP *dib) FreeImage_GetMetadataCount;
BOOL   function(FIBITMAP *dst, FIBITMAP *src) FreeImage_CloneMetadata;

char*   function(FREE_IMAGE_MDMODEL model, FITAG *tag, char *Make = null) FreeImage_TagToString;

FIBITMAP *  function(FIBITMAP *dib, double angle) FreeImage_RotateClassic;
FIBITMAP *  function(FIBITMAP *dib, double angle,  void *bkcolor = null) FreeImage_Rotate;
FIBITMAP *  function(FIBITMAP *dib, double angle, double x_shift, double y_shift, double x_origin, double y_origin, BOOL use_mask) FreeImage_RotateEx;
BOOL   function(FIBITMAP *dib) FreeImage_FlipHorizontal;
BOOL   function(FIBITMAP *dib) FreeImage_FlipVertical;
BOOL   function( char *src_file,  char *dst_file, FREE_IMAGE_JPEG_OPERATION operation, BOOL perfect = 0) FreeImage_JPEGTransform;
BOOL   function( wchar *src_file,  wchar *dst_file, FREE_IMAGE_JPEG_OPERATION operation, BOOL perfect = 0) FreeImage_JPEGTransformU;

FIBITMAP *  function(FIBITMAP *dib, int dst_width, int dst_height, FREE_IMAGE_FILTER filter) FreeImage_Rescale;
FIBITMAP *  function(FIBITMAP *dib, int max_pixel_size, BOOL convert = 1) FreeImage_MakeThumbnail;

BOOL   function(FIBITMAP *dib, BYTE *LUT, FREE_IMAGE_COLOR_CHANNEL channel) FreeImage_AdjustCurve;
BOOL   function(FIBITMAP *dib, double gamma) FreeImage_AdjustGamma;
BOOL   function(FIBITMAP *dib, double percentage) FreeImage_AdjustBrightness;
BOOL   function(FIBITMAP *dib, double percentage) FreeImage_AdjustContrast;
BOOL   function(FIBITMAP *dib) FreeImage_Invert;
BOOL   function(FIBITMAP *dib, DWORD *histo, FREE_IMAGE_COLOR_CHANNEL channel = FICC_BLACK) FreeImage_GetHistogram;
int   function(BYTE *LUT, double brightness, double contrast, double gamma, BOOL invert) FreeImage_GetAdjustColorsLookupTable;
BOOL   function(FIBITMAP *dib, double brightness, double contrast, double gamma, BOOL invert = 0) FreeImage_AdjustColors;
uint   function(FIBITMAP *dib, RGBQUAD *srccolors, RGBQUAD *dstcolors, uint count, BOOL ignore_alpha, BOOL swap) FreeImage_ApplyColorMapping;
uint   function(FIBITMAP *dib, RGBQUAD *color_a, RGBQUAD *color_b, BOOL ignore_alpha) FreeImage_SwapColors;
uint   function(FIBITMAP *dib, BYTE *srcindices, BYTE *dstindices, uint count, BOOL swap) FreeImage_ApplyPaletteIndexMapping;
uint   function(FIBITMAP *dib, BYTE *index_a, BYTE *index_b) FreeImage_SwapPaletteIndices;

FIBITMAP *  function(FIBITMAP *dib, FREE_IMAGE_COLOR_CHANNEL channel) FreeImage_GetChannel;
BOOL   function(FIBITMAP *dib, FIBITMAP *dib8, FREE_IMAGE_COLOR_CHANNEL channel) FreeImage_SetChannel;
FIBITMAP *  function(FIBITMAP *src, FREE_IMAGE_COLOR_CHANNEL channel) FreeImage_GetComplexChannel;
BOOL   function(FIBITMAP *dst, FIBITMAP *src, FREE_IMAGE_COLOR_CHANNEL channel) FreeImage_SetComplexChannel;

FIBITMAP *  function(FIBITMAP *dib, int left, int top, int right, int bottom) FreeImage_Copy;
BOOL   function(FIBITMAP *dst, FIBITMAP *src, int left, int top, int alpha) FreeImage_Paste;
FIBITMAP *  function(FIBITMAP *fg, BOOL useFileBkg = 0, RGBQUAD *appBkColor = null, FIBITMAP *bg = null) FreeImage_Composite;
BOOL   function( char *src_file,  char *dst_file, int left, int top, int right, int bottom) FreeImage_JPEGCrop;
BOOL   function( wchar *src_file,  wchar *dst_file, int left, int top, int right, int bottom) FreeImage_JPEGCropU;
BOOL   function(FIBITMAP *dib) FreeImage_PreMultiplyWithAlpha;

BOOL   function(FIBITMAP *dib,  void *color, int options = 0) FreeImage_FillBackground;
FIBITMAP *  function(FIBITMAP *src, int left, int top, int right, int bottom,  void *color, int options = 0) FreeImage_EnlargeCanvas;
FIBITMAP *  function(int width, int height, int bpp,  RGBQUAD *color, int options = 0,  RGBQUAD *palette = null, uint red_mask = 0, uint green_mask = 0, uint blue_mask = 0) FreeImage_AllocateEx;
FIBITMAP *  function(FREE_IMAGE_TYPE type, int width, int height, int bpp,  void *color, int options = 0,  RGBQUAD *palette = null, uint red_mask = 0, uint green_mask = 0, uint blue_mask = 0) FreeImage_AllocateExT;

FIBITMAP *  function(FIBITMAP *Laplacian, int ncycle = 3) FreeImage_MultigridPoissonSolver;

}
