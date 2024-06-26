Shader "Xantoz/RaymarchedPalmTree"
{
    Properties
    {
        [NoScaleOffset]_Tex ("Cubemap (HDR)", Cube) = "Cube" {}
        [Gamma] _Exposure ("Exposure", Range(0, 8)) = 0.5
        _TexTint ("Tint Color", Color) = (1, 1, 1, 1)

        [NoScaleOffset]_2DTex ("Texture", 2D) = "white" {}
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
        #define MAX_DIST (100.0*10)
        #define EPSILON (0.001*10)
        #define INOBJECTSPACE true

        #include "UnityCG.cginc"
        #include "../cginc/AudioLinkFuncs.cginc"
        #include "../cginc/rotation.cginc"

        // Currently we expect a single-channel cubemap in here
        TextureCube<float> _Tex;
        SamplerState sampler_Tex;
        float4 _Tex_HDR;
        float4 _TexTint;
        float _Exposure;
        Texture2D<float4> _2DTex;
        SamplerState sampler_2DTex;
        Texture2D<float> _NoiseTex;
        SamplerState sampler_NoiseTex;

        float _SceneScale;
        float _SceneRotationAngle;
        float3 _SceneRotationAxis;
        float3 _SceneOffset;

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
            ISDFObject Next();
            ISDFObject Next2();
            ISDFObject Next3();
	    ISDFObject Next4();
	    ISDFObject Next5();
	    ISDFObject Next6();
	    ISDFObject Next7();
	    ISDFObject Next8();
            float SDF(float3 p);
            float4 GetColor(float3 p, float3 dir, float3 normal);
        };

        class SDFObjectBase : ISDFObject {
            // The code in all methods will never be used. It is only used to declare this class
            ISDFObject Next() { SDFObjectBase base; return base; }
            ISDFObject Next2() { SDFObjectBase base; return base; }
            ISDFObject Next3() { SDFObjectBase base; return base; }
            ISDFObject Next4() { SDFObjectBase base; return base; }
            ISDFObject Next5() { SDFObjectBase base; return base; }
            ISDFObject Next6() { SDFObjectBase base; return base; }
            ISDFObject Next7() { SDFObjectBase base; return base; }
            ISDFObject Next8() { SDFObjectBase base; return base; }

            float SDF(float3 p) { return sphereSDF(p, 0.1); }
            float4 GetColor(float3 p, float3 dir, float3 normal) { return float4(1,0,1,1); }
        };

        #define estimateNormal(fn, p) \
        normalize(float3( \
                fn(float3((p).x + EPSILON, (p).y,           (p).z          )) - fn(float3((p).x - EPSILON, (p).y,           (p).z          )), \
                fn(float3((p).x,           (p).y + EPSILON, (p).z          )) - fn(float3((p).x,           (p).y - EPSILON, (p).z          )), \
                fn(float3((p).x,           (p).y,           (p).z + EPSILON)) - fn(float3((p).x,           (p).y,           (p).z - EPSILON)) \
            ));

        float3 EstimateNormal(ISDFObject sdf, float3 p)
        {
            return estimateNormal(sdf.SDF, p);
        }

        #define MERGE(a,b) a##b

        class RotateSDF : SDFObjectBase {
            float3x3 R;

            float SDF(float3 p) {
                return Next().SDF(mul(p, R));
            }

            float4 GetColor(float3 p, float3 dir, float3 normal) {
                // We unrotate the point only (potentially used for UV)
                return Next().GetColor(mul(transpose(R), p), dir, normal);
            }
        };

        #define MAKE_RotateSDF(name, rot, from) \
        class MERGE(RotateSDF_, __LINE__) : RotateSDF { ISDFObject Next() { return (from); } } name; \
        name.R = (rot)

        class TranslateSDF : SDFObjectBase {
            float3 T;

            float SDF(float3 p) {
                return Next().SDF(p - T);
            }

            float4 GetColor(float3 p, float3 dir, float3 normal) {
                // We untranslate the point only (potentially used for UV)
                return Next().GetColor(p - T, dir, normal);
            }
        };

        #define MAKE_TranslateSDF(name, translate, from) \
        class MERGE(TranslateSDF_, __LINE__) : TranslateSDF { ISDFObject Next() { return (from); } } name; \
        name.T = (translate)

        class MinSDF : SDFObjectBase {
            float dist;
            float dist1;
            float dist2;

            float SDF(float3 p) {
                dist1 = Next().SDF(p);
                dist2 = Next2().SDF(p);
                dist = min(dist1, dist2);
                return dist;
            }

            float4 GetColor(float3 p, float3 dir, float3 normal) {
                if (dist == dist1) {
                    return Next().GetColor(p, dir, normal);
                } else {
                    return Next2().GetColor(p, dir, normal);
                }
            }

            static ISDFObject New(ISDFObject from1, ISDFObject from2) {
                class LocalSDFObject : MinSDF {
                    ISDFObject Next() { return from1; }
                    ISDFObject Next2() { return from2; }
                } obj;
                return obj;
            }
        };

        class MinSDF3 : SDFObjectBase {
            float dist, dist1, dist2, dist3;

            float SDF(float3 p) {
                dist1 = Next().SDF(p);
                dist2 = Next2().SDF(p);
                dist3 = Next3().SDF(p);
                dist = min(min(dist1, dist2), dist3);
                return dist;
            }

            float4 GetColor(float3 p, float3 dir, float3 normal) {
                if (dist == dist1) {
                    return Next().GetColor(p, dir, normal);
                } else if (dist == dist2) {
                    return Next2().GetColor(p, dir, normal);
                } else {
                    return Next3().GetColor(p, dir, normal);
                }
            }

            static ISDFObject New(ISDFObject from1, ISDFObject from2, ISDFObject from3) {
                class LocalSDFObject : MinSDF3 {
                    ISDFObject Next() { return from1; }
                    ISDFObject Next2() { return from2; }
                    ISDFObject Next3() { return from3; }
                } obj;
                return obj;
            }
        };

        class MinSDF4 : SDFObjectBase {
            float dist, dist1, dist2, dist3, dist4;

            float SDF(float3 p) {
                dist1 = Next().SDF(p);
                dist2 = Next2().SDF(p);
                dist3 = Next3().SDF(p);
                dist4 = Next4().SDF(p);
                dist = min(min(dist1, dist2), min(dist3, dist4));
                return dist;
            }

            float4 GetColor(float3 p, float3 dir, float3 normal) {
                if (dist == dist1) {
                    return Next().GetColor(p, dir, normal);
                } else if (dist == dist2) {
                    return Next2().GetColor(p, dir, normal);
                } else if (dist == dist3) {
                    return Next3().GetColor(p, dir, normal);
                } else {
                    return Next4().GetColor(p, dir, normal);
                }
            }

            static ISDFObject New(ISDFObject from1, ISDFObject from2, ISDFObject from3, ISDFObject from4) {
                class LocalSDFObject : MinSDF4 {
                    ISDFObject Next() { return from1; }
                    ISDFObject Next2() { return from2; }
                    ISDFObject Next3() { return from3; }
                    ISDFObject Next4() { return from4; }
                } obj;
                return obj;
            }
        };

        class BoxSDF : SDFObjectBase {
            float4 tint;

            float SDF(float3 p) {
/*
                float3 myT = -float3(sin(frac(_Time.x)*4*UNITY_PI), 0, cos(frac(_Time.x)*4*UNITY_PI))*10;
                float3x3 myR = AngleAxis3x3(radians(AudioLinkGetChronotensity(0, 0)/1000.0 % 360.0), normalize(float3(1.0,_SinTime.y,_CosTime.y)));
                float2 cubeSize = float2((1+AudioLinkData(uint2(1,0)).r), AudioLinkData(uint2(0,0)).r);
                return udRoundBox(mul(p - myT, myR), cubeSize.x, cubeSize.y);
*/
                float2 cubeSize = float2((1+AudioLinkData(uint2(1,0)).r), AudioLinkData(uint2(0,0)).r);
                return udRoundBox(p, cubeSize.x, cubeSize.y);
            }

            float4 GetColor(float3 p, float3 dir, float3 normal) {
                float2 uv = getUV(p*0.5)/2 + .5;
                // float4 texel = stars2(reflect(dir, normal)) + 0.2;
                // float4 texel = stars2(reflect(dir, normal));
                float4 texel = sampleReflectionProbe(reflect(dir, normal));
                float4 texel2 = _2DTex.Sample(sampler_2DTex, uv);
                float4 col = texel + (normal.y / 2.0 - 0.2)/2;
                return (col + texel2)*tint;
            }

            static BoxSDF New() {
                BoxSDF obj;
                obj.tint = float4(1,.2,.5,1);
                return obj;
            }

            static BoxSDF New(float4 mytint) {
                BoxSDF obj;
                obj.tint = mytint;
                return obj;
            }
        };

        #define MOONSCALE 2
        class SphereSDF : SDFObjectBase {
            float3 myT;

            float SDF(float3 p) {
                myT = float3(sin(frac(_Time.x)*2*UNITY_PI), 0, cos(frac(_Time.x)*2*UNITY_PI))*10*MOONSCALE;
                return sphereSDF(p - myT, MOONSCALE);
            }

            float4 GetColor(float3 p, float3 dir, float3 normal) {
                float4 blue = float4(0,0,1,0);
                // float2 uv = getUV(p);
                // float4 texel1 = _NoiseTex.Sample(sampler_NoiseTex, uv) * float4(0,1,0,1)*5;

                float4 texel1 = stars2(reflect(dir, normal)) * float4(0,1,0,1);
                float texel2 = sampleCubeMap(reflect(dir, normal));

                float4 col = blue + texel1 + texel2 + (normal.y / 2.0 - 0.2)/2;
                return col;
            }

            static SphereSDF New() {
                SphereSDF obj;
                return obj;
            }
        };

        class SceneSDF : SDFObjectBase {
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

            float4 GetColor(float3 p, float3 dir, float3 normal) {
                if (dist == dist1) {
                    return box.GetColor(p, dir, normal);
                } else {
                    return sphere.GetColor(p, dir, normal);
                }
            }

            static ISDFObject New() {
                SceneSDF obj;
                return obj;
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
                col = scene.GetColor(p, marchingDirection, normal);
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
                float3 eye = mul(ray_origin/_SceneScale + _SceneOffset, R);
                float3 worldDir = mul(ray_direction, R);

                SphereSDF sphere = SphereSDF::New();
                BoxSDF box1 = BoxSDF::New(float4(1,1,.2,1));
                BoxSDF box2 = BoxSDF::New(float4(0,1,1,1));
                BoxSDF box3 = BoxSDF::New();

                MAKE_TranslateSDF(boxTranslate,
                    float3(sin(frac(_Time.x)*10*UNITY_PI), 0, cos(frac(_Time.x)*10*UNITY_PI))*10,
                    box1
                );

                MAKE_RotateSDF(boxRotate,
                    AngleAxis3x3(radians(AudioLinkGetChronotensity(0, 0)/1000.0 % 360.0), normalize(float3(1.0,_SinTime.y,_CosTime.y))),
                    box2
                );

                MAKE_TranslateSDF(boxTranslate2,
                    -float3(sin(frac(_Time.x)*4*UNITY_PI), 0, cos(frac(_Time.x)*4*UNITY_PI))*10,
                    box3
                );

                MAKE_RotateSDF(boxTranslateRotate,
                    AngleAxis3x3(radians(AudioLinkGetChronotensity(0, 0)/1000.0 % 360.0), normalize(float3(1.0,_SinTime.y,_CosTime.y))),
                    boxTranslate2
                );

                ISDFObject sdf = MinSDF4::New(
                    sphere,
                    boxTranslate,
                    boxRotate,
                    boxTranslateRotate
                );

                float dist = shortestDistanceToSurfaceWithColor(sdf, eye, worldDir, MIN_DIST, MAX_DIST, col);
                // float dist = shortestDistanceToSurfaceWithColor(sphere, eye, worldDir, MIN_DIST, MAX_DIST, col);


                // TODO: fold depth calculcation into the raymarching loop as well?
                // Output depth
                float4 clip_pos = mul(UNITY_MATRIX_VP, float4(i.worldPos, 1.0));
                float maxDepth = clip_pos.z / clip_pos.w;
                if (dist > MAX_DIST - EPSILON) {
                    depth = maxDepth;
                } else {
                    float3 p = eye + dist * worldDir;
                    p = (mul(p, transpose(R)) - _SceneOffset)*_SceneScale; // undo rotation and offset for depth calculation
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
