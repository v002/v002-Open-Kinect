uniform sampler2DRect depth;
uniform sampler2DRect color;
uniform sampler2DRect lastDepth;
uniform sampler2DRect lastColor;

//uniform float maxDepth;
//uniform float minDepth;

uniform bool drawColor;

varying vec2 texcoord0;
varying vec2 texcoord1;
varying vec2 texcoord2;
varying vec2 texcoord3;

const vec4 black = vec4(0.0, 0.0, 0.0, 1.0);

void main()
{
    vec4 colorValue = texture2DRect(color, texcoord0);
    vec4 depthValue = texture2DRect(depth, texcoord1);
    
    vec4 lastColorValue = texture2DRect(lastColor, texcoord2);
    vec4 lastDepthValue = texture2DRect(lastDepth, texcoord3);
    
    if(lastDepthValue.z < depthValue.z )
    {
        gl_FragData[1] = mix(lastDepthValue, black, vec4(drawColor));
        gl_FragData[0] = mix(lastColorValue, black, vec4(drawColor));
    }
    else
    {
        // depth image only
        gl_FragData[1] = mix(depthValue, black, vec4(drawColor));
        gl_FragData[0] = mix(colorValue, black, vec4(drawColor));
    }
}
