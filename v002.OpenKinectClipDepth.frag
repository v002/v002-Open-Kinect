varying vec2 texcoord0;

uniform sampler2DRect depth;
uniform float minDepth;
uniform float maxDepth;

void main()
{
    //Multiply color by texture
    vec4 depthValues = texture2DRect(depth, texcoord0);
    
    float depthMask = depthValues.z;
    
    if(depthMask > minDepth && depthMask < maxDepth)
    {
        gl_FragColor = vec4(depthValues.rgb, 1.0);
    }
    else
    {
        gl_FragColor = vec4(0.0);
    }
}
