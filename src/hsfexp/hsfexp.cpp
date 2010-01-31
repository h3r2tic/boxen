/**********************************************************************
 *<
   FILE: vrmlexp.cpp

   DESCRIPTION:  VRML/VRBL .WRL file export module

   CREATED BY: Scott Morrison

   HISTORY: created 15 February, 1996

 *>   Copyright (c) 1996, 1997 All Rights Reserved.
 **********************************************************************/

#include "hsfexp.h"
#include "3dsmaxport.h"
#include "maxheapdirect.h"
#include "appd.h"
#include "helpsys.h"


extern TCHAR *GetString(int id);

// Returns TRUE if an object or one of its ancestors in animated
static BOOL IsEverAnimated(INode* node);

void
CommaScan(TCHAR* buf)
{
    for(; *buf; buf++) if (*buf == ',') *buf = '.';
}

unsigned int floatRepr(const float f) {
	return *reinterpret_cast<const unsigned int*>(&f);
}

// Function for writing values into a string for output.  
// These functions take care of rounding values near zero, and flipping
// Y and Z for VRML output.

// Format a 3D coordinate value.
TCHAR*
HSFExp::point(Point3& p)
{
    static TCHAR buf[50];
    sprintf(buf, _T("%8.8x%8.8x%8.8x"),
		floatRepr(p.x),
		floatRepr(p.z),
		floatRepr(-p.y)
	);
    return buf;
}

TCHAR*
HSFExp::color(Color& c)
{
    static TCHAR buf[50];
    sprintf(buf, _T("%g %g %g"), c.r, c.g, c.b);
    CommaScan(buf);
    return buf;
}

TCHAR*
HSFExp::color(Point3& c)
{
    static TCHAR buf[50];
    sprintf(buf, _T("%g %g %g"), c.x, c.y, c.z);
    CommaScan(buf);
    return buf;
}


TCHAR*
HSFExp::floatVal(float f)
{
    static TCHAR buf[50];
    sprintf(buf, "%f", f);
    CommaScan(buf);
    return buf;
}


TCHAR*
HSFExp::texture(UVVert& uv)
{
    static TCHAR buf[50];
    sprintf(buf, _T("%8.8x%8.8x%8.8x"),
		floatRepr(uv.x),
		floatRepr(uv.y),
		floatRepr(uv.z)
	);
    return buf;
}

// Format a scale value
TCHAR*
HSFExp::scalePoint(Point3& p)
{
    static TCHAR buf[50];
    sprintf(buf, _T("%8.8x%8.8x%8.8x"),
		floatRepr(p.x),
		floatRepr(p.z),
		floatRepr(p.y)
	);
    return buf;
}

// Format a normal vector
TCHAR*
HSFExp::normPoint(Point3& p)
{
    static TCHAR buf[50];
    sprintf(buf, _T("%8.8x%8.8x%8.8x"),
		floatRepr(p.x),
		floatRepr(p.z),
		floatRepr(-p.y)
	);
    return buf;
}

// Format an axis value
TCHAR*
HSFExp::axisPoint(Point3& p, float angle)
{
    static TCHAR buf[50];
    sprintf(buf, _T("%8.8x%8.8x%8.8x%8.8x"),
		floatRepr(p.x),
		floatRepr(p.z),
		floatRepr(-p.y),
		floatRepr(-angle)
	);
    return buf;
}

// Get the tranform matrix that take a point from its local coordinate
// system to its parent's coordinate system
Matrix3 HSFExp::GetLocalTM(INode* node)
{
    Matrix3 tm;
    tm = node->GetObjTMAfterWSM(mStart);
    if (!node->GetParentNode()->IsRootNode()) {
        Matrix3 ip = node->GetParentNode()->GetObjTMAfterWSM(mStart);
		ip = Inverse(calcNoScaleMatrix(ip));
        tm = tm * ip;
    }
    return tm;
}

Matrix3 HSFExp::calcNoScaleMatrix(Matrix3 world) {
	Matrix3 res(1);	 // identity

    AffineParts parts;
    decomp_affine(world, &parts);

	res.SetRotate(parts.q);
	res *= TransMatrix(parts.t);

	return res;
}


Matrix3 HSFExp::calcRescaleMatrix(Matrix3 world) {
	Matrix3 noscale = calcNoScaleMatrix(world);
	noscale.Invert();
	return world * noscale;
}


class HSFClassDesc:public ClassDesc {
public:
    int    IsPublic()                   { return TRUE; }
    void*  Create(BOOL loading = FALSE) { return new HSFExp; }
    const  TCHAR* ClassName()           {return _T(GetString(IDS_VRML_EXPORT_CLASS));}
    SClass_ID   SuperClassID()         { return SCENE_EXPORT_CLASS_ID; }
    Class_ID    ClassID()    { return HSFEXP_CLASS_ID; }
    const TCHAR* Category()   { return GetString(IDS_TH_SCENEEXPORT); }
};

static HSFClassDesc HSFDesc;

ClassDesc* GetVRBLDesc() { return &HSFDesc; }

////////////////////////////////////////////////////////////////////////
// VRBL Export implementation
////////////////////////////////////////////////////////////////////////

// Indent to the given level.
void 
HSFExp::Indent(int level)
{
    if (!mIndent) return;
    assert(level >= 0);
    for(; level; level--)
        fprintf(mStream, _T("  "));
}

void HSFExp::newln() {
	fprintf(mStream, _T("\n"));
}
    
void HSFExp::semicolon() {
	fprintf(mStream, _T(";\n"));
}

/// delete[] the result
char* HSFExp::escapeName(char* name) {
	size_t reqLen = 1 + (name ? strlen(name) : 0);

	if (name) for (char* c = name; *c; ++c) {
		if ('\'' == *c || '\\' == *c) {
			++reqLen;
		}
	}

	char* res = new char[reqLen];
	char* dst = res;

	if (name) for (char* src = name; *src; ++src) {
		if ('\'' == *src || '\\' == *src) {
			*dst++ = '\\';
		}
		*dst++ = *src;
	}

	*dst = '\0';
	return res;
}


// Write out the transform from the local coordinate system to the
// parent coordinate system
void
HSFExp::OutputNodeTransform(INode* node, int level)
{
    // Root node is always identity
    if (node->IsRootNode())
        return;

    Matrix3 tm = GetLocalTM(node);
    int i, j;
    Point3 p;

    // Check for scale and rotation part of matrix being identity.
    BOOL isIdentity = TRUE;
    for (i=0; i<3; i++) {
        for (j=0; j<3; j++) {
            if (i==j) {
                if (tm.GetRow(i)[j] != 1.0f) {
                    isIdentity = FALSE;
                    goto done;
                }
            } else if (fabs(tm.GetRow(i)[j]) > 1.0e-05) {
                isIdentity = FALSE;
                goto done;
            }
        }
    }

  done:
    if (isIdentity) {
        p = tm.GetTrans();
        Indent(level);
        fprintf(mStream, _T("translation %s\n"), point(p));
    } else {
        // If not identity, decompose matrix into scale, rotation and
        // translation components.
        Point3 s, axis;
        Quat q;
        float ang;

        AffineParts parts;
        decomp_affine(tm, &parts);
        p = parts.t;
        q = parts.q;
        AngAxisFromQ(q, &ang, axis);
        Indent(level);
        fprintf(mStream, _T("translation %s\n"), point(p));
        if (ang != 0.0f && ang != -0.0f) {
            Indent(level);
            fprintf(mStream, _T("rotation %s\n"), axisPoint(axis, ang));
        }
        /*ScaleValue sv(parts.k, parts.u);
        s = sv.s;
        if (parts.f < 0.0f)
            s = - s;
        if (s.x != 1.0f || s.y != 1.0f || s.z != 1.0f) {
            Indent(level);
            fprintf(mStream, _T("scale %s\n"), scalePoint(s));
        }*/
    }
}


/*// Write out the indices of the normals for the IndexedFaceSet
void
HSFExp::OutputNormalIndices(Mesh& mesh, NormalTable* normTab, int level)
{
    Point3 n;
    int numfaces = mesh.getNumFaces();
    int i = 0, j = 0, v = 0, norCnt = 0;

    Indent(level);
    
    fprintf(mStream, _T("normalIndex [\n"));
    for (i = 0; i < numfaces; i++) {
        int smGroup = mesh.faces[i].getSmGroup();
        Indent(level+1);
        for(v = 0; v < 3; v++) {
            int cv = mesh.faces[i].v[v];
            RVertex * rv = mesh.getRVertPtr(cv);
            if (rv->rFlags & SPECIFIED_NORMAL) {
                n = rv->rn.getNormal();
                continue;
            }
            else if((norCnt = (int)(rv->rFlags & NORCT_MASK)) != 0 && smGroup) {
                if (norCnt == 1)
                    n = rv->rn.getNormal();
                else for(j = 0; j < norCnt; j++) {
                    if (rv->ern[j].getSmGroup() & smGroup) {
                        n = rv->ern[j].getNormal();
                        break;
                    }
                }
            } else
                n = mesh.getFaceNormal(i);
            int index = normTab->GetIndex(n);
            assert (index != -1);
            fprintf(mStream, _T("%d, "), index);
        }
        fprintf(mStream, _T("-1,\n"));
    }
    Indent(level);
    fprintf(mStream, _T("]\n"));
}

// Create the hash table of normals for the given mesh, and
// write out the normal values.
NormalTable*
HSFExp::OutputNormals(Mesh& mesh, int level)
{
    int norCnt = 0;
    int numverts = mesh.getNumVerts();
    int numfaces = mesh.getNumFaces();
    NormalTable* normTab;


    mesh.buildRenderNormals();

    if (MeshIsAllOneSmoothingGroup(mesh)) {
        // No need for normals when whole object is smooth.
        // VRML Browsers compute normals automatically in this case.
        return NULL;
    }

    normTab = new NormalTable();

    // Otherwise we have several smoothing groups
    for(int index = 0; index < numfaces; index++) {
        int smGroup = mesh.faces[index].getSmGroup();
        for(int i = 0; i < 3; i++) {
            // Now get the normal for each vertex of the face
            // Given the smoothing group
            int cv = mesh.faces[index].v[i];
            RVertex * rv = mesh.getRVertPtr(cv);
            if (rv->rFlags & SPECIFIED_NORMAL) {
                normTab->AddNormal(rv->rn.getNormal());
            }
            else if((norCnt = (int)(rv->rFlags & NORCT_MASK)) != 0 && smGroup) {
                if (norCnt == 1)        // 1 normal, stored in rn
                    normTab->AddNormal(rv->rn.getNormal());
                else for(int j = 0; j < norCnt; j++) {
                    // More than one normal, stored in ern.
                    normTab->AddNormal(rv->ern[j].getNormal());
                }
            } else
                normTab->AddNormal(mesh.getFaceNormal(index));
        }
    }

    // Now write out the table
    NormalDesc* nd;
    Indent(level);
    fprintf(mStream, _T("Normal { vector [\n"));
       
    for(int i = 0, index = 0; i < NORM_TABLE_SIZE; i++) {
        for(nd = normTab->Get(i); nd; nd = nd->next) {
            nd->index = index++;
            Indent(level+1);
            Point3 p = nd->n/NUM_NORMS;
            fprintf(mStream, _T("%s,\n"), normPoint(p));
        }
    }
    Indent(level);
    fprintf(mStream, _T("] }\n"));

    Indent(level);
    fprintf(mStream, _T("NormalBinding { value PER_VERTEX_INDEXED }\n"));
    
#ifdef DEBUG_NORM_HASH
    normTab->PrintStats(mStream);
#endif

    return normTab;
}*/

// Write out the data for a single triangle mesh
/*void
HSFExp::OutputTriObject(INode* node, TriObject* obj, BOOL isMulti,
                            BOOL twoSided, int level)
{
    assert(obj);
    Mesh &mesh = obj->GetMesh();
    int numverts = mesh.getNumVerts();
    int numtverts = mesh.getNumTVerts();
    int numfaces = mesh.getNumFaces();
    int i;
    NormalTable* normTab = NULL;
    TextureDesc* td = GetMatTex(node);

    if (numfaces == 0) {
        delete td;
        return;
    }

   if (isMulti) {
        Indent(level);
        fprintf(mStream, _T("MaterialBinding { value PER_FACE_INDEXED }\n"));
    }

    // Output the vertices
    Indent(level);
    fprintf(mStream, _T("Coordinate3 { point [\n"));
        
    for(i = 0; i < numverts; i++) {
        Point3 p = mesh.verts[i];
        Indent(level+1);
        fprintf(mStream, _T("%s"), point(p));
        if (i == numverts-1) {
            fprintf(mStream, _T("]\n"));
            Indent(level);
            fprintf(mStream, _T("}\n"));
        }
        else
            fprintf(mStream, _T(",\n"));
    }

    // Output the normals
    if (mGenNormals) {
        normTab = OutputNormals(mesh, level);
    }

    // Output Texture coordinates
    if (numtverts > 0 && td) {
        Indent(level);
        fprintf(mStream, _T("TextureCoordinate2 { point [\n"));

        for(i = 0; i < numtverts; i++) {
            UVVert p = mesh.getTVert(i);
            Indent(level+1);
            fprintf(mStream, _T("%s"), texture(p));
            if (i == numtverts-1) {
                fprintf(mStream, _T("]\n"));
                Indent(level);
                fprintf(mStream, _T("}\n"));
            }
            else
                fprintf(mStream, _T(",\n"));
        }
    }

    if (twoSided) {
        Indent(level);
        fprintf(mStream, _T("ShapeHints {\n"));
        Indent(level+1);
        fprintf(mStream, _T("shapeType UNKNOWN_SHAPE_TYPE\n"));
        Indent(level);
        fprintf(mStream, _T("}\n"));
    }
    // Output the triangles
    Indent(level);
    fprintf(mStream, _T("IndexedFaceSet { coordIndex [\n"));
    for(i = 0; i < numfaces; i++) {
        if (!(mesh.faces[i].flags & FACE_HIDDEN)) {
            Indent(level+1);
            fprintf(mStream, _T("%d, %d, %d, -1"), mesh.faces[i].v[0],
                    mesh.faces[i].v[1], mesh.faces[i].v[2]);
            if (i != numfaces-1)
                fprintf(mStream, _T(", \n"));
        }
    }
    fprintf(mStream, _T("]\n"));

    // Output the texture coordinate indices
    if (numtverts > 0 && td) {
        Indent(level);
        fprintf(mStream, _T("textureCoordIndex [\n"));
        for(i = 0; i < numfaces; i++) {
            if (!(mesh.faces[i].flags & FACE_HIDDEN)) {
                Indent(level+1);
                fprintf(mStream, _T("%d, %d, %d, -1"), mesh.tvFace[i].t[0],
                        mesh.tvFace[i].t[1], mesh.tvFace[i].t[2]);
            if (i != numfaces-1)
                fprintf(mStream, _T(", \n"));
            }
        }
        fprintf(mStream, _T("]\n"));
    }

    // Output the material indices
    if (isMulti) {
        Indent(level);
        fprintf(mStream, _T("materialIndex [\n"));
        for(i = 0; i < numfaces; i++) {
            if (!(mesh.faces[i].flags & FACE_HIDDEN)) {
                Indent(level+1);
                fprintf(mStream, _T("%d"), mesh.faces[i].getMatID());
                if (i != numfaces-1)
                    fprintf(mStream, _T(", \n"));
            }
        }
        fprintf(mStream, _T("]\n"));
    }

    // Output the normal indices
    if (mGenNormals && normTab) {
        OutputNormalIndices(mesh, normTab, level);
        delete normTab;
    }
        
    Indent(level);
    fprintf(mStream, _T("}\n"));
    delete td;
}*/

/*// Returns TRUE iff the node has an attached standard material with
// a texture map on the diffuse color
BOOL
HSFExp::HasTexture(INode* node)
{
    TextureDesc* td = GetMatTex(node);
    if (!td)
        return FALSE;
    delete td;
    return TRUE;
}

// Get the name of the texture file of the texure on the diffuse
// color of the material attached to the given node.
TextureDesc*
HSFExp::GetMatTex(INode* node)
{
    Mtl* mtl = node->GetMtl();
    if (!mtl)
        return NULL;

    // We only handle standard materials.
    if (mtl->ClassID() != Class_ID(DMTL_CLASS_ID, 0))
        return NULL;

    StdMat* sm = (StdMat*) mtl;
    // Check for texture map
    Texmap* tm = (BitmapTex*) sm->GetSubTexmap(ID_DI);
    if (!tm)
        return NULL;

    // We only handle bitmap textures in VRML
    if (tm->ClassID() != Class_ID(BMTEX_CLASS_ID, 0))
        return NULL;
    BitmapTex* bm = (BitmapTex*) tm;

    TSTR bitmapFile;
    TSTR fileName;

    bitmapFile = bm->GetMapName();
    if (bitmapFile.data() == NULL)
        return NULL;
    int l = bitmapFile.Length()-1;
    if (l < 0)
        return NULL;

    // Split the name up
    TSTR path;
    SplitPathFile(bitmapFile, &path, &fileName);

    TSTR url;
    if (mUsePrefix && mUrlPrefix.Length() > 0) {
        if (mUrlPrefix[mUrlPrefix.Length() - 1] != '/') {
            TSTR slash = "/";
            url = mUrlPrefix + slash + fileName;
        } else
            url = mUrlPrefix + fileName;
    }
    else
        url = fileName;
    TextureDesc* td = new TextureDesc(bm, fileName, url);
    return td;
}

// Write out the colors for a multi/sub-object material
void
HSFExp::OutputMultiMtl(Mtl* mtl, int level)
{
    int i;
    Mtl* sub;
    Color c;
    float f;

    Indent(level);
    fprintf(mStream, _T("Material {\n"));
    int num = mtl->NumSubMtls();

    Indent(level+1);
    fprintf(mStream, _T("ambientColor [ "));
    for(i = 0; i < num; i++) {
        sub = mtl->GetSubMtl(i);
        // Some slots might be empty!
        if (!sub)
            continue;
        c = sub->GetAmbient(mStart);
        if (i == num - 1)
            fprintf(mStream, _T("%s "), color(c));
        else
            fprintf(mStream, _T("%s, "), color(c));
    }
    fprintf(mStream, _T("]\n"));
    Indent(level+1);
    fprintf(mStream, _T("diffuseColor [ "));
    for(i = 0; i < num; i++) {
        sub = mtl->GetSubMtl(i);
        if (!sub)
            continue;
        c = sub->GetDiffuse(mStart);
        if (i == num - 1)
            fprintf(mStream, _T("%s "), color(c));
        else
            fprintf(mStream, _T("%s, "), color(c));
    }
    fprintf(mStream, _T("]\n"));
        
    Indent(level+1);
    fprintf(mStream, _T("specularColor [ "));
    for(i = 0; i < num; i++) {
        sub = mtl->GetSubMtl(i);
        if (!sub)
            continue;
        c = sub->GetSpecular(mStart);
        if (i == num - 1)
            fprintf(mStream, _T("%s "), color(c));
        else
            fprintf(mStream, _T("%s, "), color(c));
    }
    fprintf(mStream, _T("]\n"));
    
    Indent(level+1);
    fprintf(mStream, _T("shininess [ "));
    for(i = 0; i < num; i++) {
        sub = mtl->GetSubMtl(i);
        if (!sub)
            continue;
        f = sub->GetShininess(mStart);
        if (i == num - 1)
            fprintf(mStream, _T("%s "), floatVal(f));
        else
            fprintf(mStream, _T("%s, "), floatVal(f));
    }
    fprintf(mStream, _T("]\n"));
        
    Indent(level+1);
    fprintf(mStream, _T("emissiveColor [ "));
    for(i = 0; i < num; i++) {
        sub = mtl->GetSubMtl(i);
        if (!sub)
            continue;
        c = sub->GetDiffuse(mStart);
        float si;
        if (sub->ClassID() == Class_ID(DMTL_CLASS_ID, 0)) {
            StdMat* stdMtl = (StdMat *) sub;
            si = stdMtl->GetSelfIllum(mStart);
        }
        else
            si = 0.0f;
        Point3 p = si * Point3(c.r, c.g, c.b);
        if (i == num - 1)
            fprintf(mStream, _T("%s "), color(p));
        else
            fprintf(mStream, _T("%s, "), color(p));
    }
    fprintf(mStream, _T("]\n"));
        
    Indent(level);
    fprintf(mStream, _T("}\n"));
}

void
HSFExp::OutputNoTexture(int level)
{
    Indent(level);
    fprintf(mStream, _T("Texture2 {}\n"));
}

// Output the matrial definition for a node.
BOOL
HSFExp::OutputMaterial(INode* node, BOOL& twoSided, int level)
{
    Mtl* mtl = node->GetMtl();
    twoSided = FALSE;

    // If no material is assigned, use the wire color
    if (!mtl || (mtl->ClassID() != Class_ID(DMTL_CLASS_ID, 0) &&
                 !mtl->IsMultiMtl())) {
        Color col(node->GetWireColor());
        Indent(level);
        fprintf(mStream, _T("Material {\n"));
        Indent(level+1);
        fprintf(mStream, _T("diffuseColor %s\n"), color(col));
        Indent(level+1);
        fprintf(mStream, _T("specularColor .9 .9 .9\n"));
        Indent(level);
        fprintf(mStream, _T("}\n"));
        OutputNoTexture(level);
        return FALSE;
    }

    if (mtl->IsMultiMtl()) {
        OutputMultiMtl(mtl, level);
        OutputNoTexture(level);
        return TRUE;
    }

    StdMat* sm = (StdMat*) mtl;
    twoSided = sm->GetTwoSided();
    Interval i = FOREVER;
    sm->Update(0, i);
    Indent(level);
    fprintf(mStream, _T("Material {\n"));
    Color c;

    Indent(level+1);
    c = sm->GetAmbient(mStart);
    fprintf(mStream, _T("ambientColor %s\n"), color(c));
    Indent(level+1);
    c = sm->GetDiffuse(mStart);
    fprintf(mStream, _T("diffuseColor %s\n"), color(c));
    Indent(level+1);
    c = sm->GetSpecular(mStart);
    fprintf(mStream, _T("specularColor %s\n"), color(c));
    Indent(level+1);
    fprintf(mStream, _T("shininess %s\n"),
            floatVal(sm->GetShininess(mStart)));
    Indent(level+1);
    fprintf(mStream, _T("transparency %s\n"),
            floatVal(1.0f - sm->GetOpacity(mStart)));
    float si = sm->GetSelfIllum(mStart);
    if (si > 0.0f) {
        Indent(level+1);
        c = sm->GetDiffuse(mStart);
        Point3 p = si * Point3(c.r, c.g, c.b);
        fprintf(mStream, _T("emissiveColor %s\n"), color(p));
    }
    Indent(level);
    fprintf(mStream, _T("}\n"));


    TextureDesc* td = GetMatTex(node);
    if (!td) {
        OutputNoTexture(level);
        return FALSE;
    }

    Indent(level);
    fprintf(mStream, _T("Texture2 {\n"));
    Indent(level+1);
    fprintf(mStream, _T("filename \"%s\"\n"), td->url);
    Indent(level);
    fprintf(mStream, _T("}\n"));

    BitmapTex* bm = td->tex;
    delete td;

    StdUVGen* uvGen = bm->GetUVGen();
    if (!uvGen) {
        return FALSE;
    }

    // Get the UV offset and scale value for Texture2Transform
    float uOff = uvGen->GetUOffs(mStart);
    float vOff = uvGen->GetVOffs(mStart);
    float uScl = uvGen->GetUScl(mStart);
    float vScl = uvGen->GetVScl(mStart);
    float ang =  uvGen->GetAng(mStart);

    if (uOff == 0.0f && vOff == 0.0f && uScl == 1.0f && vScl == 1.0f &&
        ang == 0.0f) {
        return FALSE;
    }

    Indent(level);
    fprintf(mStream, _T("Texture2Transform {\n"));
    if (uOff != 0.0f || vOff != 0.0f) {
        Indent(level+1);
        UVVert p = UVVert(uOff, vOff, 0.0f);
        fprintf(mStream, _T("translation %s\n"), texture(p));
    }
    if (ang != 0.0f) {
        Indent(level+1);
        fprintf(mStream, _T("rotation %s\n"), floatVal(ang));
    }
    if (uScl != 1.0f || vScl != 1.0f) {
        Indent(level+1);
        UVVert p = UVVert(uScl, vScl, 0.0f);
        fprintf(mStream, _T("scaleFactor %s\n"), texture(p));
    }
    Indent(level);
    fprintf(mStream, _T("}\n"));

    return FALSE;
}


// Output an omni light
BOOL
HSFExp::VrblOutPointLight(INode* node, LightObject* light, int level)
{
    LightState ls;
    Interval iv = FOREVER;

    light->EvalLightState(mStart, iv, &ls);

    Indent(level);
    fprintf(mStream, _T("DEF %s PointLight {\n"), mNodes.GetNodeName(node));
    Indent(level+1);
    fprintf(mStream, _T("intensity %s\n"),
            floatVal(light->GetIntensity(mStart, FOREVER)));
    Indent(level+1);
    Point3 col = light->GetRGBColor(mStart, FOREVER);
    fprintf(mStream, _T("color %s\n"), color(col));
    Indent(level+1);
    fprintf(mStream, _T("location 0 0 0\n"));

    Indent(level+1);
    fprintf(mStream, _T("on %s\n"), ls.on ? _T("TRUE") : _T("FALSE"));
    Indent(level);
    fprintf(mStream, _T("}\n"));
    return TRUE;
}

// Output a directional light
BOOL
HSFExp::VrblOutDirectLight(INode* node, LightObject* light, int level)
{
    LightState ls;
    Interval iv = FOREVER;

    light->EvalLightState(mStart, iv, &ls);

    Indent(level);
    fprintf(mStream, _T("DEF %s DirectionalLight {\n"),  mNodes.GetNodeName(node));
    Indent(level+1);
    fprintf(mStream, _T("intensity %s\n"),
            floatVal(light->GetIntensity(mStart, FOREVER)));
    Indent(level+1);
    Point3 col = light->GetRGBColor(mStart, FOREVER);

    fprintf(mStream, _T("color %s\n"), color(col));

    Indent(level+1);
    fprintf(mStream, _T("on %s\n"), ls.on ? _T("TRUE") : _T("FALSE"));
    Indent(level);
    fprintf(mStream, _T("}\n"));
    return TRUE;
}

// Output a Spot Light
BOOL
HSFExp::VrblOutSpotLight(INode* node, LightObject* light, int level)
{
    LightState ls;
    Interval iv = FOREVER;

    Point3 dir(0,0,-1);
    light->EvalLightState(mStart, iv, &ls);
    Indent(level);
    fprintf(mStream, _T("DEF %s SpotLight {\n"),  mNodes.GetNodeName(node));
    Indent(level+1);
    fprintf(mStream, _T("intensity %s\n"),
            floatVal(light->GetIntensity(mStart,FOREVER)));
    Indent(level+1);
    Point3 col = light->GetRGBColor(mStart, FOREVER);
    fprintf(mStream, _T("color %s\n"), color(col));
    Indent(level+1);
    fprintf(mStream, _T("location 0 0 0\n"));
    Indent(level+1);
    fprintf(mStream, _T("direction %s\n"), normPoint(dir));
    Indent(level+1);
    fprintf(mStream, _T("cutOffAngle %s\n"),
            floatVal(DegToRad(ls.fallsize)));
    Indent(level+1);
    fprintf(mStream, _T("dropOffRate %s\n"),
            floatVal(1.0f - ls.hotsize/ls.fallsize));
    Indent(level+1);
    fprintf(mStream, _T("on %s\n"), ls.on ? _T("TRUE") : _T("FALSE"));
    Indent(level);
    fprintf(mStream, _T("}\n"));
    return TRUE;
}

// Output an omni light at the top-level Separator
BOOL
HSFExp::VrblOutTopPointLight(INode* node, LightObject* light)
{
    LightState ls;
    Interval iv = FOREVER;

    light->EvalLightState(mStart, iv, &ls);

    Indent(1);
    fprintf(mStream, _T("DEF %s PointLight {\n"),  mNodes.GetNodeName(node));
    Indent(2);
    fprintf(mStream, _T("intensity %s\n"),
            floatVal(light->GetIntensity(mStart, FOREVER)));
    Indent(2);
    Point3 col = light->GetRGBColor(mStart, FOREVER);
    fprintf(mStream, _T("color %s\n"), color(col));
    Indent(2);
    Point3 p = node->GetObjTMAfterWSM(mStart).GetTrans();
    fprintf(mStream, _T("location %s\n"), point(p));

    Indent(2);
    fprintf(mStream, _T("on %s\n"), ls.on ? _T("TRUE") : _T("FALSE"));
    Indent(1);
    fprintf(mStream, _T("}\n"));
    return TRUE;
}

// Output a directional light at the top-level Separator
BOOL
HSFExp::VrblOutTopDirectLight(INode* node, LightObject* light)
{
    LightState ls;
    Interval iv = FOREVER;

    light->EvalLightState(mStart, iv, &ls);

    Indent(1);
    fprintf(mStream, _T("DEF %s DirectionalLight {\n"),  mNodes.GetNodeName(node));
    Indent(2);
    fprintf(mStream, _T("intensity %s\n"),
            floatVal(light->GetIntensity(mStart, FOREVER)));
    Indent(2);
    Point3 col = light->GetRGBColor(mStart, FOREVER);
    fprintf(mStream, _T("color %s\n"), color(col));
    Point3 p = Point3(0,0,-1);

    Matrix3 tm = node->GetObjTMAfterWSM(mStart);
    Point3 trans, s;
    Quat q;
    AffineParts parts;
    decomp_affine(tm, &parts);
    q = parts.q;
    Matrix3 rot;
    q.MakeMatrix(rot);
    p = p * rot;
    
    Indent(2);
    fprintf(mStream, _T("direction %s\n"), normPoint(p));
    Indent(2);
    fprintf(mStream, _T("on %s\n"), ls.on ? _T("TRUE") : _T("FALSE"));
    Indent(1);
    fprintf(mStream, _T("}\n"));
    return TRUE;
}

// Output a spot light at the top-level Separator
BOOL
HSFExp::VrblOutTopSpotLight(INode* node, LightObject* light)
{
    LightState ls;
    Interval iv = FOREVER;

    light->EvalLightState(mStart, iv, &ls);
    Indent(1);
    fprintf(mStream, _T("DEF %s SpotLight {\n"),  mNodes.GetNodeName(node));
    Indent(2);
    fprintf(mStream, _T("intensity %s\n"),
            floatVal(light->GetIntensity(mStart,FOREVER)));
    Indent(2);
    Point3 col = light->GetRGBColor(mStart, FOREVER);
    fprintf(mStream, _T("color %s\n"), color(col));
    Indent(2);
    Point3 p = node->GetObjTMAfterWSM(mStart).GetTrans();
    fprintf(mStream, _T("location %s\n"), point(p));

    Matrix3 tm = node->GetObjTMAfterWSM(mStart);
    p = Point3(0,0,-1);
    Point3 trans, s;
    Quat q;
    AffineParts parts;
    decomp_affine(tm, &parts);
    q = parts.q;
    Matrix3 rot;
    q.MakeMatrix(rot);
    p = p * rot;

    Indent(2);
    fprintf(mStream, _T("direction %s\n"), normPoint(p));
    Indent(2);
    fprintf(mStream, _T("cutOffAngle %s\n"),
            floatVal( DegToRad(ls.fallsize)));
    Indent(2);
    fprintf(mStream, _T("dropOffRate %s\n"),
            floatVal(1.0f - ls.hotsize/ls.fallsize));
    Indent(2);
    fprintf(mStream, _T("on %s\n"), ls.on ? _T("TRUE") : _T("FALSE"));
    Indent(1);
    fprintf(mStream, _T("}\n"));
    return TRUE;
}

// Create a light at the top-level of the file
void
HSFExp::OutputTopLevelLight(INode* node, LightObject *light)
{
    Class_ID id = light->ClassID();
    if (id == Class_ID(OMNI_LIGHT_CLASS_ID, 0))
        VrblOutTopPointLight(node, light);
    else if (id == Class_ID(DIR_LIGHT_CLASS_ID, 0))
        VrblOutTopDirectLight(node, light);
    else if (id == Class_ID(SPOT_LIGHT_CLASS_ID, 0) ||
             id == Class_ID(FSPOT_LIGHT_CLASS_ID, 0))
        VrblOutTopSpotLight(node, light);
    
}

// Write out the VRML for nodes we know about, including VRML helper nodes, 
// lights, cameras and VRML primitives
BOOL
HSFExp::VrblOutSpecial(INode* node, INode* parent,
                             Object* obj, int level)
{
    Class_ID id = obj->ClassID();

    if (id == Class_ID(OMNI_LIGHT_CLASS_ID, 0))
        return VrblOutPointLight(node, (LightObject*) obj, level+1);

    if (id == Class_ID(DIR_LIGHT_CLASS_ID, 0))
        return VrblOutDirectLight(node, (LightObject*) obj, level+1);

    if (id == Class_ID(SPOT_LIGHT_CLASS_ID, 0) ||
        id == Class_ID(FSPOT_LIGHT_CLASS_ID, 0))
        return VrblOutSpotLight(node, (LightObject*) obj, level+1);

    return FALSE;
}


// Returns TRUE iff an object or one of its ancestors in animated
static BOOL
IsEverAnimated(INode* node)
{
 // need to sample transform
    Class_ID id = node->EvalWorldState(0).obj->ClassID();
    if (id == Class_ID(SIMPLE_CAM_CLASS_ID, 0) ||
        id == Class_ID(LOOKAT_CAM_CLASS_ID, 0)) return TRUE;

    for (; !node->IsRootNode(); node = node->GetParentNode())
        if (node->IsAnimated())
            return TRUE;
    return FALSE;
}*/

// Returns TRUE for object that we want a VRML node to occur
// in the file.  
/*BOOL
HSFExp::isVrblObject(INode * node, Object *obj, INode* parent)
{
    if (!obj)
        return FALSE;

    Class_ID id = obj->ClassID();
    // Mr Blue nodes only 1st class if stand-alone

    // only animated light come out in scene graph
    if (IsLight(node) ||
        (id == Class_ID(SIMPLE_CAM_CLASS_ID, 0) ||
         id == Class_ID(LOOKAT_CAM_CLASS_ID, 0)))
        return IsEverAnimated(node);

    return (obj->IsRenderable() ||
            node->NumberOfChildren() > 0 //||
            ) &&
            (mExportHidden || !node->IsHidden());        
}

// Write the VRML for a single object.
void
HSFExp::VrblOutObject(INode* node, INode* parent, Object* obj, int level)
{
    BOOL isTriMesh = obj->CanConvertToType(triObjectClassID);
        
    BOOL multiMat = FALSE, twoSided = FALSE;
    // Output the material
    if (obj->IsRenderable())
        multiMat = OutputMaterial(node, twoSided, level+1);

    // First check for VRML primitives and other special objects
    if (VrblOutSpecial(node, parent, obj, level)) {
        return;
    }

    // Otherwise output as a triangle mesh
    if (isTriMesh) {
        TriObject *tri = (TriObject *)obj->ConvertToType(0, triObjectClassID);
        OutputTriObject(node, tri, multiMat, twoSided, level+1);
        if(obj != (Object *)tri)
            tri->DeleteThis();
    }
}

BOOL
HSFExp::IsLight(INode* node)
{
    Object* obj = node->EvalWorldState(mStart).obj;
    if (!obj)
        return FALSE;

    SClass_ID sid = obj->SuperClassID();
    return sid == LIGHT_CLASS_ID;
}*/

// From dllmain.cpp
extern HINSTANCE hInstance;


// Dialog procedures

// Get a chunk of app data off the sound object
void
GetAppData(Interface * ip, int id, TCHAR* def, TCHAR* val, int len)
{
    SoundObj *node = ip->GetSoundObject();
	AppDataChunk *ad = node->GetAppDataChunk(HSFEXP_CLASS_ID,
                                             SCENE_EXPORT_CLASS_ID, id);
    if (!ad)
        _tcscpy(val, def);
    else
        _tcscpy(val, (TCHAR*) ad->data);
}

// Write a chunk of app data on the sound object
void
WriteAppData(Interface* ip, int id, TCHAR* val)
{
    SoundObj *node = ip->GetSoundObject();
    node->RemoveAppDataChunk(HSFEXP_CLASS_ID,
                             SCENE_EXPORT_CLASS_ID, id);
	int size = static_cast<int>((_tcslen(val)+1) * sizeof(TCHAR));
    TCHAR* buf = (TCHAR*) MAX_malloc(size);
    _tcscpy(buf, val);
    node->AddAppDataChunk(HSFEXP_CLASS_ID,
                          SCENE_EXPORT_CLASS_ID, id,
                          size, buf);
    SetSaveRequiredFlag(TRUE);
}

extern HINSTANCE hInstance;

ISpinnerControl* HSFExp::tformSpin = NULL;
ISpinnerControl* HSFExp::coordSpin = NULL;
ISpinnerControl* HSFExp::flipbookSpin = NULL;


static INT_PTR CALLBACK
SampleRatesDlgProc(HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam) 
{
    TCHAR text[MAX_PATH];
    HSFExp *exp;
    if (msg == WM_INITDIALOG) {
        DLSetWindowLongPtr(hDlg, lParam);
    }
    exp = DLGetWindowLongPtr<HSFExp *>(hDlg);
    switch (msg) {
    case WM_INITDIALOG: {
        CenterWindow(hDlg, GetParent(hDlg));
     // transform sample rate
        GetAppData(exp->mIp, TFORM_SAMPLE_ID, _T("custom"), text, MAX_PATH);
        BOOL once = _tcscmp(text, _T("once")) == 0;
        CheckDlgButton(hDlg, IDC_TFORM_ONCE, once);
        CheckDlgButton(hDlg, IDC_TFORM_CUSTOM, !once);
        EnableWindow(GetDlgItem(hDlg, IDC_TFORM_EDIT), !once);
        EnableWindow(GetDlgItem(hDlg, IDC_TFORM_SPIN), !once);
        
        GetAppData(exp->mIp, TFORM_SAMPLE_RATE_ID, _T("10"), text, MAX_PATH);
        int sampleRate = atoi(text);

        exp->tformSpin = GetISpinner(GetDlgItem(hDlg, IDC_TFORM_SPIN));
        exp->tformSpin->SetLimits(1, 100);
        exp->tformSpin->SetValue(sampleRate, FALSE);
        exp->tformSpin->SetAutoScale();
        exp->tformSpin->LinkToEdit(GetDlgItem(hDlg, IDC_TFORM_EDIT), EDITTYPE_INT);

     // coordinate interpolator sample rate
        GetAppData(exp->mIp, COORD_SAMPLE_ID, _T("custom"), text, MAX_PATH);
        once = _tcscmp(text, _T("once")) == 0;
        CheckDlgButton(hDlg, IDC_COORD_ONCE, once);
        CheckDlgButton(hDlg, IDC_COORD_CUSTOM, !once);
        EnableWindow(GetDlgItem(hDlg, IDC_COORD_EDIT), !once);
        EnableWindow(GetDlgItem(hDlg, IDC_COORD_SPIN), !once);
        
        GetAppData(exp->mIp, COORD_SAMPLE_RATE_ID, _T("3"), text, MAX_PATH);
        sampleRate = atoi(text);

        exp->coordSpin = GetISpinner(GetDlgItem(hDlg, IDC_COORD_SPIN));
        exp->coordSpin->SetLimits(1, 100);
        exp->coordSpin->SetValue(sampleRate, FALSE);
        exp->coordSpin->SetAutoScale();
        exp->coordSpin->LinkToEdit(GetDlgItem(hDlg, IDC_COORD_EDIT), EDITTYPE_INT);

     // flipbook sample rate
        GetAppData(exp->mIp, FLIPBOOK_SAMPLE_ID, _T("custom"), text, MAX_PATH);
        once = _tcscmp(text, _T("once")) == 0;
        CheckDlgButton(hDlg, IDC_FLIPBOOK_ONCE, once);
        CheckDlgButton(hDlg, IDC_FLIPBOOK_CUSTOM, !once);
        EnableWindow(GetDlgItem(hDlg, IDC_FLIPBOOK_EDIT), !once);
        EnableWindow(GetDlgItem(hDlg, IDC_FLIPBOOK_SPIN), !once);
        
        GetAppData(exp->mIp, FLIPBOOK_SAMPLE_RATE_ID, _T("10"), text, MAX_PATH);
        sampleRate = atoi(text);

        exp->flipbookSpin = GetISpinner(GetDlgItem(hDlg, IDC_FLIPBOOK_SPIN));
        exp->flipbookSpin->SetLimits(1, 100);
        exp->flipbookSpin->SetValue(sampleRate, FALSE);
        exp->flipbookSpin->SetAutoScale();
        exp->flipbookSpin->LinkToEdit(GetDlgItem(hDlg, IDC_FLIPBOOK_EDIT), EDITTYPE_INT);

        return TRUE;
    }
    case WM_DESTROY:
        ReleaseISpinner(exp->tformSpin);
        ReleaseISpinner(exp->coordSpin);
        ReleaseISpinner(exp->flipbookSpin);
        break;
    case WM_COMMAND:
        switch(LOWORD(wParam)) {
        case IDC_TFORM_ONCE:
            exp->tformSpin->Disable();
            return TRUE;
        case IDC_TFORM_CUSTOM:
            exp->tformSpin->Enable();
            return TRUE;
        case IDC_COORD_ONCE:
            exp->coordSpin->Disable();
            return TRUE;
        case IDC_COORD_CUSTOM:
            exp->coordSpin->Enable();
            return TRUE;
        case IDC_FLIPBOOK_ONCE:
            exp->flipbookSpin->Disable();
            return TRUE;
        case IDC_FLIPBOOK_CUSTOM:
            exp->flipbookSpin->Enable();
            return TRUE;
        case IDCANCEL:
            EndDialog(hDlg, FALSE);
            return TRUE;
            break;
        case IDOK: {
			assert (FALSE && "TODO");
            /*BOOL once = IsDlgButtonChecked(hDlg, IDC_TFORM_ONCE);
            exp->SetTformSample(once);
            TCHAR* val = once ? _T("once") : _T("custom");
            WriteAppData(exp->mIp, TFORM_SAMPLE_ID, val);
            int rate = exp->tformSpin->GetIVal();
            exp->SetTformSampleRate(rate);
            sprintf(text, _T("%d"), rate);
            WriteAppData(exp->mIp, TFORM_SAMPLE_RATE_ID, text);

            once = IsDlgButtonChecked(hDlg, IDC_COORD_ONCE);
            exp->SetCoordSample(once);
            val = once ? _T("once") : _T("custom");
            WriteAppData(exp->mIp, COORD_SAMPLE_ID, val);
            rate = exp->coordSpin->GetIVal();
            exp->SetCoordSampleRate(rate);
            sprintf(text, _T("%d"), rate);
            WriteAppData(exp->mIp, COORD_SAMPLE_RATE_ID, text);
            
            once = IsDlgButtonChecked(hDlg, IDC_FLIPBOOK_ONCE);
            exp->SetFlipbookSample(once);
            val = once ? _T("once") : _T("custom");
            WriteAppData(exp->mIp, FLIPBOOK_SAMPLE_ID, val);
            rate = exp->flipbookSpin->GetIVal();
            exp->SetFlipbookSampleRate(rate);
            sprintf(text, _T("%d"), rate);
            WriteAppData(exp->mIp, FLIPBOOK_SAMPLE_RATE_ID, text);*/

            EndDialog(hDlg, TRUE);
            return TRUE;
        }
        }
    }
    return FALSE;
}

static INT_PTR CALLBACK
WorldInfoDlgProc(HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam) 
{
    TCHAR text[MAX_PATH];
    HSFExp *exp;
    if (msg == WM_INITDIALOG) {
        DLSetWindowLongPtr(hDlg, lParam);
    }
    exp = DLGetWindowLongPtr<HSFExp *>(hDlg);
    switch (msg) {
    case WM_INITDIALOG: {
        CenterWindow(hDlg, GetParent(hDlg));
        GetAppData(exp->mIp, TITLE_ID, _T(""), text, MAX_PATH);
        Edit_SetText(GetDlgItem(hDlg, IDC_TITLE), text);
        GetAppData(exp->mIp, INFO_ID, _T(""), text, MAX_PATH);
        Edit_SetText(GetDlgItem(hDlg, IDC_INFO), text);
        return TRUE;
    }
    case WM_COMMAND:
        switch(LOWORD(wParam)) {
        case IDCANCEL:
            EndDialog(hDlg, FALSE);
            return TRUE;
        case IDOK:
            Edit_GetText(GetDlgItem(hDlg, IDC_TITLE), text, MAX_PATH);
            WriteAppData(exp->mIp, TITLE_ID, text);
            Edit_GetText(GetDlgItem(hDlg, IDC_INFO), text, MAX_PATH);
            WriteAppData(exp->mIp, INFO_ID, text);
            EndDialog(hDlg, TRUE);
            return TRUE;
        }
    }
    return FALSE;
}

static BOOL CALLBACK
AboutDlgProc(HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam) 
{
    switch (msg) {
    case WM_INITDIALOG: {
        CenterWindow(hDlg, GetParent(hDlg));
        return TRUE;
    }
    case WM_COMMAND:
        switch(LOWORD(wParam)) {
        case IDOK:
            EndDialog(hDlg, TRUE);
            return TRUE;
        }
    }
    return FALSE;
}

// Dialog procedure for the export dialog.
static INT_PTR CALLBACK
VrblExportDlgProc(HWND hDlg, UINT msg, WPARAM wParam, LPARAM lParam) 
{
    TCHAR text[MAX_PATH];
    HSFExp *exp;
    if (msg == WM_INITDIALOG) {
        DLSetWindowLongPtr(hDlg, lParam);
    }
    exp = DLGetWindowLongPtr<HSFExp *>(hDlg);
    switch (msg) {
    case WM_INITDIALOG: {
        CenterWindow(hDlg, GetParent(hDlg));
        GetAppData(exp->mIp, NORMALS_ID, _T("no"), text, MAX_PATH);
        BOOL gen = _tcscmp(text, "yes") == 0;
        CheckDlgButton(hDlg, IDC_GENNORMALS, gen);
        GetAppData(exp->mIp, INDENT_ID, _T("yes"), text, MAX_PATH);
        gen = _tcscmp(text, "yes") == 0;
        CheckDlgButton(hDlg, IDC_INDENT, gen);
        GetAppData(exp->mIp, FIELDS_ID, _T("yes"), text, MAX_PATH);
        gen = _tcscmp(text, "yes") == 0;
        //CheckDlgButton(hDlg, IDC_GEN_FIELDS, gen);
        GetAppData(exp->mIp, UPDIR_ID, _T("Y"), text, MAX_PATH);
        gen = _tcscmp(text, "Z") == 0;
        //CheckDlgButton(hDlg, IDC_Z_UP, gen);
        //CheckDlgButton(hDlg, IDC_Y_UP, !gen);
        GetAppData(exp->mIp, COORD_INTERP_ID, _T("no"), text, MAX_PATH);
        gen = _tcscmp(text, "yes") == 0;
        CheckDlgButton(hDlg, IDC_COORD_INTERP, gen);
        GetAppData(exp->mIp, EXPORT_HIDDEN_ID, _T("no"), text, MAX_PATH);
        gen = _tcscmp(text, "yes") == 0;
        CheckDlgButton(hDlg, IDC_EXPORT_HIDDEN, gen);
        GetAppData(exp->mIp, ENABLE_PROGRESS_BAR_ID, _T("yes"), text, MAX_PATH);
        gen = _tcscmp(text, "yes") == 0;
        CheckDlgButton(hDlg, IDC_ENABLE_PROGRESS_BAR, gen);

        GetAppData(exp->mIp, PRIMITIVES_ID, _T("yes"), text, MAX_PATH);
        gen = _tcscmp(text, "yes") == 0;
        CheckDlgButton(hDlg, IDC_PRIM, gen);

        GetAppData(exp->mIp, EXPORT_PRE_LIGHT_ID, _T("no"), text, MAX_PATH);
        gen = _tcscmp(text, "yes") == 0;
        CheckDlgButton(hDlg, IDC_COLOR_PER_VERTEX, gen);
        EnableWindow(GetDlgItem(hDlg, IDC_CPV_CALC), gen);
        EnableWindow(GetDlgItem(hDlg, IDC_CPV_MAX),  gen);

        GetAppData(exp->mIp, CPV_SOURCE_ID, _T("max"), text, MAX_PATH);
        gen = _tcscmp(text, "max") == 0;
        CheckDlgButton(hDlg, IDC_CPV_MAX, gen);
        CheckDlgButton(hDlg, IDC_CPV_CALC, !gen);

#ifdef _LEC_
        GetAppData(exp->mIp, FLIP_BOOK_ID, _T("no"), text, MAX_PATH);
        gen = _tcscmp(text, "yes") == 0;
        CheckDlgButton(hDlg, IDC_FLIP_BOOK, gen);
#endif

        EnableWindow(GetDlgItem(hDlg, IDC_FLIP_BOOK),   TRUE);

		//ComboBox_SelectString(cb, 0, text);
        GetAppData(exp->mIp, USE_PREFIX_ID, _T("yes"), text, MAX_PATH);
        CheckDlgButton(hDlg, IDC_USE_PREFIX, _tcscmp(text, _T("yes")) == 0);
        GetAppData(exp->mIp, URL_PREFIX_ID, _T("../maps"), text, MAX_PATH);
        Edit_SetText(GetDlgItem(hDlg, IDC_URL_PREFIX), text);
        HWND cb = GetDlgItem(hDlg,IDC_DIGITS);
        ComboBox_AddString(cb, _T("3"));
        ComboBox_AddString(cb, _T("4"));
        ComboBox_AddString(cb, _T("5"));
        ComboBox_AddString(cb, _T("6"));
        GetAppData(exp->mIp, DIGITS_ID, _T("4"), text, MAX_PATH);
        ComboBox_SelectString(cb, 0, text);

        cb = GetDlgItem(hDlg, IDC_POLYGON_TYPE);
        ComboBox_AddString(cb, _T(GetString(IDS_OUT_TRIANGLES)));
        GetAppData(exp->mIp, POLYGON_TYPE_ID, _T(GetString(IDS_OUT_TRIANGLES)), text, MAX_PATH);
        ComboBox_SelectString(cb, 0, text);

     // make sure the appropriate things are enabled
        /* this is not always appropriate
        BOOL checked = IsDlgButtonChecked(hDlg, IDC_PRIM);
        EnableWindow(GetDlgItem(hDlg, IDC_COLOR_PER_VERTEX), !checked);
        if (checked) CheckDlgButton(hDlg, IDC_COLOR_PER_VERTEX, FALSE);
        BOOL cpvChecked = IsDlgButtonChecked(hDlg, IDC_COLOR_PER_VERTEX);
        EnableWindow(GetDlgItem(hDlg, IDC_CPV_CALC), cpvChecked);
        EnableWindow(GetDlgItem(hDlg, IDC_CPV_MAX),  cpvChecked);
        EnableWindow(GetDlgItem(hDlg, IDC_GENNORMALS), !checked);
        if (checked) CheckDlgButton(hDlg, IDC_GENNORMALS, FALSE);
        EnableWindow(GetDlgItem(hDlg, IDC_COORD_INTERP), !checked);
        if (checked) CheckDlgButton(hDlg, IDC_COORD_INTERP, FALSE);
        */

        return TRUE; }
    case WM_COMMAND:
        switch(LOWORD(wParam)) {
        case IDC_EXP_HELP: {
            const TCHAR* helpDir = exp->mIp->GetDir(APP_HELP_DIR);
            TCHAR helpFile[MAX_PATH];
            _tcscpy(helpFile, helpDir);
            _tcscat(helpFile, _T("\\vrmlout.hlp"));
            WinHelp(hDlg, helpFile, HELP_CONTENTS, NULL);
            break; }
            /*
        case IDC_PRIM: {
            BOOL checked = IsDlgButtonChecked(hDlg, IDC_PRIM);

            EnableWindow(GetDlgItem(hDlg, IDC_COLOR_PER_VERTEX), !checked);
            if (checked) CheckDlgButton(hDlg, IDC_COLOR_PER_VERTEX, FALSE);
            BOOL cpvChecked = IsDlgButtonChecked(hDlg, IDC_COLOR_PER_VERTEX);
            EnableWindow(GetDlgItem(hDlg, IDC_CPV_CALC), cpvChecked);
            EnableWindow(GetDlgItem(hDlg, IDC_CPV_MAX),  cpvChecked);

            EnableWindow(GetDlgItem(hDlg, IDC_GENNORMALS), !checked);
            if (checked) CheckDlgButton(hDlg, IDC_GENNORMALS, FALSE);

            EnableWindow(GetDlgItem(hDlg, IDC_COORD_INTERP), !checked);
            if (checked) CheckDlgButton(hDlg, IDC_COORD_INTERP, FALSE);

            break;
            }
            */
        case IDC_COLOR_PER_VERTEX: {
            BOOL checked = IsDlgButtonChecked(hDlg, IDC_COLOR_PER_VERTEX);
            EnableWindow(GetDlgItem(hDlg, IDC_CPV_CALC), checked);
            EnableWindow(GetDlgItem(hDlg, IDC_CPV_MAX),  checked);
            break;
            }
        case IDCANCEL:
            EndDialog(hDlg, FALSE);
            break;
        case IDOK: {
            /*exp->SetGenNormals(IsDlgButtonChecked(hDlg, IDC_GENNORMALS));
            WriteAppData(exp->mIp, NORMALS_ID, exp->GetGenNormals() ?
                         _T("yes"): _T("no"));
            
            exp->SetIndent(IsDlgButtonChecked(hDlg, IDC_INDENT));
            WriteAppData(exp->mIp, INDENT_ID, exp->GetIndent() ? _T("yes"):
                         _T("no"));
#if 0            
            exp->SetZUp(IsDlgButtonChecked(hDlg, IDC_Z_UP));
#else
            exp->SetZUp(FALSE);
#endif
            WriteAppData(exp->mIp, UPDIR_ID, exp->GetZUp() ? _T("Z"):
                         _T("Y"));

            exp->SetCoordInterp(IsDlgButtonChecked(hDlg, IDC_COORD_INTERP));
            WriteAppData(exp->mIp, COORD_INTERP_ID, exp->GetCoordInterp() ?
                         _T("yes"): _T("no"));
#ifdef _LEC_
            exp->SetFlipBook(IsDlgButtonChecked(hDlg, IDC_FLIP_BOOK));
            WriteAppData(exp->mIp, FLIP_BOOK_ID, exp->GetFlipBook() ? _T("yes"): _T("no"));
#endif

            exp->SetExportHidden(IsDlgButtonChecked(hDlg, IDC_EXPORT_HIDDEN));
            WriteAppData(exp->mIp, EXPORT_HIDDEN_ID, exp->GetExportHidden() ?
                         _T("yes"): _T("no"));

            exp->SetEnableProgressBar(IsDlgButtonChecked(hDlg, IDC_ENABLE_PROGRESS_BAR));
            WriteAppData(exp->mIp, ENABLE_PROGRESS_BAR_ID, exp->GetEnableProgressBar() ?
                         _T("yes"): _T("no"));

            exp->SetPrimitives(IsDlgButtonChecked(hDlg, IDC_PRIM));
            WriteAppData(exp->mIp, PRIMITIVES_ID, exp->GetPrimitives() ?
                         _T("yes"): _T("no"));

            int index = SendMessage(GetDlgItem(hDlg,IDC_CAMERA_COMBO),
                                    CB_GETCURSEL, 0, 0);
            if (index != CB_ERR) {
                exp->SetCamera((INode *)
                               SendMessage(GetDlgItem(hDlg, IDC_CAMERA_COMBO),
                                           CB_GETITEMDATA, (WPARAM)index,
                                           0));
                ComboBox_GetText(GetDlgItem(hDlg, IDC_CAMERA_COMBO),
                                 text, MAX_PATH);
                WriteAppData(exp->mIp, CAMERA_ID, text);
            } else
                exp->SetCamera(NULL);

            index = SendMessage(GetDlgItem(hDlg,IDC_NAV_INFO_COMBO),
                                CB_GETCURSEL, 0, 0);
            if (index != CB_ERR) {
                exp->SetNavInfo((INode *)
                      SendMessage(GetDlgItem(hDlg, IDC_NAV_INFO_COMBO),
                                  CB_GETITEMDATA, (WPARAM)index,
                                  0));
                ComboBox_GetText(GetDlgItem(hDlg, IDC_NAV_INFO_COMBO),
                                 text, MAX_PATH);
                WriteAppData(exp->mIp, NAV_INFO_ID, text);
            } else
                exp->SetNavInfo(NULL);

            index = SendMessage(GetDlgItem(hDlg,IDC_BACKGROUND_COMBO),
                                CB_GETCURSEL, 0, 0);
            if (index != CB_ERR) {
                exp->SetBackground((INode *)
                      SendMessage(GetDlgItem(hDlg, IDC_BACKGROUND_COMBO),
                                  CB_GETITEMDATA, (WPARAM)index,
                                  0));
                ComboBox_GetText(GetDlgItem(hDlg, IDC_BACKGROUND_COMBO),
                                 text, MAX_PATH);
                WriteAppData(exp->mIp, BACKGROUND_ID, text);
            } else
                exp->SetBackground(NULL);

            index = SendMessage(GetDlgItem(hDlg,IDC_FOG_COMBO),
                                CB_GETCURSEL, 0, 0);
            if (index != CB_ERR) {
                exp->SetFog((INode *)
                      SendMessage(GetDlgItem(hDlg, IDC_FOG_COMBO),
                                  CB_GETITEMDATA, (WPARAM)index,
                                  0));
                ComboBox_GetText(GetDlgItem(hDlg, IDC_FOG_COMBO),
                                 text, MAX_PATH);
                WriteAppData(exp->mIp, FOG_ID, text);
            } else
                exp->SetFog(NULL);

            ComboBox_GetText(GetDlgItem(hDlg, IDC_POLYGON_TYPE), text, MAX_PATH);
            WriteAppData(exp->mIp, POLYGON_TYPE_ID, text);
         // some following strings moved to resources, 010809  --prs.
            if (_tcscmp(text, _T(GetString(IDS_VISIBLE_EDGES))) == 0)
                exp->SetPolygonType(OUTPUT_VISIBLE_EDGES);
            else if (_tcscmp(text, _T(GetString(IDS_NGONS))) == 0)
                exp->SetPolygonType(OUTPUT_NGONS);
            else if (_tcscmp(text, _T(GetString(IDS_QUADS))) == 0)
                exp->SetPolygonType(OUTPUT_QUADS);
            else
                exp->SetPolygonType(OUTPUT_TRIANGLES);

            exp->SetPreLight(IsDlgButtonChecked(hDlg, IDC_COLOR_PER_VERTEX));
            WriteAppData(exp->mIp, EXPORT_PRE_LIGHT_ID, exp->GetPreLight() ?
                         _T("yes"): _T("no"));

            exp->SetCPVSource(IsDlgButtonChecked(hDlg, IDC_CPV_MAX));
            WriteAppData(exp->mIp, CPV_SOURCE_ID, exp->GetCPVSource() ?
                         _T("max"): _T("calc"));

            exp->SetUsePrefix(IsDlgButtonChecked(hDlg, IDC_USE_PREFIX));
            WriteAppData(exp->mIp, USE_PREFIX_ID, exp->GetUsePrefix()
                         ? _T("yes") : _T("no"));
            Edit_GetText(GetDlgItem(hDlg, IDC_URL_PREFIX), text, MAX_PATH);
            TSTR prefix = text;
            exp->SetUrlPrefix(prefix);
            WriteAppData(exp->mIp, URL_PREFIX_ID, exp->GetUrlPrefix());
            ComboBox_GetText(GetDlgItem(hDlg, IDC_DIGITS), text, MAX_PATH);
            exp->SetDigits(atoi(text));
            WriteAppData(exp->mIp, DIGITS_ID, text);

            GetAppData(exp->mIp, TFORM_SAMPLE_ID, _T("custom"), text,
                       MAX_PATH);
            BOOL once = _tcscmp(text, _T("once")) == 0;
            exp->SetTformSample(once);
            GetAppData(exp->mIp, TFORM_SAMPLE_RATE_ID, _T("10"), text,
                       MAX_PATH);
            int sampleRate = atoi(text);
            exp->SetTformSampleRate(sampleRate);

            GetAppData(exp->mIp, COORD_SAMPLE_ID, _T("custom"), text,
                       MAX_PATH);
            once = _tcscmp(text, _T("once")) == 0;
            exp->SetCoordSample(once);
            GetAppData(exp->mIp, COORD_SAMPLE_RATE_ID, _T("3"), text,
                       MAX_PATH);
            sampleRate = atoi(text);
            exp->SetCoordSampleRate(sampleRate);

            GetAppData(exp->mIp, FLIPBOOK_SAMPLE_ID, _T("custom"), text,
                       MAX_PATH);
            once = _tcscmp(text, _T("once")) == 0;
            exp->SetFlipbookSample(once);
            GetAppData(exp->mIp, FLIPBOOK_SAMPLE_RATE_ID, _T("10"), text,
                       MAX_PATH);
            sampleRate = atoi(text);
            exp->SetFlipbookSampleRate(sampleRate);

            GetAppData(exp->mIp, TITLE_ID, _T(""), text, MAX_PATH);
            exp->SetTitle(text);
            GetAppData(exp->mIp, INFO_ID, _T(""), text, MAX_PATH);
            exp->SetInfo(text);*/
            EndDialog(hDlg, TRUE);
            break; }
        case IDC_SAMPLE_RATES:
            DialogBoxParam(hInstance, MAKEINTRESOURCE(IDD_SAMPLE_RATES), 
                           GetActiveWindow(), SampleRatesDlgProc,
                           (LPARAM) exp);
            break;
        case IDC_WORLD_INFO:
            DialogBoxParam(hInstance, MAKEINTRESOURCE(IDD_WORLD_INFO), 
                           GetActiveWindow(), WorldInfoDlgProc,
                           (LPARAM) exp);
            break;
        }
        break;
    case WM_SYSCOMMAND:
        if ((wParam & 0xfff0) == SC_CONTEXTHELP)
            DoHelp(HELP_CONTEXT, idh_3dsexp_export);
        break;
    }
    return FALSE;
}

// Export the current scene as VRML
int
HSFExp::DoExport(const TCHAR *filename, ExpInterface *ei, Interface *i, BOOL suppressPrompts, DWORD options) 
{
    mIp = i;
    mStart = mIp->GetAnimRange().Start();

    /*if (suppressPrompts)
        initializeDefaults();
    else if (!DialogBoxParam(hInstance, MAKEINTRESOURCE(IDD_VRBLEXP), 
                        GetActiveWindow(), VrblExportDlgProc,
                        (LPARAM) this))
        return IMPEXP_CANCEL;*/
   
        //if (this->GetFlipBook()) {
            int sampleRate;
            int end;
            int lastFrame;
            int numFrames;

            /*if (this->GetFlipbookSample())
                sampleRate = GetTicksPerFrame();
            else
                sampleRate = TIME_TICKSPERSEC / this->GetFlipbookSampleRate();*/

            mStart      = i->GetAnimRange().Start();
            /*lastFrame   = end = i->GetAnimRange().End();
            numFrames   = (end - mStart) / sampleRate + 1;

            if (((end - mStart) % sampleRate) != 0) {
                end += sampleRate;
                numFrames++;
            }*/

			CStr wName(filename); {
				int extLoc = wName.last('.');
				if (extLoc != -1)
					wName.remove(extLoc);
				wName.Append(".hsf");
			}

			{
				SplitPathFile(wName, &mExportDir, &mExportName);

				int extLoc = mExportName.last('.');
				if (extLoc != -1)
					mExportName.remove(extLoc);
			}

			// ----------------------------------------------------------------

			WorkFile theFile(wName.data(), _T("w"));
			mStream = theFile.MStream();
			if (!mStream) {
				TCHAR msg[MAX_PATH];
				TCHAR title[MAX_PATH];
				LoadString(hInstance, IDS_OPEN_FAILED, msg, MAX_PATH);
				LoadString(hInstance, IDS_VRML_EXPORT, title, MAX_PATH);
				MessageBox(GetActiveWindow(), msg, title, MB_OK);
				return TRUE;
			}
			HCURSOR busy = LoadCursor(NULL, IDC_WAIT);
			HCURSOR normal = LoadCursor(NULL, IDC_ARROW);
			SetCursor(busy);

			// ----------------------------------------------------------------

			mNumTriMeshes = 0;
			mNumMaterials = 0;
			findSceneNodes(i->GetRootNode(), NULL);
			fprintf(mStream, _T("# Heretical Scene Format 1.0\n"));
			exportSceneNodes(0);
			findMeshesAndMaterials();
			exportMaterials(0);
			exportMeshes(0);

			// ----------------------------------------------------------------

		    SetCursor(normal);

            /*for (int frame = 0; frame < numFrames; frame++, mStart += sampleRate) {
                if (mStart > lastFrame)
                    break;
                VRML2Export vrml2;
                int val = vrml2.DoFBExport(filename, i, this, frame, mStart);
                if (!val) return val;
            }*/
            return TRUE;
        //}

		/*VRML2Export vrml2;
        int val = vrml2.DoExport(filename, i, this);
        return val;*/

    //return 1;  
}

BOOL HSFExp::SupportsOptions(int ext, DWORD options) {
	assert(ext == 0);	// We only support one extension
	return(options == SCENE_EXPORT_SELECTED) ? TRUE : FALSE;
}

void
HSFExp::initializeDefaults() {
    /*TCHAR text[MAX_PATH];

    GetAppData(mIp, NORMALS_ID, _T("no"), text, MAX_PATH);
    BOOL gen = _tcscmp(text, "yes") == 0;
    SetGenNormals(gen);
    GetAppData(mIp, INDENT_ID, _T("yes"), text, MAX_PATH);
    gen = _tcscmp(text, "yes") == 0;
    SetIndent(gen);
    SetZUp(FALSE);
    GetAppData(mIp, COORD_INTERP_ID, _T("no"), text, MAX_PATH);
    gen = _tcscmp(text, "yes") == 0;
    SetCoordInterp(gen);
    GetAppData(mIp, EXPORT_HIDDEN_ID, _T("no"), text, MAX_PATH);
    gen = _tcscmp(text, "yes") == 0;
    SetExportHidden(gen);
    GetAppData(mIp, ENABLE_PROGRESS_BAR_ID, _T("yes"), text, MAX_PATH);
    gen = _tcscmp(text, "yes") == 0;
    SetEnableProgressBar(gen);

    GetAppData(mIp, PRIMITIVES_ID, _T("yes"), text, MAX_PATH);
    gen = _tcscmp(text, "yes") == 0;
    SetPrimitives(gen);

    GetAppData(mIp, EXPORT_PRE_LIGHT_ID, _T("no"), text, MAX_PATH);
    gen = _tcscmp(text, "yes") == 0;
    SetPreLight(gen);
    GetAppData(mIp, CPV_SOURCE_ID, _T("max"), text, MAX_PATH);
    gen = _tcscmp(text, "max") == 0;
    SetCPVSource(gen);

    GetAppData(mIp, FLIP_BOOK_ID, _T("no"), text, MAX_PATH);
    gen = _tcscmp(text, "yes") == 0;
    SetFlipBook(gen);

	GetAppData(mIp, USE_PREFIX_ID, _T("yes"), text, MAX_PATH);
    SetUsePrefix(_tcscmp(text, _T("yes")) == 0);
    GetAppData(mIp, URL_PREFIX_ID, _T("../maps"), text, MAX_PATH);
    TSTR prefix = text;
    SetUrlPrefix(prefix);
    GetAppData(mIp, DIGITS_ID, _T("4"), text, MAX_PATH);
    SetDigits(atoi(text));

    GetAppData(mIp, POLYGON_TYPE_ID, _T("Triangles"), text, MAX_PATH);
   // some following strings moved to resources, 010809  --prs.
    if (_tcscmp(text, _T(GetString(IDS_VISIBLE_EDGES))) == 0)
        SetPolygonType(OUTPUT_VISIBLE_EDGES);
    else if (_tcscmp(text, _T(GetString(IDS_NGONS))) == 0)
        SetPolygonType(OUTPUT_NGONS);
    else if (_tcscmp(text, _T(GetString(IDS_QUADS))) == 0)
        SetPolygonType(OUTPUT_QUADS);
    else
        SetPolygonType(OUTPUT_TRIANGLES);

    Tab<INode*> cameras, navInfos, backgrounds, fogs;
    GetCameras(GetIP()->GetRootNode(), &cameras, &navInfos,
                    &backgrounds, &fogs);
    int c = cameras.Count();
    int ci;
    INode *inode = NULL;
    if (c > 0) {
        TSTR name;
        GetAppData(mIp, CAMERA_ID, _T(""), text, MAX_PATH);
        if (_tcslen(text) == 0)
            inode = cameras[0];
        else {
            name = text;
            for (ci = 0; ci < c; ci++)
                if (_tcscmp(cameras[ci]->GetName(), name) == 0) {
                    inode = cameras[ci];
                    break;
                }
        }
    }
    SetCamera(inode);

    c = navInfos.Count();
    inode = NULL;
    if (c > 0) {
        TSTR name;
        GetAppData(mIp, NAV_INFO_ID, _T(""), text, MAX_PATH);
        if (_tcslen(text) == 0)
            inode = navInfos[0];
        else {
            name = text;
            for (ci = 0; ci < c; ci++)
                if (_tcscmp(navInfos[ci]->GetName(), name) == 0) {
                    inode = navInfos[ci];
                    break;
                }
        }
    }
    SetNavInfo(inode);

    c = backgrounds.Count();
    inode = NULL;
    if (c > 0) {
        TSTR name;
        GetAppData(mIp, BACKGROUND_ID, _T(""), text, MAX_PATH);
        if (_tcslen(text) == 0)
            inode = backgrounds[0];
        else {
            name = text;
            for (ci = 0; ci < c; ci++)
                if (_tcscmp(backgrounds[ci]->GetName(), name) == 0) {
                    inode = backgrounds[ci];
                    break;
                }
        }
    }
    SetBackground(inode);

    c = fogs.Count();
    inode = NULL;
    if (c > 0) {
        TSTR name;
        GetAppData(mIp, FOG_ID, _T(""), text, MAX_PATH);
        if (_tcslen(text) == 0)
            inode = fogs[0];
        else {
            name = text;
            for (ci = 0; ci < c; ci++)
                if (_tcscmp(fogs[ci]->GetName(), name) == 0) {
                    inode = fogs[ci];
                    break;
                }
        }
    }
    SetFog(inode);

    GetAppData(mIp, TFORM_SAMPLE_ID, _T("custom"), text, MAX_PATH);
    BOOL once = _tcscmp(text, _T("once")) == 0;
    SetTformSample(once);
    GetAppData(mIp, TFORM_SAMPLE_RATE_ID, _T("10"), text, MAX_PATH);
    SetTformSampleRate(atoi(text));

    GetAppData(mIp, COORD_SAMPLE_ID, _T("custom"), text, MAX_PATH);
    once = _tcscmp(text, _T("once")) == 0;
    SetCoordSample(once);
    GetAppData(mIp, COORD_SAMPLE_RATE_ID, _T("3"), text, MAX_PATH);
    SetCoordSampleRate(atoi(text));

    GetAppData(mIp, FLIPBOOK_SAMPLE_ID, _T("custom"), text, MAX_PATH);
    once = _tcscmp(text, _T("once")) == 0;
    SetFlipbookSample(once);        
    GetAppData(mIp, FLIPBOOK_SAMPLE_RATE_ID, _T("10"), text, MAX_PATH);
    SetFlipbookSampleRate(atoi(text));

    GetAppData(mIp, TITLE_ID, _T(""), text, MAX_PATH);
    SetTitle(text);
    GetAppData(mIp, INFO_ID, _T(""), text, MAX_PATH);
    SetInfo(text);*/
}


HSFExp::HSFExp() 
{
    //mHadAnim            = FALSE;
    mTformSample        = FALSE;
    mTformSampleRate    = 10;
    mCoordSample        = FALSE;
    mCoordSampleRate    = 3;
    mFlipbookSample     = FALSE;
    mFlipbookSampleRate = 10;

	mNextNodeId = 0;
	mNextMeshId = 0;
	mNextMaterialId = 0;
}

HSFExp::~HSFExp() {
}

// Number of file extensions supported by the exporter
int
HSFExp::ExtCount() {
    return 1;
}

// The exension supported
const TCHAR *
HSFExp::Ext(int n) {
    switch(n) {
    case 0:
        return _T("hsf");
    }
    return _T("");
}

const TCHAR *
HSFExp::LongDesc() {
    return _T("Heretical Scene Format Exporter");
}
   
const TCHAR *
HSFExp::ShortDesc() {
    return _T("Heretical Scene Format");
}

const TCHAR *
HSFExp::AuthorName() {
    return _T("h3");
}

const TCHAR *
HSFExp::CopyrightMessage() {
    return _T("Copyright 2010, URMOM");
}

const TCHAR *
HSFExp::OtherMessage1() {
    return _T("");
}

const TCHAR *
HSFExp::OtherMessage2() {
    return _T("");
}

unsigned int
HSFExp::Version() {
    return 100;
}

void
HSFExp::ShowAbout(HWND hWnd) {
}
