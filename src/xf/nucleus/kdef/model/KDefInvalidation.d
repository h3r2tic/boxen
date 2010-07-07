module xf.nucleus.kdef.model.KDefInvalidation;



struct KDefInvalidationInfo {
	bool anyConverters = false;
}


interface IKDefInvalidationObserver {
	void onKDefInvalidated(KDefInvalidationInfo info);
}
