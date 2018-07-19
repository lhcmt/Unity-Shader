// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"
//当使用三种雾计算方式时，定义FOG_DEPTH
#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
	#if !defined(FOG_DISTANCE)
		#define FOG_DEPTH 1
	#endif
	//启用 雾
	#define FOG_ON 1
#endif

float4 _Tint;
sampler2D _MainTex, _DetailTex, _DetailMask;;
float4 _MainTex_ST, _DetailTex_ST;
//法线
sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;
//金属度贴图和可调节参数
sampler2D _MetallicMap;
float _Metallic;
float _Smoothness;
//自发光纹理 和 颜色参数
sampler2D _EmissionMap;
float3 _Emission;

//自身遮罩贴图，和强度参数
sampler2D _OcclusionMap;
float _OcclusionStrength;

float _AlphaCutoff;
//顶点数据
struct VertexData {
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 uv : TEXCOORD0;
};
//片段着色器插值数据
struct Interpolators {
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;   //float4 xy表示第一套纹理， zw采样第二套纹理
	float3 normal : TEXCOORD1;

	#if defined(BINORMAL_PER_FRAGMENT)
		float4 tangent : TEXCOORD2;
	#else
		float3 tangent : TEXCOORD2;
		float3 binormal : TEXCOORD3;
	#endif
	//当启用雾深度时，增加一个通道w,为深度值包含一个插值器，保存pos.z值
	#if FOG_DEPTH
		float4 worldPos : TEXCOORD4;
	#else
		float3 worldPos : TEXCOORD4;
	#endif

	SHADOW_COORDS(5)

	#if defined(VERTEXLIGHT_ON)
		float3 vertexLightColor : TEXCOORD6;
	#endif
};
//_MetallicMap.r通道保存金属度
float GetMetallic (Interpolators i) {
	#if defined(_METALLIC_MAP)
		return tex2D(_MetallicMap, i.uv.xy).r;
	#else
		return  _Metallic;
	#endif
}


float GetSmoothness (Interpolators i) {
	float smoothness = 1;
	#if defined(_SMOOTHNESS_ALBEDO)
		smoothness = tex2D(_MainTex, i.uv.xy).a;
	#elif defined(_SMOOTHNESS_METALLIC) && defined(_METALLIC_MAP)
		smoothness = tex2D(_MetallicMap, i.uv.xy).a; //_MetallicMap.a通道保存光滑度
	#endif
	return smoothness * _Smoothness;
}

//获取自发光颜色，，前向渲染和延迟渲染通道中都需要包含
float3 GetEmission(Interpolators i)
{
	#if defined(FORWARD_BASE_PASS) ||defined(DEFERRED_PASS)
		#if defined(_EMISSION_MAP)
			return tex2D(_EmissionMap, i.uv.xy) * _Emission;
		#else
			return _Emission;
		#endif
	#else
		return 0;
	#endif
}
//自身遮罩，表示为明暗程度，0-1
float GetOcclusion (Interpolators i) {
	#if defined(_OCCLUSION_MAP)
		return lerp(1, tex2D(_OcclusionMap, i.uv.xy).g, _OcclusionStrength);
	#else
		return 1;
	#endif
}
float GetDetailMask (Interpolators i) {
	#if defined (_DETAIL_MASK)
		return tex2D(_DetailMask, i.uv.xy).a;
	#else
		return 1;
	#endif
}
//根据detailmask 的值，插值 漫反射和细节贴图
float3 GetAlbedo (Interpolators i) {
	float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;
	#if defined(_DETAIL_ALBEDO_MAP)
		float3 details = tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;
		albedo = lerp(albedo, albedo * details, GetDetailMask(i));
	#endif
	return albedo;
}

//获取保存在_MainTex.a通道中的透明度
float GetAlpha (Interpolators i)
{
	float alpha = _Tint.a;
	#if !defined(_SMOOTHNESS_ALBEDO)
		alpha *= tex2D(_MainTex, i.uv.xy).a;
	#endif
	return alpha;
}


void ComputeVertexLightColor (inout Interpolators i) {
	#if defined(VERTEXLIGHT_ON)
		i.vertexLightColor = Shade4PointLights(
			unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
			unity_LightColor[0].rgb, unity_LightColor[1].rgb,
			unity_LightColor[2].rgb, unity_LightColor[3].rgb,
			unity_4LightAtten0, i.worldPos.xyz, i.normal
		);
	#endif
}

float3 CreateBinormal (float3 normal, float3 tangent, float binormalSign) {
	return cross(normal, tangent.xyz) *
		(binormalSign * unity_WorldTransformParams.w);
}

//顶点着色器
Interpolators MyVertexProgram (VertexData v) {
	Interpolators i;
	//将顶点变换到裁剪坐标系，透视投影
	i.pos = UnityObjectToClipPos(v.vertex);
	i.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);
	#if FOG_DEPTH
		i.worldPos.w = i.pos.z;
	#endif

	//特殊矩阵，ObjectToWorld的逆转置矩阵
	i.normal = UnityObjectToWorldNormal(v.normal);

	#if defined(BINORMAL_PER_FRAGMENT)
		i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
	#else
		i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
		i.binormal = CreateBinormal(i.normal, i.tangent, v.tangent.w);
	#endif

	//纹理坐标映射
	i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
	i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);

	TRANSFER_SHADOW(i);

	ComputeVertexLightColor(i);
	return i;
}
//计算直接光UnityLight
UnityLight CreateLight (Interpolators i) {
	UnityLight light;
	//延迟光照下，使用黑色的虚拟光源
	#if defined(DEFERRED_PASS) 
		light.dir = float3(0, 1, 0);
		light.color = 0;
	//前向渲染
	#else
		//对于点光源，它们不是无限远的
		#if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
			light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
		#else
			light.dir = _WorldSpaceLightPos0.xyz;
		#endif
		//衰减因子
		UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos.xyz);
		light.color = _LightColor0.rgb * attenuation;
	#endif
	//light.ndotl = DotClamped(i.normal, light.dir);
	return light;
}

//反射投影,返回方向
float3 BoxProjection (
	float3 direction, float3 position,
	float4 cubemapPosition, float3 boxMin, float3 boxMax
) {
	#if UNITY_SPECCUBE_BOX_PROJECTION
		UNITY_BRANCH
		if (cubemapPosition.w > 0) {
			float3 factors =
				((direction > 0 ? boxMax : boxMin) - position) / direction;
			float scalar = min(min(factors.x, factors.y), factors.z);
			direction = direction * scalar + (position - cubemapPosition);
		}
	#endif
	return direction;
}
//间接光，环境光 ，反射探测机获得环境贴图
UnityIndirect CreateIndirectLight (Interpolators i, float3 viewDir) {
	UnityIndirect indirectLight;
	indirectLight.diffuse = 0;
	indirectLight.specular = 0;
	//顶点光照下
	#if defined(VERTEXLIGHT_ON)
		indirectLight.diffuse = i.vertexLightColor;
	#endif

	#if defined(FORWARD_BASE_PASS) || defined(DEFERRED_PASS)
		indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
		float3 reflectionDir = reflect(-viewDir, i.normal);
		Unity_GlossyEnvironmentData envData;
		envData.roughness = 1 - GetSmoothness(i);
		envData.reflUVW = BoxProjection(
			reflectionDir, i.worldPos.xyz,
			unity_SpecCube0_ProbePosition,
			unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax
		);
		float3 probe0 = Unity_GlossyEnvironment(
			UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData
		);
		envData.reflUVW = BoxProjection(
			reflectionDir, i.worldPos.xyz,
			unity_SpecCube1_ProbePosition,
			unity_SpecCube1_BoxMin, unity_SpecCube1_BoxMax
		);
		#if UNITY_SPECCUBE_BLENDING
			float interpolator = unity_SpecCube0_BoxMin.w;
			UNITY_BRANCH
			if (interpolator < 0.99999) {
				float3 probe1 = Unity_GlossyEnvironment(
					UNITY_PASS_TEXCUBE_SAMPLER(unity_SpecCube1, unity_SpecCube0),
					unity_SpecCube0_HDR, envData
				);
				indirectLight.specular = lerp(probe1, probe0, interpolator);
			}
			else {
				indirectLight.specular = probe0;
			}
		#else
			indirectLight.specular = probe0;
		#endif
		//将环境光的漫反射和镜面乘上
		float occlusion = GetOcclusion(i);
		indirectLight.diffuse *= occlusion;
		indirectLight.specular *= occlusion;
		#if defined(DEFERRED_PASS) && UNITY_ENABLE_REFLECTION_BUFFERS
			indirectLight.specular = 0;
		#endif
	#endif

	return indirectLight;
}
//法线存储于切线空间
float3 GetTangentSpaceNormal (Interpolators i) {
	float3 mainNormal =
		UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
	float3 detailNormal =
		UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
	detailNormal = lerp(float3(0, 0, 1), detailNormal, GetDetailMask(i));
	return BlendNormals(mainNormal, detailNormal);
}

void InitializeFragmentNormal(inout Interpolators i) {
	float3 tangentSpaceNormal = GetTangentSpaceNormal(i);
	#if defined(BINORMAL_PER_FRAGMENT)
		float3 binormal = CreateBinormal(i.normal, i.tangent.xyz, i.tangent.w);
	#else
		float3 binormal = i.binormal;
	#endif
	
	i.normal = normalize(
		tangentSpaceNormal.x * i.tangent +
		tangentSpaceNormal.y * binormal +
		tangentSpaceNormal.z * i.normal
	);
}

//用于支持在延迟渲染中，片段着色器的输出
//在定义DEFERRED_PASS，填充G  buffer
//否则 常规输出color
struct FragmentOutput{
	#if defined(DEFERRED_PASS)
		float4 gBuffer0 : SV_Target0;//第一个G缓冲区用于存储漫反射率和表面遮挡。这是一个ARGB32纹理，就像一个常规的帧缓冲区。
		                             //反射率存储在RGB通道中，遮挡存储在A通道中。 我们知道此时的反射率颜色，我们可以使用GetOcclusion来访问这些遮挡值。
		float4 gBuffer1 : SV_Target1;//第二个G缓冲器用于存储RGB通道中的镜面高光颜色，以及A通道中的平滑度值。它也是一个ARGB32纹理。
		
		float4 gBuffer2 : SV_Target2;//第三个G缓冲区包含的是世界空间中的法向量。它们存储在ARGB2101010纹理的RGB通道中，每个坐标都是使用十位进行存储，A通道只有两位
		float4 gBuffer3 : SV_Target3;//用于累计场景的光照，格式取决于是否使用HDR,LDR中，它是一个ARGB2101010纹理，就像正常的缓冲区一样。HDR中格式为ARGBHalf
	#else
		float4 color  : SV_Target;
	#endif
};

//应用雾效果,用于前向渲染通道 2018/7/17
//输入参数，片段颜色，片段插值信息
float4 ApplyFog(float4 color,Interpolators i){
	#if FOG_ON
		//雾的效果跟摄像机到观察点的距离相关,这里使用距离，而unity中使用场景的深度值
		float viewDistance = length(_WorldSpaceCameraPos - i.worldPos.xyz);
		//使用场景深度值作为雾的参数
		#if FOG_DEPTH
			viewDistance = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.worldPos.w);
		#endif

		//下面这个宏会创建unityFogFactor变量，用于插值，雾的颜色保存在unity_FogColor 这个变量定义在ShaderVariables中
		UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
		
		float3 fogColor = 0;
		//在多个光源下，如果每个光源都添加雾效果，场景会太亮
		//只对主光源添加雾效果
		#if defined(FORWARD_BASE_PASS)
			fogColor = unity_FogColor.rgb;
		#endif
		//只对RGB通道进行插值
		color.rgb = lerp(fogColor, color.rgb, saturate(unityFogFactor));
	#endif
	return color;

}

FragmentOutput MyFragmentProgram (Interpolators i){
	float alpha = GetAlpha(i);
	#if defined(_RENDERING_CUTOUT)
		clip(alpha - _AlphaCutoff);
	#endif
	InitializeFragmentNormal(i);
	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos.xyz);
	float3 specularTint;
	float oneMinusReflectivity;
	float3 albedo = DiffuseAndSpecularFromMetallic(
		GetAlbedo(i), GetMetallic(i), specularTint, oneMinusReflectivity
	);
	#if defined(_RENDERING_TRANSPARENT)
		albedo *= alpha;
		alpha = 1 - oneMinusReflectivity + alpha * oneMinusReflectivity;
	#endif
	float4 finalcolor = UNITY_BRDF_PBS(
		albedo, specularTint,
		oneMinusReflectivity, GetSmoothness(i),
		i.normal, viewDir,
		CreateLight(i), CreateIndirectLight(i, viewDir)
	);

	finalcolor.rgb += GetEmission(i);
	//淡出,获取alpha通道
	#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
		finalcolor.a = alpha;
	#endif


	FragmentOutput output;
	//如果使用延迟渲染，输出到Gbuffer
	#if defined(DEFERRED_PASS)
		//非HDR时，对原始颜色，进行编码
		#if !defined(UNITY_HDR_ON)
			finalcolor.rgb = exp2(-finalcolor.rgb);
		#endif
		output.gBuffer0.rgb = albedo;
		output.gBuffer0.a = GetOcclusion(i);
		output.gBuffer1.rgb = specularTint;
		output.gBuffer1.a = GetSmoothness(i);
		output.gBuffer2 = float4(i.normal * 0.5 + 0.5, 1);
		output.gBuffer3 = finalcolor;;
	#else
	//否则还是输出 color
		output.color = ApplyFog(finalcolor,i);
	#endif
	return output;
}

#endif