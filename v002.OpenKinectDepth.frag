#version 120

uniform sampler2DRect depthTexture;
uniform sampler2DRect colorTexture;

uniform float correctDepth;
//uniform float correctColor;
uniform float generatePositionMap;

varying vec2 texcoord0;
varying vec2 texcoord1;

const vec2 size = vec2(640,480);
const float fovWidth = 1.0144686707507438;
const float fovHeight = 0.78980943449644714;
const float XtoZ = tan(1.0144686707507438 / 2.0) * 2.0;
const float YtoZ = tan(0.78980943449644714 / 2.0) * 2.0;
const float k1 = 1.1863; 
const float k2 = 2842.5; 
const float k3 = 0.1236; 

// Transforms to ensure things line up in Quartz Compuser.
const float theta = radians(180.0);

const mat4 rotY = mat4( vec4 (cos(theta),0.0, sin(theta), 0.0),
                        vec4(0.0, 1.0, 0.0, 0.0),
                        vec4(-sin(theta), 0.0, cos(theta), 0.0),
                        vec4(1.0, 0.0, 0.0, 1.0));

const mat4 rotZ = mat4( vec4(cos(theta), -sin(theta), 0.0, 0.0),
                        vec4(sin(theta), cos(theta), 0.0, 0.0),
                        vec4(0.0, 0.0, 1.0, 0.0),
                        vec4(1.0, 0.0, 0.0, 1.0));
                        
const mat4 trans = mat4( vec4(1.0, 0.0, 0.0, 0.0),
                         vec4(0.0, 1.0, 0.0, 0.0),
                         vec4(0.0, 0.0, 1.0, 0.0),
                         vec4(0.0, 1.0, 1.5, 1.0));

// for Color RGB Rectification
const mat3 R = mat3(vec3(0.99984628826577793, -0.0014779096108364480, 0.017470421412464927),
                    vec3(0.0012635359098409581, 0.99992385683542895, 0.012275341476520762),
                    vec3(-0.017487233004436643, -0.012251380107679535, 0.99977202419716948));

const vec3 T = vec3(0.019985242312092553, -0.00074423738761617583, -0.010916736334336222);

// RGB Unprojection
const float fx_rgb = 529.21508098293293;
const float fy_rgb = 525.56393630057437;
const float cx_rgb = 328.94272028759258;
const float cy_rgb = 267.48068171871557;

// Depth Unprojection to RGB
const float fx_d = 594.21434211923247;
const float fy_d = 591.04053696870778;
const float cx_d = 339.30780975300314;
const float cy_d = 242.73913761751615;


float convertToDepth(float z)
{
    return k3 * tan(z/k2 + k1); 
}

vec4 convertProjectiveToRealWorld(vec4 raw, vec2 size)
{
	return vec4(((raw.x - 0.5) * raw.z * XtoZ) + 0.5, ((raw.y - 0.5) * raw.z * YtoZ) + 0.5, raw.z, raw.w);
}

void main(void)
{
    // Depth Correction
	float uncorrectedz = texture2DRect(depthTexture, texcoord0).r;

    // expand to proper 11 bit, uint16 range    
    uncorrectedz *= 65.535;	//65535 * 0.001 mm in a meter
	
    float depth = convertToDepth(uncorrectedz);    

    vec4 raw = vec4(texcoord0.x / (size.x - 1), texcoord0.y / (size.y - 1), uncorrectedz, 1.0);
    vec4 correctedDepth = convertProjectiveToRealWorld(raw, texcoord0);
            
    // Color RGB image Rectification
    vec3 unprojectDepth;        
    unprojectDepth.x = (texcoord0.x - cx_d) * correctedDepth.z / fx_d;
    unprojectDepth.y = (texcoord0.y - cy_d) * correctedDepth.z / fy_d;
    unprojectDepth.z = correctedDepth.z;        
            
    vec3 calibratedDepth = R * unprojectDepth.xyz + T;
    
    vec2 colorPoint;
    
    colorPoint.x = (calibratedDepth.x * fx_rgb / calibratedDepth.z) + cx_rgb;
    colorPoint.y = (calibratedDepth.y * fy_rgb / calibratedDepth.z) + cy_rgb;
        
    vec4 color = texture2DRect(colorTexture, texcoord1);
    color.a = 1.0;

    vec4 final = mix(raw, correctedDepth, correctDepth); 
    
	
	// Now we have to do some subtle coordinate shifting to ensure we output centered, etc
	final = trans * rotY * rotZ * final;

    // Do we output just luma, or XYZ?
    final = mix(vec4(vec3(correctedDepth.z), 1.0), final, generatePositionMap); // final


    gl_FragData[0] = final;
    gl_FragData[1] = clamp(color, 0.0, 1.0);

}
