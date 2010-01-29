//************************************************************************** 
//* Asciiexp.h	- Ascii File Exporter
//* 
//* By Christer Janson
//* Kinetix Development
//*
//* January 20, 1997 CCJ Initial coding
//*
//* Class definition 
//*
//* Copyright (c) 1997, All Rights Reserved. 
//***************************************************************************

#ifndef __HSFEXP__H
#define __HSFEXP__H

#include "Max.h"
#include "resource.h"
#include "istdplug.h"
#include "stdmat.h"
#include "decomp.h"
#include "shape.h"
#include "interpik.h"

#include <vector>
#include <map>

extern ClassDesc* GetHSFExpDesc();
extern TCHAR *GetString(int id);
extern HINSTANCE hInstance;

#define VERSION			200			// Version number * 100
//#define FLOAT_OUTPUT	_T("%4.4f")	// Float precision for output
#define CFGFILENAME		_T("HSFEXP.CFG")	// Configuration file

#define HSFEXP_CLASS_ID	Class_ID(0x70bf6edc, 0x6ed92b55)

class MtlKeeper {
public:
	BOOL	AddMtl(Mtl* mtl);
	int		GetMtlID(Mtl* mtl);
	int		Count();
	Mtl*	GetMtl(int id);

	Tab<Mtl*> mtlTab;
};

// This is the main class for the exporter.


struct SceneNode {
	INode*	node;
	INode*	parent;

	SceneNode(INode* n, INode* p)
		: node(n), parent(p)
	{}
};


class HSFExp : public SceneExport {
public:
	HSFExp();
	~HSFExp();

	// SceneExport methods
	int    ExtCount();     // Number of extensions supported 
	const TCHAR * Ext(int n);     // Extension #n (i.e. "hsf")
	const TCHAR * LongDesc();     // Long HSF description (i.e. "HSF Export") 
	const TCHAR * ShortDesc();    // Short HSF description (i.e. "HSF")
	const TCHAR * AuthorName();    // ASCII Author name
	const TCHAR * CopyrightMessage();   // ASCII Copyright message 
	const TCHAR * OtherMessage1();   // Other message #1
	const TCHAR * OtherMessage2();   // Other message #2
	unsigned int Version();     // Version number * 100 (i.e. v3.01 = 301) 
	void	ShowAbout(HWND hWnd);  // Show DLL's "About..." box
	int		DoExport(const TCHAR *name,ExpInterface *ei,Interface *i, BOOL suppressPrompts=FALSE, DWORD options=0); // Export	file
	BOOL	SupportsOptions(int ext, DWORD options);



    Interface* mIp;         // MAX interface pointer

    // UI controls
    static ISpinnerControl* tformSpin;
    static ISpinnerControl* coordSpin;
    static ISpinnerControl* flipbookSpin;

private:
    inline BOOL GetFlipBook() { return mFlipBook; }
    inline void SetFlipBook(BOOL ci) { mFlipBook = ci; }

    inline BOOL GetFlipbookSample() { return mFlipbookSample; }
    inline void SetFlipbookSample(BOOL b) { mFlipbookSample = b; }
    inline int GetFlipbookSampleRate() { return mFlipbookSampleRate; }
    inline void SetFlipbookSampleRate(int rate) { mFlipbookSampleRate = rate; }

	TCHAR* point(Point3& p);
    TCHAR* scalePoint(Point3& p);
    TCHAR* normPoint(Point3& p);
    TCHAR* axisPoint(Point3& p, float ang);
    TCHAR* texture(UVVert& uv);
    TCHAR* color(Color& c);
    TCHAR* color(Point3& c);
    TCHAR* floatVal(float f);

	void findSceneNodes(INode* node, INode* parent);
	void exportSceneNodes(int level);
	void exportSceneNode(INode* node, INode* parent, int level);

	void findMeshesAndMaterials();
	void findMaterial(Mtl* m);
	void findMaterial(INode* node);

	int  getMaterialId(Mtl* m);
	int  mLastExporterdMaterial;

	void exportMaterials(int level);
	void exportMaterial(Mtl* mat, int level);
	void exportMaterialMap(Mtl* mat, unsigned tmapId, int level);

	void exportMeshes(int level);
	void exportMesh(INode* node, TriObject* mesh, int level);
	int  getNodeId(INode* node);
	char* escapeName(char* name);
    
    void initializeDefaults();
    // VRBL Output routines
    void Indent(int level);
	void newln();
	void semicolon();
    //BOOL IsBBoxTrigger(INode* node);
	Matrix3 GetLocalTM(INode* node);
	Matrix3 calcNoScaleMatrix(Matrix3 world);
	Matrix3 calcRescaleMatrix(Matrix3 world);
    void OutputNodeTransform(INode* node, int level);
/*    void OutputMultiMtl(Mtl* mtl, int level);
    void OutputNoTexture(int level);
    BOOL OutputMaterial(INode* node, BOOL& twoSided, int level);
    BOOL HasTexture(INode *node);
    TextureDesc*GetMatTex(INode* node);
    void OutputNormalIndices(Mesh& mesh, NormalTable* normTab, int level);
    NormalTable* OutputNormals(Mesh& mesh, int level);*/
    /*void OutputTriObject(INode* node, TriObject* obj, BOOL multiMat,
                         BOOL twoSided, int level);
    BOOL VrblOutSpecial(INode* node, INode* parent, Object* obj, int level);
    BOOL VrblOutPointLight(INode* node, LightObject* light, int level);
    BOOL VrblOutDirectLight(INode* node, LightObject* light, int level);
    BOOL VrblOutSpotLight(INode* node, LightObject* light, int level);
    BOOL VrblOutTopPointLight(INode* node, LightObject* light);
    BOOL VrblOutTopDirectLight(INode* node, LightObject* light);
    BOOL VrblOutTopSpotLight(INode* node, LightObject* light);
    void OutputTopLevelLight(INode* node, LightObject *light);
    BOOL IsLight(INode* node);
    void TraverseNode(INode* node);
    void VrblOutFileInfo();
    void VrblOutNode(INode* node, INode* parent, int level, BOOL isLOD,
                     BOOL lastChild);
	void GenerateUniqueNodeNames(INode* node);*/

    FILE*		mStream;     // The file mStream to write
    BOOL		mIndent;     // Should we indent?
//    BOOL		mHadAnim;    // File has animation data
    TimeValue	mStart;      // First frame of the animation
	CStr		mExportDir;

	std::vector<SceneNode>	mSceneNodes;
	std::map<Mtl*, int>		mMtlToId;
	std::vector<Mtl*>		mMaterials;

	int		mNumTriMeshes;
	int		mNumMaterials;
	int		mNextNodeId;
	int		mNextMeshId;
	int		mNextMaterialId;

    BOOL       mFlipBook;   // Generate multiple file one file per frame (LEC request)
    BOOL       mTformSample;// TRUE for once per frame, FALSE for cusom rate
    int        mTformSampleRate; // Custom sample rate
    BOOL       mCoordSample;// TRUE for once per frame, FALSE for cusom rate
    int        mCoordSampleRate; // Custom sample rate
    BOOL       mFlipbookSample;     // TRUE for once per frame, FALSE for cusom rate
    int        mFlipbookSampleRate; // Custom sample rate
    Box3       mBoundBox;   // Bounding box for the whole scene
    TSTR       mTitle;      // Title of world
    TSTR       mInfo;       // Info for world
    BOOL       mExportHidden; // Export hidden objects
    BOOL       mEnableProgressBar;  // Enable export progress bar
    BOOL       mPrimitives;   // Create VRML primitves
    int         mPolygonType;   // 0 triangle, 1 QUADS, 2 NGONS
    BOOL       mPreLight;       // should we calculate the color per vertex
    BOOL       mCPVSource;  // 1 if MAX; 0 if we should calculate the color per vertex
//	NodeTable	mNodes;		// hash table of all nodes' name in the scene
};

#endif // __HSFEXP__H


// Handy file class

class WorkFile {
private:
    FILE *mStream;
	
public:
    WorkFile(const TCHAR *filename,const TCHAR *mode)
        { mStream = NULL; Open(filename, mode); };
    ~WorkFile()
        { Close(); };
    FILE *MStream()
        { return mStream; };
    int	Close()
        { int result=0;
          if(mStream) result=fclose(mStream);
          mStream = NULL;
          return result; }
    void	Open(const TCHAR *filename,const TCHAR *mode)
        { Close(); mStream = _tfopen(filename,mode); }
};

