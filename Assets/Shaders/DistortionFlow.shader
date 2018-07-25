Shader "Custom/DistortionFlow" {
	Properties {
		_Color ("Color", Color) = (1,1,1,1)
		_MainTex ("Albedo (RGB)", 2D) = "white" {}
		//一张由噪声算法产生的噪声贴图，保存了一个些顺时针的矢量，A通道中保存了一些噪声
		[NoScaleOffset] _FlowMap("Flow(RG,A noise)",2D) = "black"{}
		[NoScaleOffset] _NormalMap ("Normals", 2D) = "bump" {}
		//不是很懂
		_UJump ("U jump per phase", Range(-0.25, 0.25)) = 0.25
		_VJump ("V jump per phase", Range(-0.25, 0.25)) = 0.25
		//拉伸比率
		_Tiling ("Tiling", Float) = 1
		//
		_Speed("Speed",Float) =1
		//调整从Flowmap中采样到的方向矢量大小
		_FlowStrength ("Flow Strength", Float) = 1
		_FlowOffset ("Flow Offset", Float) = 0
		_Glossiness ("Smoothness", Range(0,1)) = 0.5
		_Metallic ("Metallic", Range(0,1)) = 0.0
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		CGPROGRAM

		#pragma surface surf Standard fullforwardshadows
		#pragma target 3.0

		#include "Flow.cginc"

		sampler2D _MainTex,_FlowMap, _NormalMap;

		struct Input {
			float2 uv_MainTex;
		};

		half _Glossiness;
		half _Metallic;
		fixed4 _Color;
		float _UJump,_VJump,_Tiling,_Speed,_FlowStrength, _FlowOffset;

		void surf (Input IN, inout SurfaceOutputStandard o) {
			//采样矢量贴图的rg通道，_FlowMap记录了每一个片段水面的流动方向
			float2 flowVector = tex2D(_FlowMap,IN.uv_MainTex).rg * 2 - 1;
			flowVector *= _FlowStrength;
			//采样矢量贴图的a通道，扰动时间
			float noise = tex2D(_FlowMap, IN.uv_MainTex).a;
			float time = _Time.y * _Speed + noise;
			float2 jump = float2(_UJump,_VJump);

			//使用间隔0.5秒的两组UV
			float3 uvwA = FlowUVW(IN.uv_MainTex, flowVector,jump,_FlowOffset,_Tiling, time, false);
			float3 uvwB = FlowUVW(IN.uv_MainTex, flowVector,jump,_FlowOffset,_Tiling,time, true);

			//两组纹理要分别采样法线贴图
			float3 normalA = UnpackNormal(tex2D(_NormalMap, uvwA.xy)) * uvwA.z;
			float3 normalB = UnpackNormal(tex2D(_NormalMap, uvwB.xy)) * uvwB.z;
			o.Normal = normalize(normalA + normalB);

			fixed4 texA = tex2D(_MainTex, uvwA.xy) * uvwA.z;
			fixed4 texB = tex2D(_MainTex, uvwB.xy) * uvwB.z;

			fixed4 c = (texA + texB)* _Color;
			o.Albedo = c.rgb;
			o.Metallic = _Metallic;
			o.Smoothness = _Glossiness;
			o.Alpha = c.a;
		}
		ENDCG
	}
	FallBack "Diffuse"
}
