#include "hsfexp.h"
#include "3dsmaxport.h"

static TriObject* GetTriObjectFromNode(TimeValue time, INode *node, int &deleteIt);



void HSFExp::findMeshesAndMaterials() {
	mNumTriMeshes = 0;
	for (int i = 0; i < mSceneNodes.size(); ++i) {
		SceneNode sceneNode = mSceneNodes[i];
		INode* node = sceneNode.node;

		if (node->IsHidden()) {
			continue;
		}

		int deleteIt;
		TriObject *obj = GetTriObjectFromNode(mStart, node, deleteIt);
		if (obj) {
			Mesh &mesh = obj->GetMesh();
			int numverts = mesh.getNumVerts();
			int numfaces = mesh.getNumFaces();
		    
			if (numfaces > 0 && numverts > 0) {
				++mNumTriMeshes;

				findMaterial(node);
			}

			if (deleteIt) obj->DeleteMe();
		}
	}
}

void HSFExp::exportMeshes(int level) {
	// Export the meshes

    Indent(level);
    fprintf(mStream, _T("meshes %d\n"), mNumTriMeshes);

	for (int i = 0; i < mSceneNodes.size(); ++i) {
		SceneNode sceneNode = mSceneNodes[i];
		INode* node = sceneNode.node;

		if (node->IsHidden()) {
			continue;
		}

		int deleteIt;
		TriObject *triObject = GetTriObjectFromNode(mStart, node, deleteIt);
		if (triObject) {
			Indent(level++);
			fprintf(mStream, _T("{\n"));

			exportMesh(node, triObject, level);

			Indent(--level);
			fprintf(mStream, _T("}\n"));

			if (deleteIt) triObject->DeleteMe();
		}
	}

	fprintf(mStream, _T("\n"));
}


void HSFExp::exportMesh(INode* node, TriObject *const obj, int level) {
    assert(obj);

    Mesh &mesh = obj->GetMesh();
    int numverts = mesh.getNumVerts();
    int numtverts = mesh.getNumTVerts();
    int numfaces = mesh.getNumFaces();
	int vx1 = 0, vx2 = 1, vx3 = 2;
    
    if (numfaces == 0 || numverts == 0) {
        return;
    }

	Matrix3 worldMat = node->GetObjTMAfterWSM(mStart);
	Matrix3 rescaleMat = calcRescaleMatrix(worldMat);
	Point3 scale; {
        AffineParts parts;
        decomp_affine(worldMat, &parts);
		ScaleValue sv(parts.k, parts.u);
        scale = sv.s;
		if (parts.f < 0.0f) {
            scale = -scale;
		}
	}

	bool reverseWinding = false;
	if (scale.x < 0) reverseWinding = !reverseWinding;
	if (scale.y < 0) reverseWinding = !reverseWinding;
	if (scale.z < 0) reverseWinding = !reverseWinding;

	if (reverseWinding) {
		vx1 = 2;
		vx3 = 0;
	}

    mesh.buildRenderNormals();

    Mtl *mtl = node->GetMtl();

	int nodeId = getNodeId(node);
	if (nodeId != -1) {
		Indent(level);
		fprintf(mStream, _T("node %d\n"), nodeId);
	}

    // Output indices
    Indent(level);
    fprintf(mStream, _T("indices %d"), numfaces*3);
    for (int i = 0; i < numfaces; ++i) {
		fprintf(mStream, _T(" %d %d %d"),
			mesh.faces[i].v[vx1],
			mesh.faces[i].v[vx2],
			mesh.faces[i].v[vx3]
		);
    }
    newln();

    // Output submaterial indices
    Indent(level);
    fprintf(mStream, _T("faceSubMats %d"), numfaces);
    for (int i = 0; i < numfaces; ++i) {
        int id = mesh.faces[i].getMatID();
		fprintf(mStream, _T(" %d"), id);
    }
    newln();

	// Output positions
    Indent(level);
    fprintf(mStream, _T("positions %d "), numverts);

    for (int i = 0; i < numverts; i++) {
		Point3 p = mesh.verts[i];
		p = VectorTransform(rescaleMat, p);
        fprintf(mStream, _T("%s"), point(p));
    }
	newln();

	// Output normals
    Indent(level);
    fprintf(mStream, _T("normals %d "), numfaces * 3);

    for (int index = 0; index < numfaces; ++index) {
        int smGroup = mesh.faces[index].getSmGroup();

		int from = 0;
		int to = 3;
		int inc = 1;

		if (reverseWinding) {
			from = 2;
			to = -1;
			inc = -1;
		}

        for (int i = from; i != to; i += inc) {
			Point3 n;
			int norCnt;

            int cv = mesh.faces[index].v[i];
            RVertex * rv = mesh.getRVertPtr(cv);
            if (rv->rFlags & SPECIFIED_NORMAL) {
                n = rv->rn.getNormal();
            }
            else if ((norCnt = (int)(rv->rFlags & NORCT_MASK)) != 0 && smGroup) {
                if (norCnt == 1)
                    n = rv->rn.getNormal();
                else for (int j = 0; j < norCnt; j++) {
                    n = rv->ern[j].getNormal();
                }
			} else {
                n = mesh.getFaceNormal(index);
			}

			if (reverseWinding) {
				n = -n;
			}

			fprintf(mStream, _T("%s"), normPoint(n));
        }
    }
	newln();
    

	// Output texture coordinates

    int numMaps = 0;
	for (int mp = 0; mp < MAX_MESHMAPS-1; ++mp) {
		if (mesh.mapSupport(mp)) {
			++numMaps;
		}
	}

	Indent(level);
	fprintf(mStream, _T("maps %d\n"), numMaps);

	for (int mp = 0; mp < MAX_MESHMAPS-1; ++mp) {
		if (mesh.mapSupport(mp)) {
			Indent(level);
			fprintf(mStream, _T("{\n"));
			++level;

			Indent(level);
			fprintf(mStream, _T("channel %d"), mp);
			newln();

			int numTVx = mesh.getNumMapVerts(mp);
			Indent(level);
			fprintf(mStream, _T("coords %d "), numTVx);

			if (numTVx) {
				UVVert* verts = mesh.mapVerts(mp);
				for (int i = 0; i < numTVx; ++i) {
					UVVert tv = verts[i];
					fprintf(mStream, _T("%s"), texture(tv));
				}
				newln();
				
				Indent(level);
				fprintf(mStream, _T("indices %d"), numfaces*3);
				TVFace* faces = mesh.mapFaces(mp);

				for (int i = 0; i < mesh.getNumFaces(); ++i) {
					fprintf(mStream, _T(" %d %d %d"),
						faces[i].t[vx1],
						faces[i].t[vx2],
						faces[i].t[vx3]
					);
				}
				newln();
			}
			--level;
			Indent(level);
			fprintf(mStream, _T("}\n"));
		}
	}
	fprintf(mStream, _T("\n"));
}


static TriObject* GetTriObjectFromNode(TimeValue time, INode *node, int &deleteIt)
{
   deleteIt = FALSE;
   Object *obj = node->EvalWorldState(time).obj;

   if (obj && obj->CanConvertToType(Class_ID(TRIOBJ_CLASS_ID, 0))) {
     TriObject *tri = (TriObject *) obj->ConvertToType(time,
     Class_ID(TRIOBJ_CLASS_ID, 0));
     // Note that the TriObject should only be deleted
     // if the pointer to it is not equal to the object
     // pointer that called ConvertToType()
     if (obj != tri) deleteIt = TRUE;
     return tri;
   } else {
     return NULL;
   }
}
