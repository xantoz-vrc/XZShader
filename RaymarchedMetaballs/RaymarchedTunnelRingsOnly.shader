Shader "Xantoz/RaymarchedTunnel"
{
    Properties
    {
        _Tint ("Tint Color", Color) = (1, 1, 1, 1)
        [NoScaleOffset]_Tex ("Cubemap (HDR)", Cube) = "Cube" {}
        [NoScaleOffset]_Tex2 ("Cubemap2 (HDR)", Cube) = "Cube" {}
        [Gamma] _Exposure ("Exposure", Range(0, 8)) = 0.5
        [NoScaleOffset]_MainTex ("Texture", 2D) = "white" {}
        [NoScaleOffset]_MainTex2 ("Texture 2", 2D) = "white" {}
        [IntRange]_InObjectSpace ("Raymarch in Object space rather than world space", Range(0, 1)) = 1
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
        #include "UnityCG.cginc"
        #include "../cginc/AudioLinkFuncs.cginc"
        #include "../cginc/rotation.cginc"

        samplerCUBE _Tex;
        float4 _Tex_HDR;
        TextureCube<float> _Tex2;
        SamplerState sampler_Tex2;
        float4 _Tex2_HDR;
        float4 _Tint;
        float _Exposure;
        sampler2D _MainTex;
        sampler2D _MainTex2;
        int _InObjectSpace;
        float _SceneScale;
        float _SceneRotationAngle;
        float3 _SceneRotationAxis;
        float3 _SceneOffset;

        float _K;


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


        #define estimateNormal(fn, p) \
        normalize(float3( \
                fn(float3((p).x + EPSILON, (p).y,           (p).z          )) - fn(float3((p).x - EPSILON, (p).y,           (p).z          )), \
                fn(float3((p).x,           (p).y + EPSILON, (p).z          )) - fn(float3((p).x,           (p).y - EPSILON, (p).z          )), \
                fn(float3((p).x,           (p).y,           (p).z + EPSILON)) - fn(float3((p).x,           (p).y,           (p).z - EPSILON)) \
            ));

        float4 sampleCubeMap(float3 texcoord)
        {
            float4 tex = texCUBE(_Tex, texcoord);
            float3 c = DecodeHDR(tex, _Tex_HDR);
            c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
            c *= _Exposure;
            return float4(c, 1);
        }

        float sampleCubeMap2(float3 texcoord)
        {
            float tex = _Tex2.Sample(sampler_Tex2, texcoord);
            float3 c = DecodeHDR(tex, _Tex2_HDR);
            c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
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

        float linefn(float val)
        {
            return val = -clamp((1.0-pow(0.1/abs(val), .1)), -2, 0);
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
        float4 stars(float3 coord) {
            /*
            const int nsamples = 2000;
            float angle = atan2(coord.x, coord.y);
            float pcm_val = PCMConditional(AudioLinkPCMLerpMirror(((angle+UNITY_PI)/(2*UNITY_PI))*nsamples*2, nsamples), 0);
            float val = simplex3d_fractal(coord+t) + pcm_val/10;
            */
            
            float3 t = float3(0,0,_Time.x);

            float val = simplex3d_fractal(coord+t);
            val = -clamp((1.0-pow(0.1/abs(val), .1)), -2, 0);

            float3 col = float3(val,val,val);
            return float4(col, 1);
        }

        // does not actually look like stars
        float4 stars2(float3 coord) {
            /*
            const int nsamples = 2000;
            float angle = atan2(coord.x, coord.y);
            float pcm_val = PCMConditional(AudioLinkPCMLerpMirror(((angle+UNITY_PI)/(2*UNITY_PI))*nsamples*2, nsamples), 0);
            float val = simplex3d_fractal(coord+t) + pcm_val/10;
            */

            float3 t = float3(0,0,_Time.x);

            float val = sampleCubeMap2(coord);
            val = -clamp((1.0-pow(0.1/abs(val), .1)), -2, 0);
            
            float3 col = float3(val,val,val);
            return float4(col, 1);
        }

        bool isInside(float3 p) {
            return length(p) <= 0.5;
        }

        ENDCG

/*
        // Stancil pass to avoid things poking out where they shouldn't
        Pass
        {
            Cull Front
            ZTest Always

            // Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
            Tags { "Queue"="AlphaTest+50" }

            // Blend Zero One

            // All pixels in this Pass will pass the stencil test and write a value of 2 to the stencil buffer
            // You would typically do this if you wanted to prevent subsequent shaders from drawing to this area of the render target or restrict them to render to this area only
            Stencil
            {
                Ref 2
                Comp Always
                Pass Replace
            }            

            ColorMask 0

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 vertexNormal : NORMAL_nointerpolation;
            };

            v2f vert (appdata v)
            {
                v2f o;
                // v.vertex.xyz -= 1*v.normal;
                // v.vertex.xyz -= 0.1*v.normal;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.vertexNormal = v.normal;
                
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Stupid hack to make it so we can see in from the top
                if (length(float3(0,0,-1) - normalize(i.vertexNormal)) < 0.1) {
                    discard;
                }

                // sample the texture
                fixed4 col = fixed4(0,1,0,1);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
*/

        Pass
        {
            //Cull Off
            Cull Front
/*
            Stencil
            {
                Ref 2
                Comp NotEqual
            }
*/

            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma multi_compile_local __ _DEPTHWRITE_ON

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                
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

            #define MAX_MARCHING_STEPS 128
            #define MIN_DIST 0.0
            #define MAX_DIST 100.0
            #define EPSILON 0.001

            float sceneSDF(float3 samplePoint);

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

            /*
            float shortestDistanceToBalls(float3 eye, float3 T, float3 marchingDirection, float start, float end) {
                float depth = start;
                for (int i = 0; i < 8; i++) {
                    float dist = balls(eye + depth * marchingDirection + T);
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
            */

            float sceneTorus(float3 samplePoint)
            {
                // sample point scaled 
                float3 sps = samplePoint*_SceneScale;

                // float nois = simplex3d(float3(samplePoint.z, samplePoint.z, samplePoint.z))*0.1;

                const float3 anchor = float3(-5*_SinTime.y,-10*_CosTime.y,4);

                float bump = AudioLinkData(uint2(1, sps.z/10 % 128)).r;

                // float2 ba = float2(UNITY_PI,UNITY_PI)/2;
                float2 ba = float2(_Time.y+sps.z, _Time.y-sps.z*2);
                float2 bend = float2(sin(ba.x), cos(ba.y))*_SceneScale*13;
                bend = lerp(anchor.xy, bend, clamp(anchor.z - sps.z, 0, 1));
                bend.y += bump;
                bend = lerp(float2(0,0), bend, clamp(abs(sps.z), 0, 1));

                // float3x3 R0 = rotateY(radians(45+_Time.y*180));
                float3x3 R0 = rotateY(radians(AudioLinkGetChronoTimeNormalized(0,2,.1)*360));
                float3x3 R1 = rotateX(radians(-90));
                float3x3 R = mul(R0,R1);

                float forward = _Time.y/2;
                float3 T = float3(bend.x, bend.y, frac(forward)*UNITY_PI*2);
                float3 p = mul(R, samplePoint + T);

                // Repeating!
                p.y = sin(p.y);

                const int nsamples = 256 - 32;
                float angle = atan2(p.x, p.z);
                float dft_val = AudioLinkDFTLerpMirror((angle)/(2*UNITY_PI)*(nsamples-1)*2, nsamples).r*5;

                float t = .9;
                // float t = _Time.y;
                // float t = AudioLinkGetChronotensity(3, 0)/100000.0;
                // float t = AudioLinkGetChronoTimeNormalized(7, 0, .1);

                // const float basicRadius = 1;
                // const float basicThickness = 1.0/3.0;
                const float basicRadius = 6;
                const float basicThickness = 2;

                return sdgTorus(p, _SceneScale*(basicRadius+ frac(t)*basicRadius*4), (basicThickness + dft_val)*_SceneScale);
            }

            float sceneWonkyTorus(float3 samplePoint)
            {
                float3 sp = samplePoint;

                float a = simplex3d(sp);
                sp.xy = a;
                // float3 a = random3(samplePoint);;
                // samplePoint.xyz += a/10;

                sp.z = sin(sp.z);
                float3x3 R = AngleAxis3x3(radians(-74), float3(1, 0, 0));
                float3 p = mul(R, sp);

                return sdgTorus(sp, _SceneScale*(1+ frac(_Time.y)*3), _SceneScale/3) - sphereSDF(samplePoint, 100*_SceneScale);
            }

/*            
            float sceneStars(float3 samplePoint)
            {
                float3 T = float3(5,10,1);
                float3 p = samplePoint + T;

                float3 pWonk = simplex3d_fractal(p/10);

                return sphereSDF(pWonk, _SceneScale) + sphereSDF(p, 10*_SceneScale);
            }
*/

            /**
            * Signed distance function describing the scene.
            */
            float sceneSDF(float3 samplePoint)
            {
                // return min(sceneTorus(samplePoint), sceneWonkyTorus(samplePoint));
                return sceneTorus(samplePoint);
                // return min(sceneTorus(samplePoint), sceneStars(samplePoint));
            }

#if _DEPTHWRITE_ON
            // float4 frag(v2f i, out float depth : SV_DepthLessEqual) : SV_Target
            float4 frag(v2f i, out float depth : SV_Depth, fixed facing : VFACE) : SV_Target
#else
            float4 frag(v2f i) : SV_Target
#endif
            {
                float4 col = 0.0f;

                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 ray_origin = i.ray_origin;
                float3 ray_direction = normalize(i.vert_position - i.ray_origin);

                float3x3 R = AngleAxis3x3(radians(_SceneRotationAngle), normalize(_SceneRotationAxis));
                float3 eye = mul(ray_origin + _SceneOffset, R);
                float3 worldDir = mul(ray_direction, R);
                float dist = shortestDistanceToSurface(eye, worldDir, MIN_DIST, MAX_DIST);

#if _DEPTHWRITE_ON
                float cameraInObjectSpace = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
                float4 clip_pos = mul(UNITY_MATRIX_VP, float4(i.worldPos, 1.0));
                float mDepth = clip_pos.z / clip_pos.w;
#endif

                if (dist > MAX_DIST - EPSILON) {
                    // discard;
                    // col = sampleCubeMap(worldDir)*0.1;

                    col = stars2(worldDir);
                    if (isInside(cameraInObjectSpace)) { col.r = .5; }

                    // col = stars(worldDir);

#if _DEPTHWRITE_ON
/*
                    if (facing > 0) {
                        discard;
                        //depth = mDepth;
                    } else {
                        depth = mDepth;
                    }
*/
                    depth = isInside(cameraInObjectSpace) ? 0 : mDepth;
#endif
                    return col;
                }

                float3 p = eye + dist * worldDir;
                float3 normal = estimateNormal(sceneSDF, p);
                float4 tex = sampleCubeMap(reflect(worldDir, normal));
                // float4 tex = stars(reflect(worldDir, normal));
                // float4 tex = stars2(reflect(worldDir, normal));

                col = (tex + (normal.y / 2.0 - 0.2)) * float4(1.0, 0.8, 0.6, 1.0);

#if _DEPTHWRITE_ON
                // Output depth
                
                float3 p0 = mul(p, transpose(R)) - _SceneOffset; // undo rotation and offset for depth calculation
                clip_pos = (_InObjectSpace) ? UnityObjectToClipPos(p0) : mul(UNITY_MATRIX_VP, float4(p0, 1.0));
                float rmDepth = clip_pos.z / clip_pos.w;
                if (isInside(cameraInObjectSpace)) {
                    depth = rmDepth;
                    //depth = max(rmDepth, mDepth);
                } else {
                    //depth = mDepth;
                    depth = isInside(p0) ? rmDepth : mDepth;
                    //depth = rmDepth;
/*
                    if (facing > 0) {
                        depth = min(rmDepth, mDepth);
                    } else {
                        depth = max(rmDepth, mDepth);
                    }
*/
                }
#endif
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
/*
        Pass
        {
            Cull Front
            // Blend One Zero
            // ZTest Less

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

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;

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

            #define MAX_MARCHING_STEPS 128
            #define MIN_DIST 0.0
            #define MAX_DIST 100.0
            #define EPSILON 0.001


            #define TIME _Time.y
            // #define TIME 1

            float sceneSDF(float3 samplePoint);


            // #define BALLMULT 2
            #define BALLMULT 1
            float balls(float3 samplePoint)
            {
                // float t = TIME / 3.0 + 10500.0;
                float t = (AudioLinkGetChronotensity(5, 3)/100000.0 + AudioLinkGetChronotensity(0, 0)/100000.0) / 3.0 + 10500.0;

                float balls = MAX_DIST;
                for (float i = 1.0; i < 4.0*BALLMULT; i += 1.3) {
                    float ballRadius = 1.0*(1+AudioLinkData(uint2(i, 0)).r);
                    for (float j = 1.0; j < 4.0*BALLMULT; j += 1.3) {
                        float cost = cos(t * j);
                        balls = smin(balls, sphereSDF(samplePoint + float3(sin(t * i) * j, cost * i, cost * j)*_SceneScale, ballRadius*_SceneScale), _K*_SceneScale);
                        // balls = min(balls, sphereSDF(samplePoint + float3(sin(t * i) * j, cost * i, cost * j)*_SceneScale, ballRadius*_SceneScale));
                    }
                }

                return balls;
            }

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

            float shortestDistanceToBalls(float3 eye, float3 T, float3 marchingDirection, float start, float end) {
                float depth = start;
                for (int i = 0; i < 8; i++) {
                    float dist = balls(eye + depth * marchingDirection + T);
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


            #define MOONSCALE 1

            float sceneSDF(float3 samplePoint)
            {
                float3 metaballsT = float3(_CosTime.z*3,_SinTime.y*10,-10)*_SceneScale;

                float3 sphereT = float3(sin(frac(_Time.x)*2*UNITY_PI), 0, cos(frac(_Time.x)*2*UNITY_PI))*10*_SceneScale*MOONSCALE;

                return min(balls(samplePoint+metaballsT), sphereSDF(samplePoint + sphereT, 1*_SceneScale*MOONSCALE));
            }

            float4 shortestDistanceToSurfaceWithColor(float3 eye, float3 marchingDirection, float start, float end)
            {
                float depth = start;

                float3 metaballsT = float3(_CosTime.z*3,_SinTime.y*10,-10)*_SceneScale;

                float3 sphereT = float3(sin(frac(_Time.x)*2*UNITY_PI), 0, cos(frac(_Time.x)*2*UNITY_PI))*10*_SceneScale*MOONSCALE;

                float3x3 cubeR = AngleAxis3x3(radians(AudioLinkGetChronotensity(0, 0)/1000.0 % 360.0), normalize(float3(1.0,_SinTime.y,_CosTime.y)));
                float2 cubeSize = float2((1+AudioLinkData(uint2(1,0)).r)*_SceneScale, AudioLinkData(uint2(0,0)).r*_SceneScale);

                float3 bgCol = sampleCubeMap(marchingDirection).rgb;

                [loop]
                for (int i = 0; i < MAX_MARCHING_STEPS; i++) {
                    float3 samplePoint = eye + depth * marchingDirection;

                    float metaballs = balls(samplePoint+metaballsT);

                    float sphere = sphereSDF(samplePoint + sphereT, MOONSCALE*_SceneScale);
                    float dist = min(metaballs, sphere);
                    
                    if (dist < EPSILON) {
                        //float3 p = eye + depth*marchingDirection;
                        float3 p = samplePoint + dist*marchingDirection;
                        float3 normal = estimateNormal(sceneSDF, p);

                        // float3 metaballsP = eye + (depth+metaballs) * marchingDirection;
                        float3 metaballsP = (samplePoint+metaballsT) + metaballs*marchingDirection;
                        float3 metaballsNormal = estimateNormal(balls, metaballsP);
                        // float4 metaballsTex = sampleCubeMap(reflect(marchingDirection, metaballsNormal));
                        // float4 metaballsTex = sampleReflectionProbe(reflect(marchingDirection, metaballsNormal));
                        float4 metaballsTex = sampleCubeMap2(reflect(marchingDirection, metaballsNormal))*float4(1.5,1.0,0.1,1);
                        // float4 metaballsTex = stars2(reflect(marchingDirection, metaballsNormal));

                        float4 metaballsCol = (metaballsTex  + (metaballsNormal.y / 2.0 - 0.2)/2) * float4(1.0, 0.8, 0.6, 1.0);

                        if (dist == metaballs) {
                            p = p + metaballsT;
                            float2 uv = getUV(normalize(p));
                            float4 texel = tex2D(_MainTex, uv);
                            float4 texel2 = tex2D(_MainTex2, uv);
                            // float3 col = metaballsCol.rgb + texel.rgb*texel.a;
                            float3 col = metaballsCol.rgb*(1-texel.a) + (texel.rgb*texel.a + texel2.rgb*(1-texel.a));
                            // float3 col = metaballsCol.rgb;
                            return float4(col, depth);
                        } else {
                            p = p + sphereT;
                            float2 uv = getUV(normalize(p));
                            float4 texel = tex2D(_MainTex, uv);
                            float4 texel2 = tex2D(_MainTex2, uv);
                            float3 col = texel.rgb + (texel2.rgb + (normal.y / 2.0 - 0.2)/2)*(1-texel.a);
                            return float4(col, depth);
                        }
                    }

                    depth += dist;
                    if (depth >= end) {
                        return float4(bgCol, depth);
                    }
                }

                return float4(bgCol, end);
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

                float4 colorDist = shortestDistanceToSurfaceWithColor(eye, worldDir, MIN_DIST, MAX_DIST);
                col.rgb = colorDist.rgb;
                float dist = colorDist.a;

                // TODO: fold depth calculcation into the raymarching loop as well?
                // Output depth
                float4 clip_pos = mul(UNITY_MATRIX_VP, float4(i.worldPos, 1.0));
                float maxDepth = clip_pos.z / clip_pos.w;
                if (dist > MAX_DIST - EPSILON) {
                    discard;
                    // depth = maxDepth;
                } else {
                    float3 p = eye + dist * worldDir;
                    p = mul(p, transpose(R)) - _SceneOffset; // undo rotation and offset for depth calculation
                    if (_InObjectSpace) {
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
        
        // One pass for the transparent cube (I could do it all inside one pass if I relly felt like it I guess)
        Pass
        {
            Cull Front


            // Blend SrcAlpha OneMinusSrcAlpha
            // Blend One One
            // Blend One OneMinusDstColor
            Blend One DstColor
            // Blend SrcAlpha OneMinusDstColor

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

            #define MAX_MARCHING_STEPS 128
            #define MIN_DIST 0.0
            #define MAX_DIST 100.0
            #define EPSILON 0.001

            #define MOONSCALE 1

            float cube(float3 samplePoint)
            {
                float3x3 cubeR = AngleAxis3x3(radians(AudioLinkGetChronotensity(0, 0)/1000.0 % 360.0), normalize(float3(1.0,_SinTime.y,_CosTime.y)));
                float2 cubeSize = float2((1+AudioLinkData(uint2(1,0)).r)*_SceneScale, AudioLinkData(uint2(0,0)).r*_SceneScale);

                return udRoundBox(mul(samplePoint, cubeR), cubeSize.x, cubeSize.y);
            }

            float shortestDistanceToSurfaceWithColor(float3 eye, float3 marchingDirection, float start, float end, out float4 col)
            {
                col = float4(0,0,0,0);
                float depth = start;

                float3x3 cubeR = AngleAxis3x3(radians(AudioLinkGetChronotensity(0, 0)/1000.0 % 360.0), normalize(float3(1.0,_SinTime.y,_CosTime.y)));
                float2 cubeSize = float2((1+AudioLinkData(uint2(1,0)).r)*_SceneScale, AudioLinkData(uint2(0,0)).r*_SceneScale);

                [loop]
                for (int i = 0; i < MAX_MARCHING_STEPS; i++) { 
                    float3 samplePoint = eye + depth * marchingDirection;
                    float dist = udRoundBox(mul(samplePoint, cubeR), cubeSize.x, cubeSize.y);

                    if (dist < EPSILON) {
                        //float3 p = eye + depth*marchingDirection;
                        float3 p = samplePoint + dist*marchingDirection;
                        float3 normal = estimateNormal(cube, p);

                        float3 newp = mul(transpose(cubeR), p);
                        float2 uv = getUV(normalize(newp));
                        float4 texel = tex2D(_MainTex, uv);
                        float4 texel2 = sampleCubeMap(reflect(marchingDirection, normal));
                        // float4 texel2 = sampleReflectionProbe(reflect(marchingDirection, normal));
                        // float4 texel2 = stars2(reflect(marchingDirection, normal));
                        
                        // col.rgb = texel.rgb;
                        texel.a += .2;
                        col.rgb = texel.rgb*texel.a + texel2.rgb*(1 - texel.a);
                        col.a = texel.a;
                        col.rgba += (normal.y / 2.0 - 0.2);

                        return depth;
                    }

                    depth += dist;
                    if (depth >= end) {
                        return depth;
                    }
                }

                return end;
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

                float dist = shortestDistanceToSurfaceWithColor(eye, worldDir, MIN_DIST, MAX_DIST, col);

                // TODO: fold depth calculcation into the raymarching loop as well?
                // Output depth
                float4 clip_pos = mul(UNITY_MATRIX_VP, float4(i.worldPos, 1.0));
                float maxDepth = clip_pos.z / clip_pos.w;
                if (dist > MAX_DIST - EPSILON) {
                    discard;
                } else {
                    float3 p = eye + dist * worldDir;
                    p = mul(p, transpose(R)) - _SceneOffset; // undo rotation and offset for depth calculation
                    if (_InObjectSpace) {
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
*/
    }
}
