/**********************************************************************
 *<
	FILE: dllmain.cpp

	DESCRIPTION:   DLL implementation of primitives

	CREATED BY: Charles Thaeler

        BASED on helpers.cpp

	HISTORY: created 12 February 1996

 *>	Copyright (c) 1994, All Rights Reserved.
 **********************************************************************/

#include "hsfexp.h"
#include "3dsmaxport.h"
#include "resource.h"

HINSTANCE hInstance;

static BOOL showPrompts;
static BOOL exportSelected;

BOOL WINAPI DllMain(HINSTANCE hinstDLL,ULONG fdwReason,LPVOID lpvReserved) 
{
   if( fdwReason == DLL_PROCESS_ATTACH )
   {
      hInstance = hinstDLL;
      DisableThreadLibraryCalls(hInstance);
   }

	return (TRUE);
}

TCHAR *GetString(int id)
{
	static TCHAR buf[256];

	if (hInstance)
		return LoadString(hInstance, id, buf, sizeof(buf)) ? buf : NULL;

	return NULL;
}

__declspec( dllexport ) const TCHAR* LibDescription() 
{
	return GetString(IDS_LIBDESCRIPTION);
}

/// MUST CHANGE THIS NUMBER WHEN ADD NEW CLASS 
__declspec( dllexport ) int LibNumberClasses() 
{
	return 1;
}


__declspec( dllexport ) ClassDesc* LibClassDesc(int i) 
{
	switch(i) {
	case 0: return GetHSFExpDesc();
	default: return 0;
	}
}

__declspec( dllexport ) ULONG LibVersion() 
{
	return VERSION_3DSMAX;
}

// Let the plug-in register itself for deferred loading
__declspec( dllexport ) ULONG CanAutoDefer()
{
	return 1;
}

class HSFExpClassDesc:public ClassDesc {
public:
	int				IsPublic() { return 1; }
	void*			Create(BOOL loading = FALSE) { return new HSFExp; } 
	const TCHAR*	ClassName() { return GetString(IDS_VRML_EXPORT); }
	SClass_ID		SuperClassID() { return SCENE_EXPORT_CLASS_ID; } 
	Class_ID		ClassID() { return HSFEXP_CLASS_ID; }
	const TCHAR*	Category() { return GetString(IDS_TH_SCENEEXPORT); }
};

static HSFExpClassDesc HSFExpDesc;

ClassDesc* GetHSFExpDesc()
{
	return &HSFExpDesc;
}
