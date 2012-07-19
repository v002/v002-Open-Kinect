
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
#define	kQCPlugIn_Description		@"Open Kinect (libfreenect) based Microsoft Kinect interface. Supports multiple Kinects. Control the tilt, and get floating point depth information, color, infra red images, perform depth unprojection and color rectification, as well as get accelerometer data from one or more connected Kinects"

// Timing - Kinect polls at 1/30th second. Multiply by nyquist so we dont miss anything
#define kv002OpenKinectTimeInterval 1.0/( 30.0 * 2.2)


#pragma mark - Helpers

static dispatch_source_t CreateDispatchTimer(uint64_t interval, uint64_t leeway, dispatch_queue_t queue, dispatch_block_t block)
{
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    if (timer)
    {
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), interval, leeway);
        dispatch_source_set_event_handler(timer, block);
    }
    return timer;
}

#pragma mark - LibFreenect Callbacks

static void rgb_cb(freenect_device *dev, void *rgb, uint32_t timestamp)
{
	v002_Open_KinectPlugIn* pluginInstance = freenect_get_user(dev);
    
    if(pluginInstance.kinectInUse)
    {
        if(pluginInstance.useIRImageFormat)
        {
            NSSize s = pluginInstance.selectedResolutionIR;
            size_t size = s.width * s.height * sizeof(unsigned char);
            memcpy(pluginInstance.textureIR, pluginInstance.IR, size);
        }
        else
        {
            NSSize s = pluginInstance.selectedResolutionRGB;
            size_t size = s.width * s.height * sizeof(unsigned char) * 3;
            memcpy(pluginInstance.textureRGB, pluginInstance.rgb, size);
        }
        
        pluginInstance.needNewRGBImage = TRUE;
    }
}

static void depth_cb(freenect_device *dev, freenect_depth_format *d, uint32_t timestamp)
{
    v002_Open_KinectPlugIn* pluginInstance = freenect_get_user(dev);

    //NSLog(@"Depth Callback from plugin %p", pluginInstance);

    if(pluginInstance.kinectInUse)
    {
        NSSize s = pluginInstance.selectedResolutionDepth;
        size_t size = s.width * s.height * sizeof(uint16);
        memcpy(pluginInstance.textureDepth, pluginInstance.depth, size);

        pluginInstance.needNewDepthImage = TRUE;
    }
}


#pragma mark - QC Callbacks
static void MyQCPlugInBufferReleaseCallback (const void* address, void * context)
{
   // free((void*)address);
}

static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
	glDeleteTextures(1, &name);
}    

#pragma mark -

@implementation v002_Open_KinectPlugIn

@synthesize kinectInUse;

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
@synthesize textureIR;
@synthesize textureRGB;
@synthesize textureDepth;
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
    return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey,
            [kQCPlugIn_Description stringByAppendingString:kv002DescriptionAddOnText], QCPlugInAttributeDescriptionKey,
            kQCPlugIn_Category, @"categories", nil]; // Horrible work around

}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
    if([key isEqualToString:@"inputDeviceID"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Device ID", QCPortAttributeNameKey,
                [NSNumber numberWithUnsignedInteger:0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey,
                nil];
//    Resolution not quite working yet.
//    if([key isEqualToString:@"inputResolution"])
//		return [NSDictionary dictionaryWithObjectsAndKeys:@"Resolution", QCPortAttributeNameKey, 
//                [NSArray arrayWithObjects:@"Low (320 x 240)", @"Medium (640 x 480)", @"High (1280 x 1024)", nil], QCPortAttributeMenuItemsKey,
//				[NSNumber numberWithUnsignedInteger:1], QCPortAttributeDefaultValueKey,
//				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey,
//				[NSNumber numberWithUnsignedInteger:2], QCPortAttributeMaximumValueKey, nil]; 
    
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
    return @[@"inputDeviceID",
            @"inputDepthFormat",
            @"inputColorFormat",
            @"inputTilt",
            @"inputCorrectDepth",
            @"inputCorrectColor",
            @"outputColorImage",
            @"outputDepthImage",
            @"outputAccelX",
            @"outputAccelY",
            @"outputAccelZ"];
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
        f_ctx = NULL;
        f_dev = NULL;
        
        // kinect startup handling        
        if (freenect_init(&f_ctx, usb_ctx) < 0)
        {
            NSLog(@"freenect_init() failed %p", self);
            return nil;
        }
        
        freenect_set_log_level(f_ctx, FREENECT_LOG_ERROR);
        
        freenect_select_subdevices(f_ctx, (freenect_device_flags)(FREENECT_DEVICE_MOTOR | FREENECT_DEVICE_CAMERA));
        
        int nr_devices = freenect_num_devices(f_ctx);
        NSLog(@"Number of devices found: %d", nr_devices);

        self.kinectInUse = NO;
        
		self.deviceID = UINT_MAX;
                
        self.needNewDepthImage = FALSE;
        self.needNewRGBImage = FALSE;
        
        // For now, we dont actually change this..
        self.resolution = FREENECT_RESOLUTION_MEDIUM;
        self.selectedResolutionIR = NSMakeSize(640, 480);
        self.selectedResolutionRGB = NSMakeSize(640, 480);
        self.selectedResolutionDepth = NSMakeSize(640, 480);
        
        // Color RGB Image
        self.rgb = malloc(self.selectedResolutionRGB.width * self.selectedResolutionRGB.height * 3 * sizeof(unsigned char));
        self.textureRGB = malloc(self.selectedResolutionRGB.width * self.selectedResolutionRGB.height * 3 * sizeof(unsigned char));
        
        //"Color" IR image, 8 bit Intensity
        self.IR = malloc(self.selectedResolutionIR.width * self.selectedResolutionIR.height * sizeof(unsigned char));
        self.textureIR = malloc(self.selectedResolutionIR.width * self.selectedResolutionIR.height * sizeof(unsigned char));
        
        // depth
        self.depth = malloc(self.selectedResolutionDepth.width * self.selectedResolutionDepth.height  * sizeof(uint16));
        self.textureDepth = malloc(self.selectedResolutionDepth.width * self.selectedResolutionDepth.height  * sizeof(uint16));
    }
	
	return self;
}

- (void) finalize
{
    if(f_ctx)
        freenect_shutdown(f_ctx);
    
    f_ctx = NULL;

    // free local resources
    free(self.IR);
    free(self.rgb);
    free(self.depth);
    
    free(self.textureIR);
    free(self.textureRGB);
    free(self.textureDepth);
    
    self.IR = NULL;
    self.rgb = NULL;
    self.depth = NULL;
    
    self.textureIR = NULL;
    self.textureRGB = NULL;
    self.textureDepth = NULL;

	[super finalize];
}

- (void) dealloc
{
    if(f_ctx)
        freenect_shutdown(f_ctx);
    
    f_ctx = NULL;
    
    // free local resources
    free(self.IR);
    free(self.rgb);
    free(self.depth);
    
    free(self.textureIR);
    free(self.textureRGB);
    free(self.textureDepth);
    
    self.IR = NULL;
    self.rgb = NULL;
    self.depth = NULL;
    
    self.textureIR = NULL;
    self.textureRGB = NULL;
    self.textureDepth = NULL;

	[super dealloc];
}

@end

#pragma mark -

@implementation v002_Open_KinectPlugIn (Execution)

- (BOOL) startExecution:(id<QCPlugInContext>)context
{
	NSLog(@"start Excecute");

    CGLContextObj cgl_ctx = [context CGLContextObj];

    [self setupGL:cgl_ctx];

    kinectQueue = dispatch_queue_create("info.v002.v002OpenKinect", DISPATCH_QUEUE_SERIAL);
        
    kinectTimer = CreateDispatchTimer(kv002OpenKinectTimeInterval * NSEC_PER_SEC,  kv002OpenKinectTimeInterval * 0.5 * NSEC_PER_SEC,
                                      kinectQueue,
                                      ^{
                                          [self periodicKinectProcessEffects];
                                      });
    dispatch_resume(kinectTimer);
    
    return YES;
}

- (void) enableExecution:(id<QCPlugInContext>)context
{
}

- (void) disableExecution:(id<QCPlugInContext>)context
{
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
    NSLog(@"Stop Excecute");
    
    CGLContextObj cgl_ctx = [context CGLContextObj];
    
    [self tearDownGL:cgl_ctx];
       
    dispatch_source_cancel(kinectTimer);
    dispatch_release(kinectTimer);
    
    [self syncTearDownKinect];
    
    dispatch_release(kinectQueue);
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
        		
//        CGLContextObj cgl_ctx = [context CGLContextObj];
        
        dispatch_suspend(kinectTimer);

        [self aSyncTearDownKinect];

        [self aSyncSetupKinect];
        
        dispatch_resume(kinectTimer);
    }
	
    if([self didValueForInputKeyChange:@"inputTilt"])
    {
        self.tilt = self.inputTilt;
        [self setTiltDegs];
    }
    
    if([self didValueForInputKeyChange:@"inputColorFormat"] || [self didValueForInputKeyChange:@"inputCorrectColor"])
    {
        self.useIRImageFormat = self.inputColorFormat;
        self.correctColor = self.inputCorrectColor;
		
        if(!self.useIRImageFormat)
            [self switchToColorMode];
		else
            [self switchToIRMode];
    }
        
    if( self.kinectInUse && (self.needNewDepthImage || self.needNewRGBImage) && (fbo && rawDepthTexture && rawRGBTexture && rawInfraTexture) )
    {        
        self.needNewDepthImage = FALSE;
        self.needNewRGBImage = FALSE;

        void* texturePointer = NULL;
        NSSize textureSize = NSZeroSize;
        GLsizei textureWidth = 0;
        GLsizei textureHeight = 0;
        
        CGLContextObj cgl_ctx = [context CGLContextObj];
        
        // State saving
        glPushAttrib(GL_ALL_ATTRIB_BITS);
        glPushClientAttrib(GL_CLIENT_ALL_ATTRIB_BITS);
        
        glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT, &previousFBO);
        glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING_EXT, &previousReadFBO);
        glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING_EXT, &previousDrawFBO);        
        
        // Update Depth Texture
        glEnable(GL_TEXTURE_RECTANGLE_EXT);

        texturePointer = self.textureDepth;
        textureSize = self.selectedResolutionDepth;
        textureWidth = textureSize.width;
        textureHeight = textureSize.height;
        
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rawDepthTexture);
        glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
        glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, textureWidth * textureHeight * sizeof(uint16), texturePointer);
        glTexParameteri(GL_TEXTURE_RECTANGLE_ARB,GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);
        glTexSubImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, 0, 0, textureWidth, textureHeight, GL_LUMINANCE, GL_UNSIGNED_SHORT, texturePointer);
                
        if(!self.useIRImageFormat)
        {
            texturePointer = self.textureRGB;
            textureSize = self.selectedResolutionRGB;
            textureWidth = textureSize.width;
            textureHeight = textureSize.height;
            
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rawRGBTexture);
            glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
            glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, textureWidth * textureHeight *3 * sizeof(unsigned char), texturePointer);
            glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);
            glTexSubImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, 0, 0, textureWidth, textureHeight, GL_RGB, GL_UNSIGNED_BYTE, texturePointer);
        } 
        else
        {
            texturePointer = self.textureIR;
            textureSize = self.selectedResolutionIR;
            textureWidth = textureSize.width;
            textureHeight = textureSize.height;
            
            glBindTexture(GL_TEXTURE_RECTANGLE_EXT, rawInfraTexture);
            glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_TRUE);
            glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, textureWidth * textureHeight * sizeof(unsigned char), texturePointer);            
            glTexParameteri(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_SHARED_APPLE);
            glTexSubImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, 0, 0, textureWidth, textureHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, texturePointer);
        }
        
        // Reset Texture Storage optimizations.
        glPixelStorei(GL_UNPACK_CLIENT_STORAGE_APPLE, GL_FALSE);
        glTextureRangeAPPLE(GL_TEXTURE_RECTANGLE_EXT, 0, NULL);
        glTexParameteri(GL_TEXTURE_RECTANGLE_ARB,GL_TEXTURE_STORAGE_HINT_APPLE, GL_STORAGE_PRIVATE_APPLE);            

        // create 2 new textures for our FBO / this ensures our output image provider has unique textures for every output.
        
        // Depth or Position Float Texture
        GLuint floatTexture = 0;
        glGenTextures(1, &floatTexture);
        glEnable(GL_TEXTURE_RECTANGLE_EXT);    
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, floatTexture);
        
        glTexImage2D(GL_TEXTURE_RECTANGLE_EXT, 0, GL_RGBA32F_ARB, self.selectedResolutionDepth.width, self.selectedResolutionDepth.height, 0, GL_RGBA, GL_FLOAT, NULL); 
        
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
        
//        glClearColor(0.0, 0.0, 0.0, 0.0);
//        glClear(GL_COLOR_BUFFER_BIT);
        
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
        id<QCPlugInOutputImageProvider> depthProvider = nil;
        depthProvider = [context outputImageProviderFromTextureWithPixelFormat:QCPlugInPixelFormatRGBAf
                                                                         pixelsWide:self.selectedResolutionDepth.width
                                                                         pixelsHigh:self.selectedResolutionDepth.height
                                                                               name:floatTexture
                                                                            flipped:YES
                                                                    releaseCallback:_TextureReleaseCallback
                                                                     releaseContext:nil
                                                                         colorSpace:[context colorSpace]
                                                                   shouldColorMatch:YES];  
        
        // Width is used from depth, since final rendered images use that as size metric
        id<QCPlugInOutputImageProvider> imageProvider = nil;
        imageProvider = [context outputImageProviderFromTextureWithPixelFormat:(usingFloatWorkaround) ? QCPlugInPixelFormatRGBAf : QCPlugInPixelFormatARGB8
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
        
        self.outputColorImage = imageProvider;
        self.outputDepthImage = depthProvider;
        
        // Accel info.
        self.outputAccelX = self.accelX;
        self.outputAccelY = self.accelY;
        self.outputAccelZ = self.accelZ;
    }
   
    return YES;
}

#pragma mark - OpenGL

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

#pragma mark - Kinect Queue Methods

- (void) syncSetupKinect
{
    // Block on setup and teardown?
    dispatch_sync(kinectQueue, ^{
        [self setupKinect];
    });
}

- (void) aSyncSetupKinect
{
    // Block on setup and teardown?
    dispatch_async(kinectQueue, ^{
        [self setupKinect];
    });
}

// Call this on our Kinect Queue
- (void) setupKinect
{        
    if(self.deviceID < UINT_MAX)
    {
        NSLog(@"Begin setupKinect from plugin %p", self);
                  
        int device = self.deviceID;
        if (freenect_open_device(f_ctx, &f_dev, device) < 0)
        {
            NSLog(@"Could not open device %p", self);

            [self aSyncTearDownKinect];

            return;
        }
        NSLog(@"Opened device %i On %p", device, self);
        
        if(freenect_set_led(f_dev, LED_GREEN) < 0)
            NSLog(@"Could not set LED Green %p", self);

        freenect_set_user(f_dev, self);
        
        if(self.useIRImageFormat)
        {
            if(freenect_set_video_mode(f_dev, freenect_find_video_mode(self.resolution, FREENECT_VIDEO_IR_8BIT)) < 0)
                NSLog(@"Could not set Video Mode %p", self);

            if(freenect_set_video_buffer(f_dev, self.IR) < 0)
                NSLog(@"Could not set Video Buffer %p", self);
            
            if(freenect_set_depth_mode(f_dev, freenect_find_depth_mode(self.resolution, FREENECT_DEPTH_MM)) < 0)
                NSLog(@"Could not set Depth Mode Mode %p", self);
        }
        else
        {
            if(freenect_set_video_mode(f_dev, freenect_find_video_mode(self.resolution, FREENECT_VIDEO_RGB)) < 0)
                NSLog(@"Could not set Video Mode %p", self);

            if(freenect_set_video_buffer(f_dev, self.rgb) < 0)
                NSLog(@"Could not set Video Buffer %p", self);
            
            if(self.correctColor)
            {
                if(freenect_set_depth_mode(f_dev, freenect_find_depth_mode(self.resolution, /*FREENECT_DEPTH_11BIT*/ FREENECT_DEPTH_REGISTERED)) < 0)
                    NSLog(@"Could not set Depth Mode %p", self);
            }
            else
                if(freenect_set_depth_mode(f_dev, freenect_find_depth_mode(self.resolution, FREENECT_DEPTH_MM)) < 0)
                    NSLog(@"Could not set Depth Mode %p", self);
        }
        
        freenect_set_video_callback(f_dev, (freenect_video_cb) rgb_cb);
        
        if(freenect_set_depth_buffer(f_dev, self.depth) > 0)
            NSLog(@"Could not set Depth Buffer %p", self);

        freenect_set_depth_callback(f_dev, (freenect_depth_cb) depth_cb);
        
        if(freenect_start_video(f_dev))
            NSLog(@"Could not Start Video %p", self);
        
        if(freenect_start_depth(f_dev))
            NSLog(@"Could not Start Depth %p", self);

        self.kinectInUse = YES;
    }
}

- (void) syncTearDownKinect
{
    dispatch_sync(kinectQueue, ^{

        [self tearDownKinect];
    });
}

- (void) aSyncTearDownKinect
{
    dispatch_async(kinectQueue, ^{
        
        [self tearDownKinect];
    });
}

// Call this on our Kinect Queue
- (void) tearDownKinect
{    
    // ensure teardown is syncronous
    if(self.kinectInUse)
    {
        self.kinectInUse = NO;
        self.needNewDepthImage = NO;
        self.needNewRGBImage = NO;
        
        if(f_dev)
        {        
            // kinect shutdown handling
            freenect_update_tilt_state(f_dev);
            freenect_stop_depth(f_dev);
            freenect_stop_video(f_dev);
            freenect_set_led(f_dev, LED_YELLOW);
            
            freenect_close_device(f_dev);
        }
        
        f_dev = NULL;
    }
}

// This is the background thread where we handle our freekinect callbacks.
- (void) periodicKinectProcessEffects
{
    // Move to shorter timeout?
    struct timeval timeout;
	timeout.tv_sec = 10; // was 60
	timeout.tv_usec = 0; // was 0
    
    if(f_dev && f_ctx && self.kinectInUse)
    {
        //if(freenect_process_events_timeout(f_ctx, &timeout) >=0)
        if(freenect_process_events(f_ctx) >= 0)
        {
            double x,y,z;
            
            freenect_update_tilt_state(f_dev);
            freenect_raw_tilt_state* state = freenect_get_tilt_state(f_dev);
            freenect_get_mks_accel(state, &x, &y, &z);
            
            self.accelX = x;
            self.accelY = y;
            self.accelZ = z;
        }
    }
}

- (void) setTiltDegs
{
    dispatch_async(kinectQueue, ^{
        if(f_dev != NULL)
        freenect_set_tilt_degs(f_dev, self.tilt);
    });
}

- (void) switchToColorMode
{
    dispatch_suspend(kinectTimer);

    dispatch_async(kinectQueue, ^{
        
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

        dispatch_resume(kinectTimer);
    });
}

- (void) switchToIRMode
{
    dispatch_suspend(kinectTimer);
    
    dispatch_async(kinectQueue, ^{
        
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
        
        dispatch_resume(kinectTimer);
    });
}

@end
