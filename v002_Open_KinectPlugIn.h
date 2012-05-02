//
//  v002_Open_KinectPlugIn.h
//  v002 Open Kinect
//
//  Created by vade on 1/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#import "libfreenect-audio.h"
#import "libfreenect-registration.h"
#import "libfreenect.h"

#import <OpenGL/OpenGL.h>
#import <Quartz/Quartz.h>

#import "v002FBO.h"
#import "v002Shader.h"

#import <pthread.h>

@interface v002_Open_KinectPlugIn : QCPlugIn
{
    BOOL usingFloatWorkaround;
    
    // this is our luminance 16 texture raw from the kinect
    GLuint rawDepthTexture;

    // this is our color image
    GLuint rawRGBTexture;

    // this is our infra red image
    GLuint rawInfraTexture;

    // FBO where MRT and shaders happen.
    GLuint fbo;
    
    // FBO state
    GLint previousFBO;	// make sure we pop out to the right FBO
	GLint previousReadFBO;
	GLint previousDrawFBO;
    
    v002Shader* depthShader;        
    
    NSThread* kinectThread;
    
    freenect_context *f_ctx;
    freenect_device *f_dev;
		
    // CPU side buffers for Kinect images
    unsigned char *IR;
    unsigned char *rgb;
    uint16 *depth;
	freenect_registration* registration;
	
    
    BOOL needNewRGBImage;
    BOOL needNewDepthImage;
    double tilt;
    
    BOOL useIRImageFormat; // Color or Infra Red image?
    BOOL correctColor;
	
    NSUInteger deviceID;
    
    double accelX;
    double accelY;
    double accelZ;
    
    freenect_resolution resolution;
    NSSize selectedResolutionRGB;
    NSSize selectedResolutionIR;
    NSSize selectedResolutionDepth;

    // cache our image providers
    id<QCPlugInOutputImageProvider> depthProvider;
    id<QCPlugInOutputImageProvider> imageProvider;
    
    pthread_mutex_t rlock;
}

@property (readwrite, assign) id<QCPlugInOutputImageProvider> depthProvider;
@property (readwrite, assign) id<QCPlugInOutputImageProvider> imageProvider;

@property (readwrite, assign) BOOL correctColor;
@property (readwrite, assign) BOOL useIRImageFormat;
@property (readwrite, assign) BOOL needNewRGBImage;
@property (readwrite, assign) BOOL needNewDepthImage;
@property (readwrite, assign) double tilt; 

@property (readwrite, assign) freenect_resolution resolution;
@property (readwrite, assign) NSSize selectedResolutionRGB;
@property (readwrite, assign) NSSize selectedResolutionIR;
@property (readwrite, assign) NSSize selectedResolutionDepth;

@property (readwrite) NSUInteger deviceID;
@property (readwrite) unsigned char *IR;
@property (readwrite) unsigned char *rgb;
@property (readwrite) uint16 *depth;
@property (readwrite) freenect_registration* registration;

@property (readwrite, assign) double accelX;
@property (readwrite, assign) double accelY;
@property (readwrite, assign) double accelZ;

// Plugin IO ports
@property (readwrite, assign) NSUInteger inputDeviceID;
@property (readwrite, assign) double inputTilt;
@property (readwrite, assign) NSUInteger inputColorFormat;
@property (readwrite, assign) NSUInteger inputDepthFormat;
@property (readwrite, assign) BOOL inputCorrectDepth;
@property (readwrite, assign) BOOL inputCorrectColor;
// @property (readwrite, assign) NSUInteger inputResolution;

@property (assign) id <QCPlugInOutputImageProvider> outputColorImage;
@property (assign) id <QCPlugInOutputImageProvider> outputDepthImage;
@property (assign) double outputAccelX;
@property (assign) double outputAccelY;
@property (assign) double outputAccelZ;
@end

@interface v002_Open_KinectPlugIn (Execution)
- (void) setupGL:(CGLContextObj) cgl_ctx;
- (void) tearDownGL:(CGLContextObj) cgl_ctx;

- (void) backgroundThread;
- (void) switchToColorMode;
- (void) switchToIRMode;
@end
