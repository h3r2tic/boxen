#include "hsfexp.h"
#include "3dsmaxport.h"



void HSFExp::findSceneNodes(INode* node, INode* parent) {
	if (!node) return;


	if (!node->IsHidden()) {
		Object* obj = node->EvalWorldState(mStart).obj;
		if (obj && obj->CanConvertToType(triObjectClassID)) {
			++mNumTriMeshes;
		}
	}

	mSceneNodes.push_back(SceneNode(node, parent));
	
	int n = node->NumberOfChildren();
	for (int i = 0; i < n; ++i) {
		findSceneNodes(node->GetChildNode(i), node);
	}
}


int HSFExp::getNodeId(INode* node) {
	for (int i = 0; i < mSceneNodes.size(); ++i) {
		SceneNode &sceneNode = mSceneNodes[i];
		if (sceneNode.node == node) {
			return i;
		}
	}

	return -1;
}


void HSFExp::exportSceneNodes(int level) {
	Indent(level);
    fprintf(mStream, _T("nodes %d\n"), mSceneNodes.size());

	for (int i = 0; i < mSceneNodes.size(); ++i) {
		SceneNode sceneNode = mSceneNodes[i];
		INode* node = sceneNode.node;
		INode* parent = sceneNode.parent;

		exportSceneNode(node, parent, level);
	}

	fprintf(mStream, _T("\n"));
}


void HSFExp::exportSceneNode(INode* node, INode* parent, int level) {
    Indent(level++);
    fprintf(mStream, _T("{\n"));

	int parentId = getNodeId(parent);
	if (parentId != -1) {
		Indent(level);
		fprintf(mStream, _T("parent %d\n"), parentId);
	}

	Indent(level);
	char* name = escapeName(node->GetName());
	fprintf(mStream, _T("name '%s'\n"), name);
	delete[] name;

	OutputNodeTransform(node, level);

    Indent(--level);
    fprintf(mStream, _T("}\n"));
}