// Based on https://www.shadertoy.com/view/XdBBzR

Shader "Xantoz/XZAudioLinkBlobMarchingCubes"
{
    Properties
    {
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 1
        _Tint ("Tint Color", Color) = (1, 1, 1, 1)
        [NoScaleOffset]_Tex ("Cubemap (HDR)", Cube) = "Cube" {}
        [Gamma] _Exposure ("Exposure", Range(0, 8)) = 0.5
        _K("k-factor", Float) = 2.5
        _SceneScale("Scene scale", Float) = 0.03

        [Space(10)]
        [Header(Audiolink)]
        _Amplitude_Scale ("AudioLink PCM Amplitude Scale", Range(0.0, 2.0)) = 1.0  // Scale amplitude of PCM
    }

    CGINCLUDE
    #pragma target 5.0
    #pragma multi_compile_fog
    #pragma multi_compile_instancing

    #include "UnityCG.cginc"
    #include "../cginc/rotation.cginc"
    #include "../cginc/AudioLinkFuncs.cginc"
    #include "MarchingTable.hlsl"

    // Number of samples to turn into metaballs
    #define SAMPLECNT 64
    // Use every n'th sample
    #define STEP 16

    #define MAX_DIST 100.0
    #define EPSILON 0.001

    ENDCG

    SubShader
    {
        Tags { "RenderType"="Opaque" "DisableBatching"="True" }
        LOD 100
        Cull [_Cull]

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma geometry geom
            #pragma fragment frag

            samplerCUBE _Tex;
            float4 _Tex_HDR;
            float4 _Tint;
            float _Exposure;
            float _K;
            float _SceneScale;

            float _Amplitude_Scale;

            struct appdata
            {
                float4 vertex : POSITION;

                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2g
            {
                float4 vertex : SV_POSITION;

                UNITY_FOG_COORDS(6)
                UNITY_VERTEX_OUTPUT_STEREO
            };


            struct g2f
            {
                float4 vertex : SV_POSITION; // Clip space pos
                // float2 uv : TEXCOORD0;
                // float3 ray_origin : TEXCOORD1;
                // float3 vert_position : TEXCOORD2; // Object space pos
                float3 normal : TEXCOORD3;

                UNITY_FOG_COORDS(6)
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2g vert(appdata IN)
            {
                v2g o;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2g, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                // o.vertex = UnityObjectToClipPos(v.vertex);
                o.vertex = 0.0;

                return o;
            }

            /**
            * Signed distance function for a sphere centered at the origin with radius r.
            */
            float sphereSDF(float3 p, float r) {
                return length(p) - r;
            }

            // polynomial smooth min (k = 0.1);
            float smin(float a, float b, float k)
            {
                float h = clamp(0.5+0.5*(b-a)/k, 0.0, 1.0);
                return lerp(b, a, h) - k*h*(1.0-h);
            }

            /**
            * Signed distance function describing the scene.
            */
            float sceneSDF(float3 samplePoint) {
                float ballRadius = 1.0;
                float balls = MAX_DIST;
                [loop]
                for (uint i = 0; i < SAMPLECNT; ++i) {
                    float4 pcm = AudioLinkPCMData(i*STEP)*0.5*_Amplitude_Scale;
                    float2 pcm_lr = PCMToLR(pcm);
                    balls = smin(balls, sphereSDF(samplePoint + float3(pcm_lr.x, pcm_lr.y, pcm.g), ballRadius*_SceneScale), _K*_SceneScale);
                }
                return balls;
            }

            #define LOOPS 8
            #define NUMINSTANCES 32

            #define GRIDSIZE 64
            #define SCALE (1.0f/GRIDSIZE)

            #define isoLevel 0.5f
            //#define isoLevel 0.0f

            float3 Interp(float3 edgeVertex1, float valueAtVertex1, float3 edgeVertex2, float valueAtVertex2) {
                return (edgeVertex1 + (isoLevel - valueAtVertex1) * (edgeVertex2 - edgeVertex1) / (valueAtVertex2 - valueAtVertex1));
            }

            // For now hard-coded for the case of 1024 points in * 32 instances * 8 loops = 262144 cubes = 64x64x64 grid
            //
            // In theory we could do up to 25 loops with maxvertexcount(128), since one cube can have up to 5 vertices
            // out (see the triangle table), but 8 is easier to work with for now, and cleanly breaks up into a 2x2x2
            // subsection and all that.
            //
            // More loops would mean less redundant calculations, however, as we can reuse isosurface calculations for
            // neighboring cubes only within the same thread here.
            //
            // TODO: Perhaps we could make this less hard-coded and more flexible though by using a mesh specifically prepared for marching cubes.
            //       Say a point mesh with one point for each cube corner, and we could simply use its position.
            //       Then instances and loops could be used simply as a means to densify that lattice
            [instance(NUMINSTANCES)]
            [maxvertexcount(LOOPS*5*3)]
            void geom(
                point v2g IN[1], inout TriangleStream<g2f> stream,
                uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID)
            {
                g2f o;

                uint operationID = (geoPrimID*NUMINSTANCES + instanceID)*LOOPS;
                //uint operationID = (geoPrimID + instanceID*1024)*LOOPS;
                //uint operationID = (geoPrimID*NUMINSTANCES + instanceID);
                uint zoffset = operationID / (GRIDSIZE * GRIDSIZE);
                uint yoffset = (operationID % (GRIDSIZE * GRIDSIZE)) / GRIDSIZE;
                //uint yoffset = (operationID / (GRIDSIZE * GRIDSIZE)) % GRIDSIZE;
                uint xoffset = (operationID % (GRIDSIZE * GRIDSIZE)) % GRIDSIZE;

                // Now we have to work out which 2x2x2 = 8 cubes to process for this particular invocation
                // TODO: reuse of neighboring cube vertices to avoid recalculating the SDF
                [loop]
                for (uint z = 0; z < 2 ; ++z) {
                    uint zz = z + zoffset;
                    [loop]
                    for (uint y = 0; y < 2; ++y) {
                        uint yy = y + yoffset;
                        [loop]
                        for (uint x = 0; x < 2; ++x) {
                            uint xx = x + xoffset;

                            float3 basePos = float3(xx, yy, zz) - GRIDSIZE/2;
                            //float3 basePos = float3(xx, yy, zz);
                            float3 basePosScaled = basePos * SCALE;
                            float3 pos[8];
                            float val[8];
                            for (uint k = 0; k < 8; ++k) {
                                pos[k] = (basePos + cornerOffsets[k]) * SCALE;
                                val[k] = sceneSDF(pos[k]);
                            }

                            uint cubeIndex = 0;
                            if (val[0] < isoLevel) cubeIndex |= 1;
                            if (val[1] < isoLevel) cubeIndex |= 2;
                            if (val[2] < isoLevel) cubeIndex |= 4;
                            if (val[3] < isoLevel) cubeIndex |= 8;
                            if (val[4] < isoLevel) cubeIndex |= 16;
                            if (val[5] < isoLevel) cubeIndex |= 32;
                            if (val[6] < isoLevel) cubeIndex |= 64;
                            if (val[7] < isoLevel) cubeIndex |= 128;

                            int edges[] = triTable[cubeIndex];

                            // Triangulate
                            for (uint i = 0; edges[i] != -1; i += 3) {
                                int e00 = edgeConnections[edges[i]][0];
                                int e01 = edgeConnections[edges[i]][1];

                                int e10 = edgeConnections[edges[i + 1]][0];
                                int e11 = edgeConnections[edges[i + 1]][1];

                                int e20 = edgeConnections[edges[i + 2]][0];
                                int e21 = edgeConnections[edges[i + 2]][1];

                                float3 verts[3];
                                verts[0] = (Interp(cornerOffsets[e00], val[e00], cornerOffsets[e01], val[e01]) + basePos) * SCALE;
                                verts[1] = (Interp(cornerOffsets[e10], val[e10], cornerOffsets[e11], val[e11]) + basePos) * SCALE;
                                verts[2] = (Interp(cornerOffsets[e20], val[e20], cornerOffsets[e21], val[e21]) + basePos) * SCALE;

                                // Just a quick & dirty normal for now (going to look faceted I think?)
                                // TODO: figure out something smarter to do (might require computing neighboring cubes that we aren't neccesarily outputting in this geom invocation) 
                                float3 u = normalize(verts[1] - verts[0]);
                                float3 v = normalize(verts[2] - verts[1]);
                                float3 normal = cross(u, v);

                                for (uint j = 0; j < 3; ++j) {
                                    o.vertex = UnityObjectToClipPos(verts[j]);
                                    o.normal = normal;
                                    stream.Append(o);
                                }
                                //stream.RestartStrip();
                            }
                        }
                    }
                }
            }

/*
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
*/

            float3 estimateNormal(float3 p) {
                return normalize(float3(
                        sceneSDF(float3(p.x + EPSILON, p.y, p.z)) - sceneSDF(float3(p.x - EPSILON, p.y, p.z)),
                        sceneSDF(float3(p.x, p.y + EPSILON, p.z)) - sceneSDF(float3(p.x, p.y - EPSILON, p.z)),
                        sceneSDF(float3(p.x, p.y, p.z  + EPSILON)) - sceneSDF(float3(p.x, p.y, p.z - EPSILON))
                    ));
            }

            float4 sampleCubeMap(float3 texcoord)
            {
                float4 tex = texCUBE(_Tex, texcoord);
                float3 c = DecodeHDR(tex, _Tex_HDR);
                c = c * _Tint.rgb * unity_ColorSpaceDouble.rgb;
                c *= _Exposure;
                return float4(c, 1);
            }

            float4 frag (g2f i) : SV_Target
            {
                float4 col = 0.0f;

                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 ray_direction = normalize(i.vertex - _WorldSpaceCameraPos);

/*
                float3 p = i.vert_position;
                float3 normal = estimateNormal(p);
*/

                float3 normal = i.normal;
                float4 tex = sampleCubeMap(reflect(ray_direction, normal));

                col = (tex + (normal.y / 2.0 - 0.2)) * float4(1.0, 0.8, 0.6, 1.0);

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
