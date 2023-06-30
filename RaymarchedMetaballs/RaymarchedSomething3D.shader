// Based on https://www.shadertoy.com/view/XdBBzR

Shader "Xantoz/RaymarchedSomething3D"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 1
        _Tint ("Tint Color", Color) = (1, 1, 1, 1)
        [NoScaleOffset]_Tex ("Cubemap (HDR)", Cube) = "Cube" {}
        [Gamma] _Exposure ("Exposure", Range(0, 8)) = 0.5
        [NoScaleOffset]_MainTex ("Texture", 2D) = "white" {}
        [IntRange]_InObjectSpace ("Raymarch in Object space rather than world space", Range(0, 1)) = 1
        _SceneScale("Scene scale", Range(0,1)) = 0.04
        _SceneRotationAngle("Scene rotation angle", Range(-180,180)) = 0
        _SceneRotationAxis("Scene rotation axis", Vector) = (1,0,0)
        _SceneOffset("Scene offset", Vector) = (0,0,0)
        _K("k-factor", Float) = 0.7
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "DisableBatching"="True" }
        LOD 100
        Cull [_Cull]

        CGINCLUDE
            #include "UnityCG.cginc"
            #include "../cginc/AudioLinkFuncs.cginc"
            #include "../cginc/rotation.cginc"
        ENDCG

        Pass
        {
            // ZWrite Off
            // ZTest LEqual
            // ZTest Less
            // ZTest GEqual
            // ZTest Greater
            // ZClip false


            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_fog

            samplerCUBE _Tex;
            float4 _Tex_HDR;
            float4 _Tint;
            float _Exposure;
            sampler2D _MainTex;
            int _InObjectSpace;
            float _SceneScale;
            float _SceneRotationAngle;
            float3 _SceneRotationAxis;
            float3 _SceneOffset;

            float _K;

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

                UNITY_FOG_COORDS(2)
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

                if (_InObjectSpace) {
                    o.ray_origin = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
                    o.vert_position = v.vertex;
                } else {
                    o.ray_origin = _WorldSpaceCameraPos;
                    o.vert_position = mul(unity_ObjectToWorld, v.vertex);
                }

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            #define MAX_MARCHING_STEPS 64
            #define MIN_DIST 0.0
            #define MAX_DIST 100.0
            #define EPSILON 0.001


            #define TIME _Time.y
            // #define TIME 1

            /**
            * Signed distance function for a sphere centered at the origin with radius r.
            */
            float sphereSDF(float3 p, float r) {
                return length(p) - r;
            }

            float udRoundBox(float3 p, float3 b, float r) 
            {
                return length(max(abs(p)-b,0.0))-r;
            }


            // polynomial smooth min (k = 0.1);
            float smin(float a, float b, float k)
            {
                float h = clamp(0.5+0.5*(b-a)/k, 0.0, 1.0);
                return lerp(b, a, h) - k*h*(1.0-h);
            }

/*
            // from https://www.shadertoy.com/view/Mds3Rn
//            #define speed (_Time.x*0.2975)
            #define speed 0
            #define ground_x (1.0-0.325*sin(PI*speed*0.25))
            float ground_y=1.0;
            float ground_z=0.5;

            float tunnel(float3 p)
            {
                float tunnel_m=0.125*cos(UNITY_PI*p.z*1.0+speed*4.0-UNITY_PI);
                float tunnel1_p=2.0;
                float tunnel1_w=tunnel1_p*0.225;
                float tunnel1=length(mod(p.xy,tunnel1_p)-tunnel1_p*0.5)-tunnel1_w;	// tunnel1
                float tunnel2_p=2.0;
                float tunnel2_w=tunnel2_p*0.2125+tunnel2_p*0.0125*cos(UNITY_PI*p.y*8.0)+tunnel2_p*0.0125*cos(UNITY_PI*p.z*8.0);
                float tunnel2=length(mod(p.xy,tunnel2_p)-tunnel2_p*0.5)-tunnel2_w;	// tunnel2
                float hole1_p=1.0;
                float hole1_w=hole1_p*0.5;
                float hole1=length(mod(p.xz,hole1_p).xy-hole1_p*0.5)-hole1_w;	// hole1
                float hole2_p=0.25;
                float hole2_w=hole2_p*0.375;
                float hole2=length(mod(p.yz,hole2_p).xy-hole2_p*0.5)-hole2_w;	// hole2
                float hole3_p=0.5;
                float hole3_w=hole3_p*0.25+0.125*sin(UNITY_PI*p.z*2.0);
                float hole3=length(mod(p.xy,hole3_p).xy-hole3_p*0.5)-hole3_w;	// hole3
                float tube_m=0.075*sin(UNITY_PI*p.z*1.0);
                float tube_p=0.5+tube_m;
                float tube_w=tube_p*0.025+0.00125*cos(UNITY_PI*p.z*128.0);
                float tube=length(mod(p.xy,tube_p)-tube_p*0.5)-tube_w;			// tube
                float bubble_p=0.05;
                float bubble_w=bubble_p*0.5+0.025*cos(UNITY_PI*p.z*2.0);
                float bubble=length(mod(p.yz,bubble_p)-bubble_p*0.5)-bubble_w;	// bubble
                return max(min(min(-tunnel1,lerp(tunnel2,-bubble,0.375)),max(min(-hole1,hole2),-hole3)),-tube);
            }
*/

            float balls(float3 samplePoint)
            {
                // float t = TIME / 3.0 + 10500.0;
                float t = (AudioLinkGetChronotensity(5, 3)/100000.0 + AudioLinkGetChronotensity(0, 0)/100000.0) / 3.0 + 10500.0;

                float balls = MAX_DIST;
                for (float i = 1.0; i < 4.0*2; i += 1.3) {
                    float ballRadius = 1.0*(1+AudioLinkData(uint2(i % 4,0)).r);
                    for (float j = 1.0; j < 4.0*2; j += 1.3) {
                        float cost = cos(t * j);
                        balls = smin(balls, sphereSDF(samplePoint + float3(sin(t * i) * j, cost * i, cost * j)*_SceneScale, ballRadius*_SceneScale), _K*_SceneScale);
                    }
                }

                return balls;
            }

            // 
            /**
            * Signed distance function describing the scene.
            */
            float sceneSDF(float3 samplePoint)
            {
                // return min(balls(samplePoint), tunnel(samplePoint*10));
                // return tunnel(samplePoint);

                // return min(balls(samplePoint), udRoundBox(samplePoint, 0.1*_SceneScale, 0.1*_SceneScale));

                // return min(
                //     sphereSDF(
                //         samplePoint + float3(sin(frac(_Time.x)*2*UNITY_PI), 0, cos(frac(_Time.x)*2*UNITY_PI))*10*_SceneScale,
                //         1*_SceneScale),
                //     udRoundBox(samplePoint, (1+AudioLinkData(uint2(1,0)).r)*_SceneScale, AudioLinkData(uint2(0,0)).r*_SceneScale)
                // );

                return
                min(
                    balls(samplePoint+float3(0,0,-10)*_SceneScale),
                    min(
                        sphereSDF(
                            samplePoint + float3(sin(frac(_Time.x)*2*UNITY_PI), 0, cos(frac(_Time.x)*2*UNITY_PI))*10*_SceneScale,
                            1*_SceneScale),
                        udRoundBox(samplePoint, (1+AudioLinkData(uint2(1,0)).r)*_SceneScale, AudioLinkData(uint2(0,0)).r*_SceneScale)));


            }

            /**
            * Return the shortest distance from the eyepoint to the scene surface along
            * the marching direction. If no part of the surface is found between start and end,
            * return end.
            *
            * eye: the eye point, acting as the origin of the ray
            * marchingDirection: the normalized direction to march in
            * start: the starting distance away from the eye
            * end: the max distance away from the ey to march before giving up
            */
            float shortestDistanceToSurface(float3 eye, float3 marchingDirection, float start, float end) {
                float depth = start;
                for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
                    float dist = sceneSDF(eye + depth * marchingDirection);
                    if (dist < EPSILON) {
                        return depth;
                    }
                    depth += dist;
                    if (depth >= end) {
                        return end;
                    }
                }
                return end;
            }

            float3 rayDirection(float fieldOfView, float2 size, float2 fragCoord) {
                float2 xy = fragCoord - size / 2.0;
                float z = size.y / tan(radians(fieldOfView) / 2.0);
                return normalize(float3(xy, -z));
            }

            /**
            * Using the gradient of the SDF, estimate the normal on the surface at point p.
            */
            float3 estimateNormal(float3 p) {
                return normalize(float3(
                        sceneSDF(float3(p.x + EPSILON, p.y, p.z)) - sceneSDF(float3(p.x - EPSILON, p.y, p.z)),
                        sceneSDF(float3(p.x, p.y + EPSILON, p.z)) - sceneSDF(float3(p.x, p.y - EPSILON, p.z)),
                        sceneSDF(float3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(float3(p.x, p.y, p.z - EPSILON))
                    ));
            }

            float3x3 viewMatrix(float3 eye, float3 center, float3 up) {
                // Based on gluLookAt man page
                float3 f = normalize(center - eye);
                float3 s = normalize(cross(f, up));
                float3 u = cross(s, f);
                return float3x3(s, u, -f);
            }

            float4 sampleCubeMap(float3 texcoord)
            {
                float4 tex = texCUBE(_Tex, texcoord);
                float3 c = DecodeHDR(tex, _Tex_HDR);
                c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
                c *= _Exposure;
                return float4(c, 1);
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

            float4 frag(v2f i, out float depth : SV_Depth) : SV_Target
            // float4 frag (v2f i, out float depth : SV_DepthLessEqual) : SV_Target
            // float4 frag (v2f i, out float depth : SV_DepthGreaterEqual) : SV_Target
            {
                float4 col = 0.0f;


                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 ray_origin = i.ray_origin;
                float3 ray_direction = normalize(i.vert_position - i.ray_origin);

                float3x3 R = AngleAxis3x3(radians(_SceneRotationAngle), normalize(_SceneRotationAxis));
                float3 eye = mul(ray_origin + _SceneOffset, R);
                float3 worldDir = mul(ray_direction, R);
                float dist = shortestDistanceToSurface(eye, worldDir, MIN_DIST, MAX_DIST);

                float4 clip_pos = mul(UNITY_MATRIX_VP, float4(i.worldPos, 1.0));
                float maxDepth = clip_pos.z / clip_pos.w;

                if (dist > MAX_DIST - EPSILON) {
                    // discard;
                    col = sampleCubeMap(worldDir);
                    depth = maxDepth;
                    return col;
                }

                /*
                float3 p = eye + dist * worldDir;
                float3 normal = estimateNormal(p);
                float4 tex = sampleCubeMap(reflect(worldDir, normal));
                col = (tex  + (normal.y / 2.0 - 0.2)) * float4(1.0, 0.8, 0.6, 1.0);
                */

                float3 p = eye + dist * worldDir;
                float3 normal = estimateNormal(p);
                float2 uv = getUV(normalize(p));
                col = tex2D(_MainTex, uv) + (normal.y / 2.0 - 0.2);

                // Output depth
                // undo rotation and offset for depth calculation
                p = mul(p, transpose(R)) - _SceneOffset;
                if (_InObjectSpace) {
                    clip_pos = UnityObjectToClipPos(p);
                } else {
                    clip_pos = mul(UNITY_MATRIX_VP, float4(p, 1.0));
                }
                depth = max(clip_pos.z / clip_pos.w, maxDepth);

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
