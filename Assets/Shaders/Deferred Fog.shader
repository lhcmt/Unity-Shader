Shader "Custom/Deferred Fog" {
	
	Properties {
		_MainTex ("Source", 2D) = "white" {}
	}

	SubShader {
		Cull Off
		ZTest Always
		ZWrite Off

		Pass {
			CGPROGRAM

			#pragma vertex VertexProgram
			#pragma fragment FragmentProgram

			#pragma multi_compile_fog
			#define FOG_DISTANCE

			#include "UnityCG.cginc"
			//Unity通过_CameraDepthTexture变量使深度缓冲区可用
			sampler2D _MainTex, _CameraDepthTexture;

			float3 _FrustumCorners[4];

			struct VertexData {
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;

			};

			struct Interpolators {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				#if defined(FOG_DISTANCE)
					float3 ray : TEXCOORD1;
				#endif
			};

			Interpolators VertexProgram (VertexData v) {
				Interpolators i;
				i.pos = UnityObjectToClipPos(v.vertex);
				i.uv = v.uv;
				#if defined(FOG_DISTANCE)
					i.ray = _FrustumCorners[v.uv.x + 2 * v.uv.y];
				#endif
				return i;
			}

			float4 FragmentProgram (Interpolators i) : SV_Target {
				//对这个摄像机深度纹理进行采样,采样结果为0-1 需要转换
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv);
				depth = Linear01Depth(depth);
				//通过到远裁剪平面的距离来缩放这个值
				float viewDistance = depth * _ProjectionParams.z - _ProjectionParams.y;
				#if defined(FOG_DISTANCE)
					viewDistance = length(i.ray * depth);
				#endif

				UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
				unityFogFactor = saturate(unityFogFactor);
				//对于天空盒不做影响
				#if !defined(FOG_SKYBOX)
					if (depth > 0.9999) {
						unityFogFactor = 1;
					}
				#endif
				#if !defined(FOG_LINEAR) && !defined(FOG_EXP) && !defined(FOG_EXP2)
					unityFogFactor = 1;
				#endif						
				float3 sourceColor = tex2D(_MainTex, i.uv).rgb;
				float3 foggedColor =
					lerp(unity_FogColor.rgb, sourceColor, unityFogFactor);
				return float4(foggedColor, 1);
			}

			ENDCG
		}
	}
}