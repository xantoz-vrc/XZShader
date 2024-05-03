// Porting of Asbtract Corridor by Shane on ShaderToy: https://www.shadertoy.com/view/MlXSWX to Unity

Shader "Xantoz/AbstractCorridor"
{
    Properties
    {
        [NoScaleOffset]_Tex0 ("Texture 0", 2D) = "white" {}
        [NoScaleOffset]_Tex1 ("Texture 1", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "DisableBatching"="True" }
        LOD 100
        Cull Off

        CGINCLUDE
        #include "UnityCG.cginc"
        ENDCG

        Pass
        {
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
            
            Texture2D<float4> _Tex0;
            Texture2D<float4> _Tex1;
            SamplerState sampler_Tex0;
            SamplerState sampler_Tex1;

            #define TIME _Time.y

            /*
            Abstract Corridor
            -------------------

            Using Shadertoy user Nimitz's triangle noise idea and his curvature function to fake an abstract,
            flat-shaded, point-lit, mesh look.

            It's a slightly trimmed back, and hopefully, much quicker version my previous tunnel example...
            which is not interesting enough to link to. :)

           */

            #define PI 3.1415926535898
            #define FH 1.0 // Floor height. Set it to 2.0 to get rid of the floor.

            // Grey scale.
            float getGrey(float3 p)
            {
                return p.x*0.299 + p.y*0.587 + p.z*0.114;
            }

            // Non-standard float3-to-float3 hash function.
            float3 hash33(float3 p)
            {

                float n = sin(dot(p, float3(7, 157, 113)));
                return frac(float3(2097152, 262144, 32768)*n);
            }

            // 2x2 matrix rotation.
            float2x2 rot2(float a)
            {
                float c = cos(a);
                float s = sin(a);
                return float2x2(c, s, -s, c);
            }

            // Tri-Planar blending function. Based on an old Nvidia tutorial.
            float3 custom_tex3D(Texture2D<float4> tex, SamplerState sam, in float3 p, in float3 n )
            {
                n = max((abs(n) - 0.2)*7., 0.001); // max(abs(n), 0.001), etc.
                n /= (n.x + n.y + n.z );

                return (tex.Sample(sam, p.yz)*n.x + tex.Sample(sam, p.zx)*n.y + tex.Sample(sam, p.xy)*n.z).xyz;
            }

            // The triangle function that Shadertoy user Nimitz has used in various triangle noise demonstrations.
            // See Xyptonjtroz - Very cool. Anyway, it's not really being used to its full potential here.
            float3 tri(in float3 x)
            {
                return abs(x-floor(x)-.5); // Triangle function.
            }

            // The function used to perturb the walls of the cavern: There are infinite possibities, but this one is
            // just a cheap...ish routine - based on the triangle function - to give a subtle jaggedness. Not very fancy,
            // but it does a surprizingly good job at laying the foundations for a sharpish rock face. Obviously, more
            // layers would be more convincing. However, this is a GPU-draining distance function, so the finer details
            // are bump mapped.
            float surfFunc(in float3 p)
            {
                return dot(tri(p*0.5 + tri(p*0.25).yzx), float3(0.666,0.666,0.666));
            }


            // The path is a 2D sinusoid that varies over time, depending upon the frequencies, and amplitudes.
            float2 path(in float z)
            {
                float s = sin(z/24.0)*cos(z/12.0);
                return float2(s*12.0, 0.0);
            }

            // Standard tunnel distance function with some perturbation thrown into the mix. A floor has been
            // worked in also. A tunnel is just a tube with a smoothly shifting center as you traverse lengthwise.
            // The walls of the tube are perturbed by a pretty cheap 3D surface function.
            float map(float3 p)
            {
                float sf = surfFunc(p - float3(0, cos(p.z/3.)*.15, 0));
                // Square tunnel.
                // For a square tunnel, use the Chebyshev(?) distance: max(abs(tun.x), abs(tun.y))
                float2 tun = abs(p.xy - path(p.z))*float2(0.5, 0.7071);
                float n = 1.0 - max(tun.x, tun.y) + (0.5 - sf);
                return min(n, p.y + FH);

                /*
                // Round tunnel.
                // For a round tunnel, use the Euclidean distance: length(tun.y)
                float2 tun = (p.xy - path(p.z))*float2(0.5, 0.7071);
                float n = 1.0 - length(tun) + (0.5 - sf);
                return min(n, p.y + FH);
                */

                /*
                // Rounded square tunnel using Minkowski distance: pow(pow(abs(tun.x), n), pow(abs(tun.y), n), 1/n)
                float2 tun = abs(p.xy - path(p.z))*float2(0.5, 0.7071);
                tun = pow(tun, float2(4.));
                float n = 1.0 -pow(tun.x + tun.y, 1.0/4.) + (0.5 - sf);
                return min(n, p.y + FH);
                */

            }

            // Texture bump mapping. Four tri-planar lookups, or 12 texture lookups in total.
            float3 doBumpMap(Texture2D<float4> tex, SamplerState sam, in float3 p, in float3 nor, float bumpfactor) {

                const float eps = 0.001;
                float ref = getGrey(custom_tex3D(tex, sam,  p , nor));
                float3 grad = float3(getGrey(custom_tex3D(tex, sam, float3(p.x - eps, p.y, p.z), nor)) - ref,
                    getGrey(custom_tex3D(tex, sam, float3(p.x, p.y - eps, p.z), nor)) - ref,
                    getGrey(custom_tex3D(tex, sam, float3(p.x, p.y, p.z - eps), nor)) - ref )/eps;

                grad -= nor*dot(nor, grad);

                return normalize( nor + grad*bumpfactor );

            }

            // Surface normal.
            float3 getNormal(in float3 p)
            {
                const float eps = 0.001;
                return normalize(float3(
                        map(float3(p.x + eps, p.y, p.z)) - map(float3(p.x - eps, p.y, p.z)),
                        map(float3(p.x, p.y + eps, p.z)) - map(float3(p.x, p.y - eps, p.z)),
                        map(float3(p.x, p.y, p.z + eps)) - map(float3(p.x, p.y, p.z - eps))
                    ));
            }

            // Based on original by IQ.
            float calculateAO(float3 p, float3 n)
            {

                const float AO_SAMPLES = 5.0;
                float r = 0.0, w = 1.0, d;

                for (float i = 1.0; i<AO_SAMPLES+1.1; i++){
                    d = i/AO_SAMPLES;
                    r += w*(d - map(p + n*d));
                    w *= 0.5;
                }

                return 1.0-clamp(r,0.0,1.0);
            }

            // Cool curve function, by Shadertoy user, Nimitz.
            //
            // I wonder if it relates to the discrete finite difference approximation to the
            // continuous Laplace differential operator? Either way, it gives you a scalar
            // curvature value for an object's signed distance function, which is pretty handy.
            //
            // From an intuitive sense, the function returns a weighted difference between a surface
            // value and some surrounding values. Almost common sense... almost. :) If anyone
            // could provide links to some useful articles on the function, I'd be greatful.
            //
            // Original usage (I think?) - Cheap curvature: https://www.shadertoy.com/view/Xts3WM
            // Other usage: Xyptonjtroz: https://www.shadertoy.com/view/4ts3z2
            float curve(in float3 p, in float w)
            {

                float2 e = float2(-1., 1.)*w;

                float t1 = map(p + e.yxx), t2 = map(p + e.xxy);
                float t3 = map(p + e.xyx), t4 = map(p + e.yyy);

                return 0.125/(w*w) *(t1 + t2 + t3 + t4 - 4.*map(p));
            }

            // void mainImage(out float4 fragColor, in float2 fragCoord)
            float4 frag(v2f i) : SV_Target
            {

                // Screen coordinates.
                // float2 uv = (fragCoord - iResolution.xy*0.5)/iResolution.y;
                float2 uv = i.uv.xy - 0.5;

                // Camera Setup.
                float3 camPos = float3(0.0, 0.0, TIME*5.0); // Camera position, doubling as the ray origin.
                float3 lookAt = camPos + float3(0.0, 0.1, 0.5);  // "Look At" position.

                // Light positioning. One is a little behind the camera, and the other is further down the tunnel.
                float3 light_pos = camPos + float3(0.0, 0.125, -0.125);// Put it a bit in front of the camera.
                float3 light_pos2 = camPos + float3(0.0, 0.0, 6.0);// Put it a bit in front of the camera.

                // Using the Z-value to perturb the XY-plane.
                // Sending the camera, "look at," and two light floattors down the tunnel. The "path" function is
                // synchronized with the distance function.
                lookAt.xy += path(lookAt.z);
                camPos.xy += path(camPos.z);
                light_pos.xy += path(light_pos.z);
                light_pos2.xy += path(light_pos2.z);

                // Using the above to produce the unit ray-direction floattor.
                float FOV = PI/3.; // FOV - Field of view.
                float3 forward = normalize(lookAt-camPos);
                float3 right = normalize(float3(forward.z, 0.0, -forward.x));
                float3 up = cross(forward, right);

                // rd - Ray direction.
                float3 rd = normalize(forward + FOV*uv.x*right + FOV*uv.y*up);

                // Swiveling the camera from left to right when turning corners.
                // TODO: Fixme, this line won't compile with a type error it seems
                rd.xy = mul(rot2(path(lookAt.z).x/32.0), rd.xy);

                // Standard ray marching routine. I find that some system setups don't like anything other than
                // a "break" statement (by itself) to exit.
                float t = 0.0, dt;
                for (int i=0; i<128; i++) {
                    dt = map(camPos + rd*t);
                    if(dt<0.005 || t>150.0){ break; }
                    t += dt*0.75;
                }

                // The final scene color. Initated to black.
                float3 sceneCol = float3(0,0,0);

                // The ray has effectively hit the surface, so light it up.
                if (dt<0.005) {
                    // Surface position and surface normal.
                    float3 sp = t * rd+camPos;
                    float3 sn = getNormal(sp);

                    // Texture scale factor.
                    const float tSize0 = 1.0/1.0;
                    const float tSize1 = 1.0/4.0;

                    // Texture-based bump mapping.
                    if (sp.y<-(FH-0.005)) {
                        sn = doBumpMap(_Tex1, sampler_Tex1, sp*tSize1, sn, 0.025); // Floor.
                    } else {
                        sn = doBumpMap(_Tex0, sampler_Tex0, sp*tSize0, sn, 0.025); // Walls.
                    }

                    // Ambient occlusion.
                    float ao = calculateAO(sp, sn);

                    // Light direction floattors.
                    float3 ld = light_pos-sp;
                    float3 ld2 = light_pos2-sp;

                    // Distance from respective lights to the surface point.
                    float distlpsp = max(length(ld), 0.001);
                    float distlpsp2 = max(length(ld2), 0.001);

                    // Normalize the light direction floattors.
                    ld /= distlpsp;
                    ld2 /= distlpsp2;

                    // Light attenuation, based on the distances above. In case it isn't obvious, this
                    // is a cheap fudge to save a few extra lines. Normally, the individual light
                    // attenuations would be handled separately... No one will notice, nor care. :)
                    float atten = min(1.0/(distlpsp) + 1.0/(distlpsp2), 1.0);

                    // Ambient light.
                    float ambience = 0.25;

                    // Diffuse lighting.
                    float diff = max( dot(sn, ld), 0.0);
                    float diff2 = max( dot(sn, ld2), 0.0);

                    // Specular lighting.
                    float spec = pow(max( dot( reflect(-ld, sn), -rd ), 0.0 ), 8.);
                    float spec2 = pow(max( dot( reflect(-ld2, sn), -rd ), 0.0 ), 8.);

                    // Curvature.
                    float crv = clamp(curve(sp, 0.125)*0.5 + 0.5, .0, 1.0);

                    // Fresnel term. Good for giving a surface a bit of a reflective glow.
                    float fre = pow( clamp(dot(sn, rd) + 1.0, 0.0, 1.0), 1.0);

                    // Obtaining the texel color. If the surface point is above the floor
                    // height use the wall texture, otherwise use the floor texture.
                    float3 texCol;
                    if (sp.y < -(FH - 0.005)) {
                        texCol = custom_tex3D(_Tex1, sampler_Tex1, sp*tSize1, sn); // Floor.
                    } else {
                        texCol = custom_tex3D(_Tex0, sampler_Tex0, sp*tSize0, sn); // Walls.
                    }

                    // Shadertoy doesn't appear to have anisotropic filtering turned on... although,
                    // I could be wrong. Texture-bumped objects don't appear to look as crisp. Anyway,
                    // this is just a very lame, and not particularly well though out, way to sparkle
                    // up the blurry bits. It's not really that necessary.
                    //float3 aniso = (0.5 - hash33(sp))*fre*0.35;
                    //texCol = clamp(texCol + aniso, 0., 1.0);

                    // Darkening the crevices. Otherwise known as cheap, scientifically-incorrect shadowing.
                    float shading =  crv*0.5 + 0.5;

                    // Combining the above terms to produce the final color. It was based more on acheiving a
                    // certain aesthetic than science.
                    //
                    // Glow.
                    sceneCol = getGrey(texCol)*((diff + diff2)*0.75 + ambience*0.25) + (spec + spec2)*texCol*2. + fre*crv*texCol.zyx*2.;
                    //
                    // Other combinations:
                    //
                    // Shiny.
                    //sceneCol = texCol*((diff + diff2)*float3(1.0, 0.95, 0.9) + ambience + fre*fre*texCol) + (spec + spec2);
                    // Abstract pen and ink?
                    //float c = getGrey(texCol)*((diff + diff2)*1.75 + ambience + fre*fre) + (spec + spec2)*0.75;
                    //sceneCol = float3(c*c*c, c*c, c);


                    // Shading.
                    sceneCol *= atten*shading*ao;

                    // Drawing the lines on the walls. Comment this out and change the first texture to
                    // granite for a granite corridor effect.
                    sceneCol *= clamp(1.0-abs(curve(sp, 0.0125)), .0, 1.0);


                }

                // Edit: No gamma correction -- I can't remember whether it was a style choice, or whether I forgot at
                // the time, but you should always gamma correct. In this case, just think of it as rough gamma correction
                // on a postprocessed color: sceneCol = sqrt(sceneCol*sceneCol); :D
                return float4(clamp(sceneCol, 0., 1.0), 1.0);
            }
            ENDCG
        }
    }
}

