Shader "flexcrt/ExampleFlexCRT"
{
    Properties
    {
    }

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #pragma geometry geo
    #pragma multi_compile_fog
    #pragma target 5.0

    #define CRTTEXTURETYPE uint4
    #include "flexcrt.cginc"
    ENDCG


    SubShader
    {
	Tags { }
	ZTest always
	ZWrite Off

	Pass
	{
	    Name "Demo Compute Test"
	    
	    CGPROGRAM
	    
	    #include "hashwithoutsine.cginc"

	    struct v2g
	    {
		float4 vertex : SV_POSITION;
		uint2 batchID : TEXCOORD0;
	    };

	    struct g2f
	    {
		float4 vertex		   : SV_POSITION;
		uint4 color			: TEXCOORD0;
	    };

	    // The vertex shader doesn't really perform much anything.
	    v2g vert( appdata_customrendertexture IN )
	    {
		v2g o;
		o.batchID = IN.vertexID / 6;

		// This is unused, but must be initialized otherwise things get janky.
		o.vertex = 0.;
		return o;
	    }

	    // Because we are outputting a vertex and a color, that's 8 interpolation value, so
	    // with PS5.0 we can output a maximum of 128 pixels from each execution.
	    [maxvertexcount(128)]
	    
	    // We can cause the geometry program to execute multiple times for each source triangle.
	    // By selecting 32, we execute a total of 64 times per CRT pass.
	    [instance(32)]

	    void geo( point v2g input[1], inout PointStream<g2f> stream,
		uint instanceID : SV_GSInstanceID, uint geoPrimID : SV_PrimitiveID )
	    {
		// Just FYI you get 64kB of local variable space.
		
		int batchID = input[0].batchID;

		// For geometry shaders on CRTs, you get two triangles per pass, if split as points, you get
		// the first point for each triangle that are made in the quad.  The batchID may look a little weird
		// but, the idea is if you're in the next batch, that's a unique instance ID.
		// Also, note order of operations here.
		
		// The pixels are emitted in the order of for each point, every instance, then additional points.
		// so you can make sure the order-of-operations of output pixels is preserved.
		int operationID = geoPrimID * 32 + ( instanceID - batchID );
		
		// You could run the same code here, and selectively output pixels.  If so, then for a given
		// program you could output a total of 64 * 128 or 8192 pixels.

		g2f o;

		for( int i = 0; i < 128; i++ )
		{
		    uint PixelID = i + operationID * 128;
		    
		    // We first output random noise, then we output a stable block.
		    uint2 coordOut;
		    if( PixelID < 4096 )
		    coordOut = hash23( float3( i, operationID, _Time.y ) ) * FlexCRTSize;
		    else
		    coordOut = uint2( i, operationID );

		    o.vertex = FlexCRTCoordinateOut( coordOut );
		    o.color = uint4( (_Time.y*65536 + operationID*256 + i *256)%65536, operationID*256, i*256, 0 );
		    stream.Append(o);
		}
	    }

	    uint4 frag( g2f IN ) : SV_Target
	    {
		return IN.color;
	    }
	    ENDCG
	}
    }
}
