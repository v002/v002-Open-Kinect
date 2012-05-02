//
//  v002_Open_KinectPlugIn.m
//  v002 Open Kinect
//
//  Created by vade on 1/24/11.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
#import <OpenGL/CGLMacro.h>

#import <Accelerate/Accelerate.h>

#import "v002_Open_KinectPlugIn.h"

#import "libfreenect.h"

#define	kQCPlugIn_Name				@"v002 Open Kinect"
#define	kQCPlugIn_Description		@"Open Kinect (libfreenect) based Kinect interface. Control the tilt, and get floating point depth information, color, infra red, accelerometer from a connected Kinect"

#pragma mark -
#pragma mark QC Callbacks
static void MyQCPlugInBufferReleaseCallback (const void* address, void * context)
{
   // free((void*)address);
}

static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
	// our IOSurface to GL routine makes new texture IDs, so we blast em.
	glDeleteTextures(1, &name);
}    

#pragma mark -

@implementation v002_Open_KinectPlugIn

@synthesize depthProvider;
@synthesize imageProvider;

@synthesize useIRImageFormat;
@synthesize needNewRGBImage;
@synthesize needNewDepthImage;

@synthesize tilt;
@synthesize resolution;
@synthesize correctColor;

@synthesize selectedResolutionRGB;
@synthesize selectedResolutionIR;
@synthesize selectedResolutionDepth;

@synthesize IR;
@synthesize rgb;
@synthesize depth;
@synthesize registration;

@synthesize deviceID;
@synthesize accelX;
@synthesize accelY;
@synthesize accelZ;

//Port IO
@dynamic inputDeviceID;
@dynamic inputTilt;
@dynamic inputDepthFormat;
@dynamic inputColorFormat;
@dynamic inputCorrectDepth;
@dynamic inputCorrectColor;
//@dynamic inputResolution;

@dynamic outputColorImage;
@dynamic outputDepthImage;
@dynamic outputAccelX;
@dynamic outputAccelY;
@dynamic outputAccelZ;

+ (NSDictionary*) attributes
{
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
    if([key isEqualToString:@"inputDeviceID"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Device ID", QCPortAttributeNameKey,
                [NSNumber numberWithUnsignedInteger:0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey,
                nil];
//
//    if([key isEqualToString:@"inputResolution"])
//		return [NSDictionary dictionaryWithObjectsAndKeys:@"Resolution", QCPortAttributeNameKey, 
//                [NSArray arrayWithObjects:@"Low (320 x 240)", @"Medium (640 x 480)", @"High (1280 x 1024)", nil], QCPortAttributeMenuItemsKey,
//				[NSNumber numberWithUnsignedInteger:1], QCPortAttributeDefaultValueKey,
//				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey,
//				[NSNumber numberWithUnsignedInteger:2], QCPortAttributeMaximumValueKey, nil]; 
//
    
    if([key isEqualToString:@"inputColorFormat"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image Format", QCPortAttributeNameKey, 
                [NSArray arrayWithObjects:@"Color", @"Infra Red", nil], QCPortAttributeMenuItemsKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithUnsignedInteger:1], QCPortAttributeMaximumValueKey, nil]; 

    if([key isEqualToString:@"inputDepthFormat"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Depth Format", QCPortAttributeNameKey, 
                [NSArray arrayWithObjects:@"Depth Map (Greycale)", @"Position Map (RGB as XYZ)", nil], QCPortAttributeMenuItemsKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithUnsignedInteger:1], QCPortAttributeMaximumValueKey, nil]; 
    
    
    if([key isEqualToString:@"inputTilt"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Tilt Angle", QCPortAttributeNameKey, 
				[NSNumber numberWithDouble:0.0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithDouble:-30], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithDouble:30], QCPortAttributeMaximumValueKey, nil]; 

    if([key isEqualToString:@"inputCorrectDepth"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Depth Unprojection", QCPortAttributeNameKey, nil];

    if([key isEqualToString:@"inputCorrectColor"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Color Rectification", QCPortAttributeNameKey, nil];

    
    if([key isEqualToString:@"outputColorImage"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];

    if([key isEqualToString:@"outputDepthImage"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Depth Image", QCPortAttributeNameKey, nil];

    if([key isEqualToString:@"outputAccelX"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Accelerometer X", QCPortAttributeNameKey, nil];

    if([key isEqualToString:@"outputAccelY"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Accelerometer Y", QCPortAttributeNameKey, nil];

    if([key isEqualToString:@"outputAccelZ"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Accelerometer Z", QCPortAttributeNameKey, nil];

	return nil;
}

+ (NSArray*) sortedPropertyPortKeys
{
    return [NSArray arrayWithObjects:@"inputDeviceID",
            @"inputDepthFormat",
            @"inputColorFormat",
            @"inputTilt",
            @"inputCorrectDepth",
            @"inputCorrectColor",
            @"outputColorImage",
            @"outputDepthImage",
            @"outputAccelX",
            @"outputAccelY",
            @"outputAccelZ",
            nil];
}

+ (QCPlugInExecutionMode) executionMode
{
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode) timeMode
{
	return kQCPlugInTimeModeIdle;
}

- (id) init
{
	if(self = [super init])
    {
		self.deviceID = 0;
        
        self.depthProvider = nil;
        self.imageProvider = nil;
        
        self.needNewDepthImage = FALSE;
        self.needNewRGBImage = FALSE;
        
        self.resolution = FREENECT_RESOLUTION_MEDIUM;
        self.selectedResolutionIR = NSMakeSize(640, 480);
        self.selectedResolutionRGB = NSMakeSize(640, 480);
        self.selectedResolutionDepth = NSMakeSize(640, 480);
        
        pthread_mutex_init(&rlock, NULL);
    }
	
	return self;
}

- (void) finalize
{
	[super finalize];
}

- (void) dealloc
{	
    if([kinectThread isExecuting])
    {
        while([kinectThread isExecuting])
            [kinectThread cancel];
        
        [kinectThread release];
        kinectThread = nil;
    }
    
    pthread_mutex_destroy(&rlock);
    
	[super dealloc];
}

@end

#pragma mark -

@implementation v002_Open_KinectPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{	    
    CGLContextObj cgl_ctx = [context CGLContextObj];
    
	NSLog(@"start Execute");
	
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
	
		// Spawn our background kinect capture thread
		kinectThread = [[NSThread alloc] initWithTarget:self selector:@selector(backgroundThread) object:nil];
		[kinectThread start];
	});
        
	
	NSLog(@"start Execute 2");

    [self setupGL:cgl_ctx];
    
	NSLog(@"start Execute 3");

    return YES;
}

- (void) enableExecution:(id<QCPlugInContext>)context
{
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{    
	
	if([self didValueForInputKeyChange:@"inputDeviceID"] /*|| [self didValueForInputKeyChange:@"inputResolution"]*/ )
	{
		self.deviceID = self.inputDeviceID;
  
        // This was a bad idea, as depth and video modes can be out of sync size wise. 
//        switch (self.inputResolution) 
//        {
//            case 0:
//                self.resolution = FREENECT_RESOLUTION_LOW;
//                self.selectedResolutionIR = NSMakeSize(640, 488);
//                self.selectedResolutionRGB = NSMakeSize(640, 480);
//                self.selectedResolutionDepth = NSMakeSize(640, 480);
//
//               // break;
//            case 1:
//                self.resolution = FREENECT_RESOLUTION_MEDIUM;
//                self.selectedResolutionIR = NSMakeSize(640, 488);
//                self.selectedResolutionRGB = NSMakeSize(640, 480);
//                self.selectedResolutionDepth = NSMakeSize(640, 480);
//
//                break;
//            case 2:
//                self.resolution = FREENECT_RESOLUTION_HIGH;
//                self.selectedResolutionIR = NSMakeSize(1280, 1024);
//                self.selectedResolutionRGB = NSMakeSize(640, 480);
//                self.selectedResolutionDepth = NSMakeSize(640, 480);
//
//                break;
//
//            default:
//                break;
//        }
        		
        CGLContextObj cgl_ctx = [context CGLContextObj];

        [self tearDownGL:cgl_ctx];
        
		// Restart the Kinect Thread
		if([kinectThread isExecuting])
		{
			while([kinectThread isExecuting])
				[kinectThread cancel];
			
			[kinectThread release];
			kinectThread = nil;
		}

		kinectThread = [[NSThread alloc] initWithTarget:self selector:@selector(backgroundThread) object:nil];
		[kinectThread start];
        
        [self setupGL:cgl_ctx];
	}
	
    if([self didValueForInputKeyChange:@"inputTilt"])
        self.tilt = self.inputTilt;
    
    if([self didValueForInputKeyChange:@"inputColorFormat"] || [self didValueForInputKeyChange:@"inputCorrectColor"])
    {
        self.useIRImageFormat = self.inputColorFormat;
        self.correctColor = self.inputCorrectColor;
		
        if(!self.useIRImageFormat)
            //[self switchToColorMode];
            //[self performSelector:@selector(switchToColorMode)];
            //[kinectThread switchToColorMode];
            //[self performSelector:@selector(switchToColorMode) onThread:kinectThread withObject:nil waitUntilDone:NO];
            //[self performSelectorOnMainThread:@selector(switchToColorMode) withObject:nil waitUntilDone:NO];
			[self performSelectorInBackground:@selector(switchToColorMode) withObject:nil];
		else
			[self performSelectorInBackground:@selector(switchToIRMode) withObject:nil];

            //[self performSelectorOnMainThread:@selector(switchToIRMode) withObject:nil waitUntilDone:NO];
            //[self switchToIRMode];
            //[self performSelector:@selector(switchToIRMode)];
            //[self performSelector:@selector(switchToIRMode) onThread:kinectThread withObject:nil waitUntilDone:NO];              
    }
        
    if( (self.needNewDepthImage || self.needNewRGBImage) && fbo && (rawDepthTexture && rawRGBTexture && rawInfraTexture) )
    {
        self.depthProvider = nil;
        self.imageProvider = nil;

        self.needNewDepthImage = FALSE;
        self.needNewRGBImage = FALSE;

        CGLContextObj cgl_ctx = [context CGLContextObj];
        
        // State saving
        glPushAttrib(GL_ALL_ATTRIB_BITS);
        glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
        
        glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);
        glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
        glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);        
        
        // Update Depth Texture
        glEnable(GL_TEXTURE_RECTANGLE_EXT);

        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rawDepthTexture);
        glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
        glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, self.selectedResolutionDepth.width * self.selectedResolutionDepth.height * sizeof(uint16), self.depth);
        glTexParameteri(GL_TEXTURE_RECTANGLE_ARB,GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);
        glTexSubImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, 0, 0, self.selectedResolutionDepth.width, self.selectedResolutionDepth.height, GL_LUMINANCE, GL_UNSIGNED_SHORT, self.depth);
        
        // TODO: update via TexSubImage...
        
        if(!self.useIRImageFormat)
        {
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rawRGBTexture);
            glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
            glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, self.selectedResolutionRGB.width * self.selectedResolutionRGB.width *3 * sizeof(unsigned char), self.rgb);
            glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);
            glTexSubImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, 0, 0, self.selectedResolutionRGB.width, self.selectedResolutionRGB.height, GL_RGB, GL_UNSIGNED_BYTE, self.rgb);
        } 
        else
        {
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rawInfraTexture);
            glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
            glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, self.selectedResolutionIR.width * self.selectedResolutionIR.height * sizeof(unsigned char), self.IR);            
            glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);
            glTexSubImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, 0, 0, self.selectedResolutionIR.width, self.selectedResolutionIR.height, GL_LUMINANCE, GL_UNSIGNED_BYTE, self.IR);
        }
        
        // Reset Texture Storage optimizations.
        glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE);
        glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, 0, NULL);
        glTexParameteri(GL_TEXTURE_RECTANGLE_ARB,GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_PRIVATE_APPLE);            

        // create 2 new textures for our FBO.
        
        // Depth or Position Float Texture
        GLuint floatTexture = 0;
        glGenTextures(1, &floatTexture);
        glEnable(GL_TEXTURE_RECTANGLE_EXT);    
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, floatTexture);
        
        glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA32F_ARB, self.selectedResolutionDepth.width, self.selectedResolutionDepth.height, 0, GL_RGBA, GL_FLOAT, NULL); 
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);        
        
        // Color 8 Bit Texture
        GLuint rgbaTexture = 0;
        glGenTextures(1, &rgbaTexture);
        glEnable(GL_TEXTURE_RECTANGLE_EXT);    
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rgbaTexture);
        glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA32F_ARB, self.selectedResolutionDepth.width, self.selectedResolutionDepth.height, 0, GL_RGBA, GL_FLOAT, NULL); 
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);        
        
        // Attach to our FBO
        glBindFramebuffer(GL_FRAMEBUFFER, fbo);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_RECTANGLE_ARB, floatTexture, 0);
        glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_RECTANGLE_ARB, rgbaTexture, 0);

        GLenum status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
        if(status != GL_FRAMEBUFFER_COMPLETE_EXT)
        {
            // This means we are probably on an x1600.
            // Workaround is to render 2 float textures. This avoids clamping
            // and lets the x1600 work, but slower than it would otherwise
        
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rgbaTexture);
            glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA8, self.selectedResolutionDepth.width, self.selectedResolutionDepth.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL); 
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);        
        
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_RECTANGLE_ARB, floatTexture, 0);
            glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT1, GL_TEXTURE_RECTANGLE_ARB, rgbaTexture, 0);

            usingFloatWorkaround = YES;
        }
        else
            usingFloatWorkaround = NO;        
        
        // Render
        GLenum buffers[] = {GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1};
        
        glDrawBuffers(2, buffers);
                
        glViewport(0, 0,  self.selectedResolutionDepth.width, self.selectedResolutionDepth.height);
        glMatrixMode(GL_PROJECTION);
        glPushMatrix();
        glLoadIdentity();
        
        glOrtho(0.0, self.selectedResolutionDepth.width,  0.0,  self.selectedResolutionDepth.height, -1, 1);		
        
        glMatrixMode(GL_MODELVIEW);
        glPushMatrix();
        glLoadIdentity();
        
        //glClearColor(0.0, 0.0, 0.0, 0.0);    
//        glClear(GL_COLOR_BUFFER_BIT);
//        
        glDisable(GL_BLEND);
		
		glColor4f(1.0, 1.0, 1.0, 1.0);

        glActiveTexture(GL_TEXTURE1);
        glEnable(GL_TEXTURE_RECTANGLE_EXT);
        if(!self.useIRImageFormat)
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rawRGBTexture);
        else 
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rawInfraTexture);
        
		glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		
        glActiveTexture(GL_TEXTURE0);
        glEnable(GL_TEXTURE_RECTANGLE_EXT);
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rawDepthTexture);
		glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

        // bind our shader program
        glUseProgramObjectARB([depthShader programObject]);
        
        // set program vars
        glUniform1iARB([depthShader getUniformLocation:"depthTexture"], 0); 
        glUniform1fARB([depthShader getUniformLocation:"correctDepth"], (GLfloat) self.inputCorrectDepth); 
        glUniform1iARB([depthShader getUniformLocation:"colorTexture"], 1); 
        // we only actually perform correction to RGB image
        //glUniform1fARB([depthShader getUniformLocation:"correctColor"], (GLfloat) self.inputCorrectColor && !self.inputColorFormat); 
        glUniform1fARB([depthShader getUniformLocation:"generatePositionMap"], (GLfloat) self.inputDepthFormat); 

        // move to VA for rendering
        GLfloat coords[] = 
        {
            self.selectedResolutionDepth.width,self.selectedResolutionDepth.height,
            0.0,self.selectedResolutionDepth.height,
            0.0,0.0,
            self.selectedResolutionDepth.width,0.0
        };
        glClientActiveTexture(GL_TEXTURE1);
        glEnableClientState( GL_TEXTURE_COORD_ARRAY );
        glTexCoordPointer(2, GL_FLOAT, 0, coords );
        
        glClientActiveTexture(GL_TEXTURE0);
        glEnableClientState( GL_TEXTURE_COORD_ARRAY );
        glTexCoordPointer(2, GL_FLOAT, 0, coords );
        
        glEnableClientState(GL_VERTEX_ARRAY);		
        glVertexPointer(2, GL_FLOAT, 0, coords );
        glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );
        
        // disable shader program
        glUseProgramObjectARB(NULL);
        
        glMatrixMode(GL_MODELVIEW);
        glPopMatrix();
        glMatrixMode(GL_PROJECTION);
        glPopMatrix();
		
        // Really don't see why we need this? Tom
        //glFlushRenderAPPLE();	
                
        // Restore State
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, previousFBO);	
        glBindFramebufferEXT(GL_READ_FRAMEBUFFER_EXT, previousReadFBO);
        glBindFramebufferEXT(GL_DRAW_FRAMEBUFFER_EXT, previousDrawFBO);
                
        // Image Providers
        self.depthProvider = [context outputImageProviderFromTextureWithPixelFormat:QCPlugInPixelFormatRGBAf
                                                                         pixelsWide:self.selectedResolutionDepth.width
                                                                         pixelsHigh:self.selectedResolutionDepth.height
                                                                               name:floatTexture
                                                                            flipped:YES
                                                                    releaseCallback:_TextureReleaseCallback
                                                                     releaseContext:nil
                                                                         colorSpace:[context colorSpace]
                                                                   shouldColorMatch:YES];  
        
        // Width is used as depth, since final rendered images use that as size metric
        self.imageProvider = [context outputImageProviderFromTextureWithPixelFormat:(usingFloatWorkaround) ? QCPlugInPixelFormatRGBAf : QCPlugInPixelFormatARGB8
                                                                         pixelsWide:self.selectedResolutionDepth.width
                                                                         pixelsHigh:self.selectedResolutionDepth.height
                                                                               name:rgbaTexture
                                                                            flipped:YES
                                                                    releaseCallback:_TextureReleaseCallback
                                                                     releaseContext:nil
                                                                         colorSpace:[context colorSpace]
                                                                   shouldColorMatch:YES];
        
        glPopClientAttrib();
        glPopAttrib();
    }
   
    self.outputColorImage = self.imageProvider;
    self.outputDepthImage = self.depthProvider;
    
    // Accel info.
    self.outputAccelX = self.accelX; 
    self.outputAccelY = self.accelY;
    self.outputAccelZ = self.accelZ;
    
    return YES;
}

- (void) disableExecution:(id<QCPlugInContext>)context
{
}

- (void) stopExecution:(id<QCPlugInContext>)context
{    
    CGLContextObj cgl_ctx = [context CGLContextObj];

    [self tearDownGL:cgl_ctx];
    
    // kill our previous background thead if we had one
    while([kinectThread isExecuting])
        [kinectThread cancel];

    [kinectThread release];
    kinectThread = nil;    
}

#pragma mark -

- (void) setupGL:(CGLContextObj) cgl_ctx
{
    glPushAttrib(GL_ALL_ATTRIB_BITS);
    glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
 
    NSBundle *pluginBundle =[NSBundle bundleForClass:[self class]];	
    depthShader = [[v002Shader alloc] initWithShadersInBundle:pluginBundle withName:@"v002.OpenKinectDepth" forContext:cgl_ctx];
    
    // create FBO
    glGenFramebuffers(1, &fbo);
    
    // Create Depth Texture;
    rawDepthTexture = 0;
    glGenTextures(1, &rawDepthTexture);
    glEnable(GL_TEXTURE_RECTANGLE_EXT);
    
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rawDepthTexture);
    glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_LUMINANCE16F_ARB, self.selectedResolutionDepth.width, self.selectedResolutionDepth.height, 0, GL_LUMINANCE, GL_UNSIGNED_SHORT, NULL);
        
    glGenTextures(1, &rawRGBTexture);
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rawRGBTexture);
    glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGB8, self.selectedResolutionRGB.width, self.selectedResolutionRGB.height, 0, GL_RGB, GL_UNSIGNED_BYTE, NULL);
    
    glGenTextures(1, &rawInfraTexture);
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rawInfraTexture);
    glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_LUMINANCE8, self.selectedResolutionIR.width, self.selectedResolutionIR.height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, NULL); 
    
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, 0);
    
    glPopAttrib();
    glPopClientAttrib();
}

- (void) tearDownGL:(CGLContextObj) cgl_ctx
{    
    [depthShader release];
    depthShader = nil;
    
    if(rawDepthTexture)
    {
        glDeleteTextures(1,&rawDepthTexture);
        rawDepthTexture = 0;
    }
    
    if(rawRGBTexture)
    {
        glDeleteTextures(1,&rawRGBTexture);
        rawRGBTexture = 0;
    }
    
    if(rawInfraTexture)
    {
        glDeleteTextures(1,&rawInfraTexture);
        rawInfraTexture = 0;
    }    
    
    if(fbo)
    {
        glDeleteFramebuffers(1, &fbo);
        fbo = 0;
    }    
}

// the RGB callback.
static void rgb_cb(freenect_device *dev, void *rgb, uint32_t timestamp)
{
	v002_Open_KinectPlugIn* self = freenect_get_user(dev);
    self.needNewRGBImage = TRUE;   
}

//static int max = 0;
//static int min = UINT16_MAX;

static void depth_cb(freenect_device *dev, freenect_depth_format *d, uint32_t timestamp)
{
    v002_Open_KinectPlugIn* self = freenect_get_user(dev);   
	
//	max = 0;
//	min = UINT16_MAX;
	
//	for(int x = 0; x < 640 * 480; x++)
//	{
//		int test = self.depth[x];
//		
//		self.depth[x] = test = (test > 1100) ? min : test; 
//		
//		min = MIN(min, test);
//		max = MAX(max, test);
//	}

	//NSLog(@"Min: %i, Max %i", min, max);

    self.needNewDepthImage = TRUE;
}

- (void) switchToColorMode
{
    if(f_dev != NULL)
    {
        freenect_stop_video(f_dev);
        freenect_set_video_mode(f_dev, freenect_find_video_mode(self.resolution, FREENECT_VIDEO_RGB));
        freenect_set_video_buffer(f_dev, self.rgb);
        freenect_set_video_callback(f_dev, &rgb_cb);
        freenect_start_video(f_dev);    
    
		freenect_stop_depth(f_dev);
		if(self.correctColor)
			freenect_set_depth_mode(f_dev, freenect_find_depth_mode(self.resolution, /*FREENECT_DEPTH_11BIT*/ FREENECT_DEPTH_REGISTERED));
		else
			freenect_set_depth_mode(f_dev, freenect_find_depth_mode(self.resolution, FREENECT_DEPTH_MM));
		freenect_set_depth_buffer(f_dev, self.depth);
		freenect_set_depth_callback(f_dev, (freenect_depth_cb) &depth_cb);
		freenect_start_depth(f_dev);
	}
}

- (void) switchToIRMode
{
    if(f_dev != NULL)
    {
        freenect_stop_video(f_dev);
        freenect_set_video_mode(f_dev, freenect_find_video_mode(self.resolution, FREENECT_VIDEO_IR_8BIT));
        freenect_set_video_buffer(f_dev, self.IR);
        freenect_set_video_callback(f_dev, &rgb_cb);
        freenect_start_video(f_dev);    
		
		freenect_stop_depth(f_dev);
		freenect_set_depth_mode(f_dev, freenect_find_depth_mode(self.resolution, FREENECT_DEPTH_MM));
		freenect_set_depth_buffer(f_dev, self.depth);
		freenect_set_depth_callback(f_dev, (freenect_depth_cb) &depth_cb);
		freenect_start_depth(f_dev);

    }
}

// This is the background thread where we handle our freekinect callbacks.
- (void) backgroundThread
{
    NSLog(@"background thread starting");
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    
    // Color RGB Image
    self.rgb = malloc(self.selectedResolutionRGB.width * self.selectedResolutionRGB.height * 3 * sizeof(unsigned char));

     //"Color" IR image, 8 bit Intensity
    self.IR = malloc(self.selectedResolutionIR.width * self.selectedResolutionIR.height * sizeof(unsigned char));

    // depth
    self.depth = malloc(self.selectedResolutionDepth.width * self.selectedResolutionDepth.height  * sizeof(uint16));
    
    // kinect startup handling
    
    if (freenect_init(&f_ctx, NULL) < 0)
    {
		NSLog(@"freenect_init() failed");
        return;
	}

    freenect_set_log_level(f_ctx, FREENECT_LOG_ERROR);
    
//	int nr_devices = freenect_num_devices(f_ctx);
//	NSLog(@"Number of devices found: %d", nr_devices);
    
    // TODO: test with more than 1 kinect
    // self.inputDeviceNumber
    if (freenect_open_device(f_ctx, &f_dev, self.deviceID) < 0)
	{
        NSLog(@"Could not open device");    
        return;
    }
    
    NSLog(@"Opened device %u", self.deviceID);    
    
    freenect_set_led(f_dev, LED_GREEN);
    freenect_set_user(f_dev, self);
        
    if(self.useIRImageFormat)
    {
        freenect_set_video_mode(f_dev, freenect_find_video_mode(self.resolution, FREENECT_VIDEO_IR_8BIT));
        freenect_set_video_buffer(f_dev, self.IR);

		freenect_set_depth_mode(f_dev, freenect_find_depth_mode(self.resolution, FREENECT_DEPTH_MM));
    }
    else
    {
        freenect_set_video_mode(f_dev, freenect_find_video_mode(self.resolution, FREENECT_VIDEO_RGB));
        freenect_set_video_buffer(f_dev, self.rgb);
		
		if(self.correctColor)
			freenect_set_depth_mode(f_dev, freenect_find_depth_mode(self.resolution, /*FREENECT_DEPTH_11BIT*/ FREENECT_DEPTH_REGISTERED));
		else
			freenect_set_depth_mode(f_dev, freenect_find_depth_mode(self.resolution, FREENECT_DEPTH_MM));
	}

	freenect_set_video_callback(f_dev, &rgb_cb);
      
	freenect_set_depth_buffer(f_dev, self.depth);
	freenect_set_depth_callback(f_dev, (freenect_depth_cb) &depth_cb);
    freenect_start_video(f_dev);
    freenect_start_depth(f_dev);
    
    while (![[NSThread currentThread] isCancelled] && (freenect_process_events(f_ctx) >= 0))
    {
        freenect_set_tilt_degs(f_dev, self.tilt);
        
        double x,y,z;
        
        freenect_update_tilt_state(f_dev);
        freenect_raw_tilt_state* state = freenect_get_tilt_state(f_dev);
        freenect_get_mks_accel(state, &x, &y, &z);
        
        self.accelX = x;
        self.accelY = y;
        self.accelZ = z;
        
        //usleep(5000);
    }
    
    self.needNewDepthImage = NO;
    self.needNewRGBImage = NO;
    
    // kinect shutdown handling
	freenect_update_tilt_state(f_dev);
	freenect_stop_depth(f_dev);
	freenect_stop_video(f_dev);
	freenect_set_led(f_dev, LED_YELLOW);
    
	freenect_close_device(f_dev);
	freenect_shutdown(f_ctx);

    f_dev = NULL;
    f_ctx = NULL;
    
    // free local resources
    free(self.IR);
    free(self.rgb);
    free(self.depth);

    self.IR = NULL;
    self.rgb = NULL;
    self.depth = NULL;
    
    [pool drain];
 
    NSLog(@"background thread ending");
}

@end