#if !defined(FLOW_INCLUDED)
#define FLOW_INCLUDED

//CG函数，让UV坐标随着时间移动
//w为权重，flowB为TRUE时，表示第二次采样
float3 FlowUVW(float2 uv,float2 flowVector,float2 jump,
	float flowOffset, float tiling, float time, bool flowB){

	//对时间使用锯齿级数
	float phaseOffset = flowB ? 0.5 : 0;
	//第二个锯齿比第一个锯齿快0.5秒，是的两个锯齿的之和始终保持1
	//frac函数是取小数部分
	float progress = frac(time + phaseOffset);
	float3 uvw;
	//uvw.xy = uv - flowVector * progress + phaseOffset;
	uvw.xy = uv - flowVector * (progress + flowOffset);
	//拉伸平铺,拉伸以后会导致周期变短，比如tiling =2 时。流动会比 =1 时快
	//因为采样的步幅变大，周期变短了
	uvw.xy *= tiling;
	uvw.xy += phaseOffset;
	//
	uvw.xy += (time - progress) * jump;
	//Z为权重 在0-1-0变化，用来平滑锯齿级数
	uvw.z = 1 - abs(1 - 2 * progress);
	return uvw;
}

#endif