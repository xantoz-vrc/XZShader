Shader "Xantoz/RaymarchedPalmTree"
{
    Properties
    {
        [NoScaleOffset]_Tex ("Cubemap (HDR)", Cube) = "Cube" {}
        [Gamma] _Exposure ("Exposure", Range(0, 8)) = 0.5
        _TexTint ("Tint Color", Color) = (1, 1, 1, 1)

        [NoScaleOffset]_NoiseTex ("Texture", 2D) = "white" {}

        _SceneScale("Scene scale", Range(0,10)) = 0.04
        _SceneRotationAngle("Scene rotation angle", Range(-180,180)) = 0
        _SceneRotationAxis("Scene rotation axis", Vector) = (1,0,0)
        _SceneOffset("Scene offset", Vector) = (0,0,0)
        _K("k-factor", Float) = 0.7
        
        [Toggle]_DepthWrite ("Write depth", Int) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "DisableBatching"="True" }
        LOD 100

        CGINCLUDE
        #define MAX_MARCHING_STEPS 128
        #define MIN_DIST 0.0
        #define MAX_DIST 100.0
        #define EPSILON 0.001

        #include "UnityCG.cginc"
        #include "../cginc/AudioLinkFuncs.cginc"
        #include "../cginc/rotation.cginc"

        // Currently we expect a single-channel cubemap in here
        TextureCube<float> _Tex;
        SamplerState sampler_Tex;
        float4 _Tex_HDR;
        float4 _TexTint;
        float _Exposure;
        Texture2D<float> _NoiseTex;

        float _SceneScale;
        float _SceneRotationAngle;
        float3 _SceneRotationAxis;
        float3 _SceneOffset;

        #define INOBJECTSPACE true
        float sphereSDF(float3 p, float r) {
            return length(p) - r;
        }

        float udRoundBox(float3 p, float3 b, float r) 
        {
            return length(max(abs(p)-b,0.0))-r;
        }

        float4 sdgTorus(float3 p, float ra, float rb)
        {
            float h = length(p.xz);
            return float4(length(float2(h-ra,p.y))-rb,
                normalize(p*float3(h-ra,h,h-ra)) );
        }

        // polynomial smooth min (k = 0.1);
        float smin(float a, float b, float k)
        {
            float h = clamp(0.5+0.5*(b-a)/k, 0.0, 1.0);
            return lerp(b, a, h) - k*h*(1.0-h);
        }

/*
        #define estimateNormal(fn, p) \
        normalize(float3( \
                fn(float3((p).x + EPSILON, (p).y,           (p).z          )) - fn(float3((p).x - EPSILON, (p).y,           (p).z          )), \
                fn(float3((p).x,           (p).y + EPSILON, (p).z          )) - fn(float3((p).x,           (p).y - EPSILON, (p).z          )), \
                fn(float3((p).x,           (p).y,           (p).z + EPSILON)) - fn(float3((p).x,           (p).y,           (p).z - EPSILON)) \
            ));
*/

        float sampleCubeMap(float3 texcoord)
        {
            float tex = _Tex.Sample(sampler_Tex, texcoord);
            float3 c = DecodeHDR(tex, _Tex_HDR);
            c = c * _TexTint.rgb * unity_ColorSpaceDouble.rgb;
            c *= _Exposure;
            return float4(c, 1);
        }

        float4 sampleReflectionProbe(float3 texcoord)
        {
            float3 col;
            
            // float4 tex0 = texCUBE(unity_SpecCube0, texcoord);
            float4 tex0 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, texcoord, 0.0);
	    float3 probe0 = DecodeHDR(tex0, unity_SpecCube0_HDR);
            col = probe0;

	    #if defined(FORWARD_BASE_PASS)
	    #if UNITY_SPECCUBE_BLENDING
	    float interpolator = unity_SpecCube0_BoxMin.w;

	    if (interpolator < 0.99999) {
		// float4 tex1 = texCUBE(unity_SpecCube1, texcoord);
                float4 tex1 = UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube1, texcoord, 0.0);
                float3 probe1 = DecodeHDR(tex1, unity_SpecCube0_HDR);

		col = lerp(probe1, probe0, interpolator);
	    } else {
		col = probe0;
	    }
	    #else
	    col = probe0;
            #endif
            #endif

            return float4(col, 1);
        }

        // from https://gist.github.com/ishikawash/4648390
        // 'p' must be normalized
        float2 getUV(float3 p)
        {
	    // float phi = atan(p.y, p.x);
            float phi = atan2(p.y, p.x);
	    float theta = acos(p.z);
	    float s = phi*rcp(2*UNITY_PI);
	    float t = theta*rcp(UNITY_PI);
	    return float2(s, t);
        }

        // does not actually look like stars
        float4 stars2(float3 coord) 
        {
            float3 t = float3(0,0,_Time.x);

            float val = sampleCubeMap(coord);
            val = -clamp((1.0-pow(0.1/abs(val), .1)), -2, 0);
            
            float3 col = float3(val,val,val);
            return float4(col, 1);
        }

        interface ISDFObject {
            float SDF(float3 p);
            float4 GetColor(float3 dir, float3 normal, float2 uv);
        };

        float3 EstimateNormal(ISDFObject sdf, float3 p)
        {
            return normalize(float3(
                    sdf.SDF(float3((p).x + EPSILON, (p).y,           (p).z          )) - sdf.SDF(float3((p).x - EPSILON, (p).y,           (p).z          )),
                    sdf.SDF(float3((p).x,           (p).y + EPSILON, (p).z          )) - sdf.SDF(float3((p).x,           (p).y - EPSILON, (p).z          )),
                    sdf.SDF(float3((p).x,           (p).y,           (p).z + EPSILON)) - sdf.SDF(float3((p).x,           (p).y,           (p).z - EPSILON))
                ));
        }

/*
        float2 GetUV(SDFObject sdf, float3 p)
        {
            float3 newp = mul(transpose(sdf.R), p) + sdf.T;
            return getUV(newp);
        }
*/

        class BoxSDF : ISDFObject {
            float SDF(float3 p) {
                float3 myT = float3(sin(frac(_Time.y)*2*UNITY_PI), 0, cos(frac(_Time.y)*2*UNITY_PI))*10*_SceneScale;
                float3x3 myR = AngleAxis3x3(radians(AudioLinkGetChronotensity(0, 0)/1000.0 % 360.0), normalize(float3(1.0,_SinTime.y,_CosTime.y)));
                float2 cubeSize = float2((1+AudioLinkData(uint2(1,0)).r)*_SceneScale, AudioLinkData(uint2(0,0)).r*_SceneScale);
                return udRoundBox(mul(p - myT, myR), cubeSize.x, cubeSize.y);
            }

            float4 GetColor(float3 dir, float3 normal, float2 uv) {
                float4 texel = stars2(reflect(normal, dir));
                float4 col = texel + (normal.y / 2.0 - 0.2)/2;
                return col * float4(1,0,0,1);
            }
        };

        #define MOONSCALE 1
        class SphereSDF : ISDFObject {
            float SDF(float3 p) {
                float3 myT = float3(sin(frac(_Time.x)*2*UNITY_PI), 0, cos(frac(_Time.x)*2*UNITY_PI))*10*MOONSCALE*_SceneScale;
                return sphereSDF(p - myT, MOONSCALE*_SceneScale);
            }

            float4 GetColor(float3 dir, float3 normal, float2 uv) {
                float4 texel = sampleReflectionProbe(reflect(normal, dir));
                float4 col = texel + (normal.y / 2.0 - 0.2)/2;
                return col * float4(0,1,0,1);
            }
        };

        class SceneSDF : ISDFObject {
            BoxSDF box;
            SphereSDF sphere;
            float dist;
            float dist1;
            float dist2;

            float SDF(float3 p) {
                dist1 = box.SDF(p);
                dist2 = sphere.SDF(p);
                dist = min(dist1, dist2);
                return dist;
            }

            float4 GetColor(float3 dir, float3 normal, float2 uv) {
                if (dist == dist1) {
                    return box.GetColor(dir, normal, uv);
                } else {
                    return sphere.GetColor(dir, normal, uv);
                }
            }
        };

        float shortestDistanceToSurfaceWithColor(ISDFObject scene, float3 eye, float3 marchingDirection, float start, float end, out float4 col) {
            col = float4(1,1,1,1);
            float depth = start;

            float3 samplePoint;
            float dist;

            [loop]
            for (int i = 0; i < MAX_MARCHING_STEPS; i++) { 
                samplePoint = eye + depth * marchingDirection;

                dist = scene.SDF(samplePoint);

                if (dist < EPSILON) {
                    break;
                }

                depth += dist;
                if (depth >= end) {
                    break;
                }
            }

            if (dist < EPSILON) {
                float3 p = samplePoint + dist*marchingDirection;
                float3 normal = EstimateNormal(scene, p);
                col = scene.GetColor(marchingDirection, normal, float2(0,0));
            } else {
                if (i >= MAX_MARCHING_STEPS) {
                    depth = end;
                }
                col = stars2(marchingDirection);
            }
            
            return depth;
        }
        ENDCG

        Pass
        {
            Cull Back

            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_fog

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 ray_origin : TEXCOORD1;
                float3 vert_position : TEXCOORD2;
                float3 worldPos : TEXCOORD3;

                UNITY_FOG_COORDS(7)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert (appdata v)
            {
                v2f o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = v.uv;

                if (INOBJECTSPACE) {
                    o.ray_origin = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
                    o.vert_position = v.vertex;
                } else {
                    o.ray_origin = _WorldSpaceCameraPos;
                    o.vert_position = mul(unity_ObjectToWorld, v.vertex);
                }

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }
            
            float4 frag(v2f i, out float depth : SV_Depth) : SV_Target
            {
                float4 col = float4(0,0,0,1);

                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 ray_origin = i.ray_origin;
                float3 ray_direction = normalize(i.vert_position - i.ray_origin);

                float3x3 R = AngleAxis3x3(radians(_SceneRotationAngle), normalize(_SceneRotationAxis));
                float3 eye = mul(ray_origin + _SceneOffset, R);
                float3 worldDir = mul(ray_direction, R);

                SceneSDF sdf;
                float dist = shortestDistanceToSurfaceWithColor(sdf, eye, worldDir, MIN_DIST, MAX_DIST, col);

                // TODO: fold depth calculcation into the raymarching loop as well?
                // Output depth
                float4 clip_pos = mul(UNITY_MATRIX_VP, float4(i.worldPos, 1.0));
                float maxDepth = clip_pos.z / clip_pos.w;
                if (dist > MAX_DIST - EPSILON) {
                    depth = maxDepth;
                } else {
                    float3 p = eye + dist * worldDir;
                    p = mul(p, transpose(R)) - _SceneOffset; // undo rotation and offset for depth calculation
                    if (INOBJECTSPACE) {
                        clip_pos = UnityObjectToClipPos(p);
                    } else {
                        clip_pos = mul(UNITY_MATRIX_VP, float4(p, 1.0));
                    }
                    depth = max(clip_pos.z / clip_pos.w, maxDepth);
                }

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
