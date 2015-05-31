varying vec2 texcoord0;
varying vec2 texcoord1;
varying vec2 texcoord2;
varying vec2 texcoord3;

void main()
{
    // perform standard transform on vertex
    gl_Position = ftransform();
    
    // transform texcoords
    texcoord0 = vec2(gl_TextureMatrix[0] * gl_MultiTexCoord0);
    texcoord1 = vec2(gl_TextureMatrix[1] * gl_MultiTexCoord1);
    texcoord2 = vec2(gl_TextureMatrix[2] * gl_MultiTexCoord2);
    texcoord3 = vec2(gl_TextureMatrix[3] * gl_MultiTexCoord3);
}