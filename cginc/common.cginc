#ifndef _COMMON_CGINC
#define _COMMON_CGINC

float mod(float x, float y)
{
    return x - y * floor(x/y);
}

float2 mod(float2 x, float2 y)
{
    return x - y * floor(x/y);
}

float3 mod(float3 x, float3 y)
{
    return x - y * floor(x/y);
}

float4 mod(float4 x, float4 y)
{
    return x - y * floor(x/y);
}

// From: https://stackoverflow.com/questions/5149544/can-i-generate-a-random-number-inside-a-pixel-shader
float random(float2 p)
{
    // We need irrationals for pseudo randomness.
    // Most (all?) known transcendental numbers will (generally) work.
    const float2 r = float2(
        23.1406926327792690,  // e^pi (Gelfond's constant)
        2.6651441426902251); // 2^sqrt(2) (Gelfond窶鉄chneider constant)
    return frac(cos(mod(123456789.0, 1e-7 + 256.0 * dot(p,r))));
}

// from https://www.shadertoy.com/view/XsX3zB
// * The MIT License
// * Copyright © 2013 Nikita Miropolskiy
float3 random3(float3 c) {
    float j = 4096.0*sin(dot(c,float3(17.0, 59.4, 15.0)));
    float3 r;
    r.z = frac(512.0*j);
    j *= .125;
    r.x = frac(512.0*j);
    j *= .125;
    r.y = frac(512.0*j);
    return r-0.5;
}

// from https://www.shadertoy.com/view/XsX3zB
// * The MIT License
// * Copyright © 2013 Nikita Miropolskiy
/* 3d simplex noise */
float simplex3d(float3 p) {
    /* skew constants for 3d simplex functions */
    static const float F3 =  0.3333333;
    static const float G3 =  0.1666667;

    /* 1. find current tetrahedron T and it's four vertices */
    /* s, s+i1, s+i2, s+1.0 - absolute skewed (integer) coordinates of T vertices */
    /* x, x1, x2, x3 - unskewed coordinates of p relative to each of T vertices*/

    /* calculate s and x */
    float3 s = floor(p + dot(p, float3(F3,F3,F3)));
    float3 x = p - s + dot(s, float3(G3,G3,G3));

    /* calculate i1 and i2 */
    float3 e = step(float3(0,0,0), x - x.yzx);
    float3 i1 = e*(1.0 - e.zxy);
    float3 i2 = 1.0 - e.zxy*(1.0 - e);

    /* x1, x2, x3 */
    float3 x1 = x - i1 + G3;
    float3 x2 = x - i2 + 2.0*G3;
    float3 x3 = x - 1.0 + 3.0*G3;

    /* 2. find four surflets and store them in d */
    float4 w, d;

    /* calculate surflet weights */
    w.x = dot(x, x);
    w.y = dot(x1, x1);
    w.z = dot(x2, x2);
    w.w = dot(x3, x3);

    /* w fades from 0.6 at the center of the surflet to 0.0 at the margin */
    w = max(0.6 - w, 0.0);

    /* calculate surflet components */
    d.x = dot(random3(s), x);
    d.y = dot(random3(s + i1), x1);
    d.z = dot(random3(s + i2), x2);
    d.w = dot(random3(s + 1.0), x3);

    /* multiply d by w^4 */
    w *= w;
    w *= w;
    d *= w;

    /* 3. return the sum of the four surflets */
    return dot(d, float4(52,52,52,52));
}

// from https://www.shadertoy.com/view/XsX3zB
// * The MIT License
// * Copyright © 2013 Nikita Miropolskiy
/* directional artifacts can be reduced by rotating each octave */
float simplex3d_fractal(float3 m) {
    /* const matrices for 3d rotation */
    static const float3x3 rot1 = float3x3(-0.37, 0.36, 0.85,-0.14,-0.93, 0.34,0.92, 0.01,0.4);
    static const float3x3 rot2 = float3x3(-0.55,-0.39, 0.74, 0.33,-0.91,-0.24,0.77, 0.12,0.63);
    static const float3x3 rot3 = float3x3(-0.71, 0.52,-0.47,-0.08,-0.72,-0.68,-0.7,-0.45,0.56);

    // return 0.5333333*simplex3d(m*rot1)
    //            +0.2666667*simplex3d(2.0*m*rot2)
    //            +0.1333333*simplex3d(4.0*m*rot3)
    //            +0.0666667*simplex3d(8.0*m);
    return 0.5333333*simplex3d(mul(rot1,m))
               +0.2666667*simplex3d(2.0*mul(rot2, m))
               +0.1333333*simplex3d(4.0*mul(rot3, m))
               +0.0666667*simplex3d(8.0*m);
}

#endif /* _COMMON_CGINC */
