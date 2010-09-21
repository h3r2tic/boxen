module xf.nucleus.light.Point;

private {
	import xf.Common;
	import xf.nucleus.Light;
	import xf.nucleus.KernelParamInterface;
	import xf.nucleus.Defs;
}



class PointLight : Light {
	override cstring kernelName() {
		return "PointLight";
	}
	
	override void setKernelData(KernelParamInterface kpi) {
		kpi.bindUniform("lightPos", &position);
		kpi.bindUniform("lightRadius", &radius);
		kpi.bindUniform("lumIntens", &lumIntens);
		kpi.bindUniform("influenceRadius", &influenceRadius);
	}
}
