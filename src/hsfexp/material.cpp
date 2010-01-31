#include "hsfexp.h"
#include "3dsmaxport.h"
#include "bmmlib.h"
#include "Path.h"
#include "IPathConfigMgr.h"
#include "shaders.h"



int HSFExp::getMaterialId(Mtl* m) {
	std::map<Mtl*, int>::const_iterator it
		= mMtlToId.find(m);

	if (it != mMtlToId.end()) {
		return it->second;
	} else {
		return -1;
	}
}


void HSFExp::findMaterial(Mtl* m) {
	if (!m) return; // No material assigned

	int id = getMaterialId(m);
	if (-1 == id) {
		mMtlToId[m] = mNextMaterialId++;
		mMaterials.push_back(m);

		if (m->IsMultiMtl()) {
			int numSub = m->NumSubMtls();
			for (int i = 0; i < numSub; ++i) {
				findMaterial(m->GetSubMtl(i));
			}
		}
	}
}

void HSFExp::findMaterial(INode* node) {
	// Get the material from the node
	Mtl* m = node->GetMtl();
	findMaterial(m);
}

void HSFExp::exportMaterials(int level) {
	Indent(level);
    fprintf(mStream, _T("materials %d\n"), mMaterials.size());

	mLastExporterdMaterial = -1;

	for (
		std::vector<Mtl*>::iterator it = mMaterials.begin();
		it != mMaterials.end();
		++it
	) {
		exportMaterial(*it, level);
	}

	fprintf(mStream, _T("\n"));
}


void HSFExp::exportMaterial(Mtl* mat, int level) {
	if (!mat) {
		Indent(level);
		fprintf(mStream, _T("null\n"));
		return;
	}

	int matId = getMaterialId(mat);
	assert (matId != -1);

	// Already exported
	if (matId <= mLastExporterdMaterial) {
		Indent(level);
		fprintf(mStream, _T("%d\n"), matId);
		return;
	}

	assert (mLastExporterdMaterial < matId);
	mLastExporterdMaterial = matId;

	Indent(level++);
	fprintf(mStream, _T("%d {\n"), matId);

	{
		Indent(level);
		char* matName = escapeName(mat->GetName());
		fprintf(mStream, _T("name '%s'\n"), matName);
		fflush(mStream);
		delete[] matName;
	}

	if (mat->IsMultiMtl()) {
		Indent(level);
		fprintf(mStream, _T("type 'multi'\n"));

		int numSub = mat->NumSubMtls();

		Indent(level);
		fprintf(mStream, _T("sub %d\n"), numSub);

		for (int i = 0; i < numSub; ++i) {
			Mtl* sub = mat->GetSubMtl(i);
			exportMaterial(sub, level);
		}
	} else {
		BOOL isStd1 = (mat->ClassID() == Class_ID(DMTL_CLASS_ID, 0));
		BOOL isStd2 = (mat->ClassID() == Class_ID(DMTL2_CLASS_ID, 0));

		// See if it's a Standard material
		if (isStd1 || isStd2) {
			Indent(level);
			fprintf(mStream, _T("type 'standard'\n"));

			StdMat* stdMat = (StdMat*)mat;
			char* shadingName;

			if (isStd2) {
				Shader* shader = ((StdMat2*)mat)->GetShader();
				if (shader) {
					shadingName = shader->GetName();
				} else {
					shadingName = "Unknown";
				}
			} else {
				int shading = stdMat->GetShading();
				switch (shading) {
					case SHADE_CONST:	// faceted Phong
					case SHADE_PHONG: {
						shadingName = "Phong";
					} break;
					case SHADE_METAL: {
						shadingName = "Metal";
					} break;
					case SHADE_BLINN: {
						shadingName = "Blinn";
					} break;
					default: {
						shadingName = "Unknown";
					}
				}
			}

			Indent(level);
			fprintf(mStream, _T("shader '%s'\n"), shadingName);			

			Indent(level);
	        fprintf(
				mStream, _T("diffuseTint %s\n"),
				color(stdMat->GetDiffuse(mStart))
			);

			Indent(level);
	        fprintf(
				mStream, _T("specularTint %s\n"),
				color(stdMat->GetSpecular(mStart))
			);

			Indent(level);
	        fprintf(
				mStream, _T("shininess %s\n"),
				floatVal(stdMat->GetShininess(mStart))
			);

			Indent(level);
	        fprintf(
				mStream, _T("shininessStrength %s\n"),
				floatVal(stdMat->GetShinStr(mStart))
			);

			Indent(level);
	        fprintf(
				mStream, _T("ior %s\n"),
				floatVal(stdMat->GetIOR(mStart))
			);

			Indent(level);
	        fprintf(
				mStream, _T("opacity %s\n"),
				floatVal(stdMat->GetOpacity(mStart))
			);

			BOOL twoSided = stdMat->GetTwoSided();
			//buf.printf(_T("Two sided=%d, U Tile = %.1f, V Tile = %.1f"),
			//two, utile, vtile);

			int numSubMaps = mat->NumSubTexmaps();

			Indent(level);
	        fprintf(mStream, _T("maps %d\n"), numSubMaps);

			for (int i = 0; i < numSubMaps; ++i) {
				exportMaterialMap(mat, i, level);
			}
		} else {
			Indent(level);
			fprintf(mStream, _T("type 'Unknown'\n"));
		}
	}

	Indent(--level);
	fprintf(mStream, _T("}\n"));
}


void HSFExp::exportMaterialMap(Mtl* mat, unsigned tmapId, int level) {
	assert (mat);

	Texmap* tmap = mat->GetSubTexmap(tmapId);
	if (!tmap) {
		Indent(level);
		fprintf(mStream, _T("null\n"));
		return;
	}

	Indent(level++);
	fprintf(mStream, _T("{\n"));

	Class_ID clsId = tmap->ClassID();

	Indent(level);
	char* mapName = escapeName(tmap->GetName());
	fprintf(mStream, _T("name '%s'\n"), mapName);
	fflush(mStream);
	delete[] mapName;

	CStr texDir = mExportName + _T("-tex");
	TSTR newFilePath = mExportDir + _T("\\") + texDir + _T("\\");
	TSTR hsfFilePath = texDir + _T("/");

	IPathConfigMgr::GetPathConfigMgr()
		->CreateDirectoryHierarchy(mExportDir + _T("\\") + texDir);

	if (Class_ID(BMTEX_CLASS_ID, 0) == clsId) {
		Indent(level);
		fprintf(mStream, _T("type 'bitmap'\n"));

		BitmapTex *bmt = (BitmapTex*)tmap;

		TSTR oldFilePath = bmt->GetMapName();

		TSTR escapedFilePath;
		escapedFilePath.append(oldFilePath);

		{
			char* fname = escapedFilePath;
			for (char* ch = fname; ch && *ch; ++ch) {
				if ('\\' == *ch || '/' == *ch || ':' == *ch) {
					*ch = '-';
				}
			}
		}

		newFilePath += escapedFilePath;
		hsfFilePath += escapedFilePath;

		CopyFile(oldFilePath, newFilePath, FALSE);

		char* fname = escapeName(hsfFilePath);
		Indent(level);
		fprintf(mStream, _T("file '%s'\n"), fname);
		delete[] fname;
	} else {
		Indent(level);
		if (Class_ID(MIRROR_CLASS_ID, 0) == clsId) {
			fprintf(mStream, _T("type 'flatMirror'\n"));
		} else if (Class_ID(ACUBIC_CLASS_ID, 0) == clsId) {
			fprintf(mStream, _T("type 'reflection'\n"));
		} else if (Class_ID(MIRROR_CLASS_ID, 0) == clsId) {
			fprintf(mStream, _T("type 'flatMirror'\n"));
		} else {
			fprintf(mStream, _T("type 'bitmap'\n"));
		}

		Bitmap* bm;
		BitmapInfo bi;
		bi.SetType(BMM_TRUE_32);
		bi.SetWidth(512);
		bi.SetHeight(512);
		bi.SetFlags(MAP_HAS_ALPHA);
		bi.SetCustomFlag(0);
		bm = TheManager->Create(&bi);
		assert (bm);
		tmap->RenderBitmap(mStart, bm, 1.0f, TRUE);

		newFilePath += tmap->GetName() + _T(".png");
		hsfFilePath += tmap->GetName() + _T(".png");

		bi.SetPath(MaxSDK::Util::Path(newFilePath));

		bm->OpenOutput(&bi);
		bm->Write(&bi);
		bm->Close(&bi);

		char* fname = escapeName(hsfFilePath);
		Indent(level);
		fprintf(mStream, _T("file '%s'\n"), fname);
		delete[] fname;

		bm->DeleteThis();
	}

	UVGen *uvGen = tmap->GetTheUVGen();
	if (uvGen && uvGen->IsStdUVGen()) {
		StdUVGen* uv = (StdUVGen*)uvGen;
		assert (uv);

		float utile = uv->GetUScl(mStart);
		float vtile = uv->GetVScl(mStart);
		float uoff = uv->GetUOffs(mStart);
		float voff = uv->GetVOffs(mStart);

		if (utile != 1.0f || vtile != 1.0f) {
			Indent(level);
			fprintf(mStream, _T("uvTile %f %f\n"), utile, vtile);
		}

		if (uoff != 0.0f || voff != 0.0f) {
			Indent(level);
			fprintf(mStream, _T("uvOffset %f %f\n"), uoff, voff);
		}
	}

	Indent(--level);
	fprintf(mStream, _T("}\n"));
	fflush(mStream);
}
