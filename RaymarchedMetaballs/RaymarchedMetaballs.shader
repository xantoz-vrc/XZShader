// Based on https://www.shadertoy.com/view/XdBBzR

Shader "Xantoz/RaymarchedMetaballs"
{
    Properties
    {
        _Tint ("Tint Color", Color) = (1, 1, 1, 1)
        [NoScaleOffset]_Tex ("Cubemap (HDR)", Cube) = "Cube" {}
        [Gamma] _Exposure ("Exposure", Range(0, 8)) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        Cull Off

        Pass
        {
            CGPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            samplerCUBE _Tex;
            float4 _Tex_HDR;
            float4 _Tint;
            float _Exposure;

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
                float3 texcoord : TEXCOORD1;

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
                o.texcoord = v.vertex.xyz;
                o.uv = v.uv;

                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            const int MAX_MARCHING_STEPS = 64;
            const float MIN_DIST = 0.0;
            const float MAX_DIST = 100.0;
            const float EPSILON = 0.001;

            // #define TIME _Time.y
            #define TIME 0

            /**
            * Rotation matrix around the Y axis.
            */
            float3x3 rotateY(float theta) {
                float c = cos(theta);
                float s = sin(theta);
                return float3x3(
                    c, 0, s,
                    0, 1, 0,
                    -s, 0, c
                );
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
                float t = TIME / 3.0 + 10500.0;
                float balls = MAX_DIST;
                for (float i = 1.0; i < 4.0; i += 1.3) {
                    for (float j = 1.0; j < 4.0; j += 1.3) {
                        float cost = cos(t * j);
                        balls = smin(balls, sphereSDF(samplePoint + float3(sin(t * i) * j, cost * i, cost * j), ballRadius), 0.7);
                    }
                }

                return balls;
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

            float4 frag (v2f i) : SV_Target
            {
                float4 col = 0.0f;

                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float3 viewDir = rayDirection(90.0, float2(1, 1), i.uv.xy);
                float3 eye = mul(rotateY(TIME / 3.0), float3(3.0, 3.0, 10.0));
                float3x3 viewToWorld = viewMatrix(eye, float3(0.0, 0.0, 0.0), float3(0.0, 1.0, 0.0));
                float3 worldDir = mul(viewToWorld, viewDir);
                float dist = shortestDistanceToSurface(eye, worldDir, MIN_DIST, MAX_DIST);

                if (dist > MAX_DIST - EPSILON) {
                    col = sampleCubeMap(worldDir);
                    return col;
                }

                float3 p = eye + dist * worldDir;
                float3 normal = estimateNormal(p);
                float4 tex = sampleCubeMap(reflect(worldDir, normal));

                col = (tex + (normal.y / 2.0 - 0.2)) * float4(1.0, 0.8, 0.6, 1.0);

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}
