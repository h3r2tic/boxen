module xf.nucleus.StdUniforms;


template MStdUniforms() {
	private	import
		xf.omg.core.LinearAlgebra,
		xf.omg.util.ViewSettings;
	
	mat4	worldToView;
	mat4	worldToClip;
	mat4	viewToWorld;
	mat4	viewToClip;
	mat4	clipToView;
	vec3	eyePosition;
	float	farPlaneDistance;
	float	nearPlaneDistance;

	const char[] stdUniformsCg =
`
float3x4 modelToWorld;
float4x4 worldToView <
	string scope = "effect";
>;
float4x4 worldToClip <
	string scope = "effect";
>;
float4x4 viewToWorld <
	string scope = "effect";
>;
float4x4 viewToClip <
	string scope = "effect";
>;
float4x4 clipToView <
	string scope = "effect";
>;
float3 eyePosition <
	string scope = "effect";
>;
float farPlaneDistance <
	string scope = "effect";
>;`;

	void updateStdUniforms(ViewSettings vs) {
		this.viewToClip = vs.computeProjectionMatrix();
		this.clipToView = this.viewToClip.inverse();
		this.worldToView = vs.computeViewMatrix();
		this.worldToClip = this.viewToClip * this.worldToView;
		this.viewToWorld = this.worldToView.inverse();
		this.eyePosition = vec3.from(vs.eyeCS.origin);
		this.farPlaneDistance = vs.farPlaneDistance;
		this.nearPlaneDistance = vs.nearPlaneDistance;
	}

	void bindStdUniforms(Effect effect) {
		void setUniform(cstring name, void* ptr) {
			if (auto upp = effect.getUniformPtrPtr(name)) {
				*upp = ptr;
			}
		}

		setUniform("worldToView", &worldToView);
		setUniform("worldToClip", &worldToClip);
		setUniform("viewToWorld", &viewToWorld);
		setUniform("viewToClip", &viewToClip);
		setUniform("clipToView", &clipToView);
		setUniform("eyePosition", &eyePosition);
		setUniform("farPlaneDistance", &farPlaneDistance);
	}
}
