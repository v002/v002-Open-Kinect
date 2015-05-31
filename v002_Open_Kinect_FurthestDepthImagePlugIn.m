//
//  v002_Open_Kinect_FurthestDepthImage.m
//  v002 Open Kinect
//
//  Created by vade on 5/30/15.
//
//

#import <OpenGL/CGLMacro.h>

#import "v002FBO.h"
#import "v002Shader.h"

#import "v002_Open_Kinect_FurthestDepthImagePlugIn.h"

#define	kQCPlugIn_Name				@"v002 Open Kinect Furthest Depth"
#define	kQCPlugIn_Description		@"Provides the furthest seen depth and color pixels at the furthest depth providing you with best case, uninterrupted background."

// hack to return tuple ugh.
typedef struct  {
    GLuint colorResult;
    GLuint depthResult;
} MRTResult;

static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
    glDeleteTextures(1, &name);
}

@implementation v002_Open_Kinect_FurthestDepthImagePlugIn

@dynamic inputColorImage;
@dynamic inputDepthImage;
@dynamic inputLastColorImage;
@dynamic inputLastDepthImage;
@dynamic inputReset;

@dynamic outputFurthestColorImage;
@dynamic outputFurthestDepthImage;

+ (NSDictionary*) attributes
{
    return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey,
            [kQCPlugIn_Description stringByAppendingString:kv002DescriptionAddOnText], QCPlugInAttributeDescriptionKey,
            kQCPlugIn_Category, @"categories", nil]; // Horrible work around
    
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
    if([key isEqualToString:@"inputColorImage"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
    
    if([key isEqualToString:@"inputDepthImage"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Depth Image", QCPortAttributeNameKey, nil];

    if([key isEqualToString:@"outputFurthestColorImage"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Furthest Image", QCPortAttributeNameKey, nil];
    
    if([key isEqualToString:@"outputFurthestDepthImage"])
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Furthest Depth Image", QCPortAttributeNameKey, nil];
    
    return nil;
}

+ (NSArray*) sortedPropertyPortKeys
{
    return @[@"inputColorImage",
             @"inputDepthImage",
             @"outputFurthestColorImage",
             @"outputFurthestDepthImage",
             ];
}

+ (QCPlugInExecutionMode) executionMode
{
    return kQCPlugInExecutionModeProcessor;
}

+ (QCPlugInTimeMode) timeMode
{
    return kQCPlugInTimeModeNone;
}

- (id) init
{
    self = [super init];
    if(self)
    {
        self.pluginShaderName = @"v002.OpenKinectFurthestDepth";
    }
    return self;
}

- (void) finalize
{
    [super finalize];
}
- (void) dealloc
{
    [super dealloc];
}

@end

#pragma mark -

@implementation v002_Open_Kinect_FurthestDepthImagePlugIn (Execution)

// load shader
- (BOOL) startExecution:(id<QCPlugInContext>)context
{
    return [super startExecution:context];
}

// unload shader
- (void) stopExecution:(id<QCPlugInContext>)context
{
    [super stopExecution:context];
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
    CGLContextObj cgl_ctx = [context CGLContextObj];
    
    // lock our two input textures
    id<QCPlugInInputImageSource> colorImage = self.inputColorImage;
    id<QCPlugInInputImageSource> depthImage = self.inputDepthImage;
    id<QCPlugInInputImageSource> lastColorImage = self.inputLastColorImage;
    id<QCPlugInInputImageSource> lastDepthImage = self.inputLastDepthImage;
    
    CGColorSpaceRef ccspace = ([colorImage shouldColorMatch]) ? [context colorSpace] : [colorImage imageColorSpace];
    CGColorSpaceRef dcspace = ([depthImage shouldColorMatch]) ? [context colorSpace] : [depthImage imageColorSpace];
    
    CGColorSpaceRef lccspace = ([lastColorImage shouldColorMatch]) ? [context colorSpace] : [lastColorImage imageColorSpace];
    CGColorSpaceRef ldcspace = ([lastDepthImage shouldColorMatch]) ? [context colorSpace] : [lastDepthImage imageColorSpace];
    
    if([colorImage lockTextureRepresentationWithColorSpace:ccspace forBounds:[colorImage imageBounds]]
       && [depthImage lockTextureRepresentationWithColorSpace:dcspace forBounds:[depthImage imageBounds]]
       )
    {
        [colorImage bindTextureRepresentationToCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0 normalizeCoordinates:YES];
        [depthImage bindTextureRepresentationToCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE1 normalizeCoordinates:YES];

        if(lastColorImage && [lastColorImage lockTextureRepresentationWithColorSpace:lccspace forBounds:[lastColorImage imageBounds]]
        && lastDepthImage && [lastDepthImage lockTextureRepresentationWithColorSpace:ldcspace forBounds:[lastDepthImage imageBounds]])
        {
            [lastColorImage bindTextureRepresentationToCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE2 normalizeCoordinates:YES];
            [lastDepthImage bindTextureRepresentationToCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE3 normalizeCoordinates:YES];
        }
        
        MRTResult* latestResult = [self renderToFBO:cgl_ctx colorImage:colorImage depthImage:depthImage lastColorImage:lastColorImage lastDepthImage:lastDepthImage reset:self.inputReset];

        
        if(lastColorImage && lastDepthImage)
        {
            [lastDepthImage unbindTextureRepresentationFromCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE3];
            [lastDepthImage unlockTextureRepresentation];
            
            [lastColorImage unbindTextureRepresentationFromCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE2];
            [lastColorImage unlockTextureRepresentation];
        }
        
        [depthImage unbindTextureRepresentationFromCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE1];
        [depthImage unlockTextureRepresentation];
        
        [colorImage unbindTextureRepresentationFromCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0];
        [colorImage unlockTextureRepresentation];

        id depth = [context outputImageProviderFromTextureWithPixelFormat:QCPlugInPixelFormatRGBAf
                                                               pixelsWide:[depthImage imageBounds].size.width
                                                               pixelsHigh:[depthImage imageBounds].size.height
                                                                     name:latestResult->depthResult
                                                                  flipped:[depthImage textureFlipped]
                                                          releaseCallback:_TextureReleaseCallback
                                                           releaseContext:latestResult
                                                               colorSpace:[context colorSpace]
                                                         shouldColorMatch:[depthImage shouldColorMatch]];
        
        if(depth == nil)
            return NO;
        
        self.outputFurthestDepthImage = depth;
        
        id color = [context outputImageProviderFromTextureWithPixelFormat:QCPlugInPixelFormatRGBAf
                                                               pixelsWide:[colorImage imageBounds].size.width
                                                               pixelsHigh:[colorImage imageBounds].size.height
                                                                     name:latestResult->colorResult
                                                                  flipped:[colorImage textureFlipped]
                                                          releaseCallback:_TextureReleaseCallback
                                                           releaseContext:latestResult
                                                               colorSpace:[context colorSpace]
                                                         shouldColorMatch:[colorImage shouldColorMatch]];
        
        if(color == nil)
            return NO;
        
        self.outputFurthestColorImage = color;

        free(latestResult);
       
    }
    return YES;
}


- (MRTResult*) renderToFBO:(CGLContextObj)cgl_ctx colorImage:(id<QCPlugInInputImageSource>)colorImage depthImage:(id<QCPlugInInputImageSource>)depthImage  lastColorImage:(id<QCPlugInInputImageSource>)lastColorImage lastDepthImage:(id<QCPlugInInputImageSource>)lastDepthImage reset:(BOOL)reset

{
    GLsizei width = [colorImage imageBounds].size.width;
    GLsizei height = [colorImage imageBounds].size.height;

    [pluginFBO pushAttributes:cgl_ctx];
    
    glEnable(GL_TEXTURE_RECTANGLE_EXT);
    
    GLuint resultColorTexture = 0;
    glGenTextures(1, &resultColorTexture);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, resultColorTexture);
    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA32F_ARB, width, height, 0, GL_RGBA, GL_FLOAT, NULL);

    GLuint resultDepthTexture = 0;
    glGenTextures(1, &resultDepthTexture);
    glBindTexture(GL_TEXTURE_RECTANGLE_ARB, resultDepthTexture);
    glTexImage2D(GL_TEXTURE_RECTANGLE_ARB, 0, GL_RGBA32F_ARB, width, height, 0, GL_RGBA, GL_FLOAT, NULL);

    [pluginFBO pushFBO:cgl_ctx];

    // We do bind, attach, attach, setup to validate our FBO for MRT - rather than one shot with the old method
    [pluginFBO bindFBO:cgl_ctx];

    [pluginFBO attachFBO:cgl_ctx withTexture:resultColorTexture toAttachment:GL_COLOR_ATTACHMENT0 width:width height:height];
    [pluginFBO attachFBO:cgl_ctx withTexture:resultDepthTexture toAttachment:GL_COLOR_ATTACHMENT1 width:width height:height];

    [pluginFBO setupFBOViewport:cgl_ctx width:width height:height];
    
    GLenum buffers[] = {GL_COLOR_ATTACHMENT0, GL_COLOR_ATTACHMENT1};
    glDrawBuffers(2, buffers);

    glClampColorARB(GL_CLAMP_VERTEX_COLOR_ARB, GL_FALSE);
    glClampColorARB(GL_CLAMP_FRAGMENT_COLOR_ARB, GL_FALSE);
    glClampColorARB(GL_CLAMP_READ_COLOR_ARB, GL_FALSE);

    glClearColor(1.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT);
    
    if(lastColorImage && lastDepthImage)
    {
        glActiveTexture(GL_TEXTURE3);
        glEnable(GL_TEXTURE_RECTANGLE_EXT);
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, [lastDepthImage textureName]);
        glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
        glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
        
        glActiveTexture(GL_TEXTURE2);
        glEnable(GL_TEXTURE_RECTANGLE_EXT);
        glBindTexture(GL_TEXTURE_RECTANGLE_EXT, [lastColorImage textureName]);
        glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
        glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
    
    glActiveTexture(GL_TEXTURE1);
    glEnable(GL_TEXTURE_RECTANGLE_EXT);
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, [depthImage textureName]);
    glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
    glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glActiveTexture(GL_TEXTURE0);
    glEnable(GL_TEXTURE_RECTANGLE_EXT);
    glBindTexture(GL_TEXTURE_RECTANGLE_EXT, [colorImage textureName]);
    glTexEnvf(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
    glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_R, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameterf(GL_TEXTURE_RECTANGLE_EXT, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glDisable(GL_BLEND);
    
    // bind our shader program
    glUseProgramObjectARB([pluginShader programObject]);
    
    // set program vars
    glUniform1iARB([pluginShader getUniformLocation:"color"], 0); // load tex1 sampler to texture unit 0
    glUniform1iARB([pluginShader getUniformLocation:"depth"], 1); // load tex1 sampler to texture unit 0
    glUniform1iARB([pluginShader getUniformLocation:"lastColor"], 2); // load tex1 sampler to texture unit 0
    glUniform1iARB([pluginShader getUniformLocation:"lastDepth"], 3); // load tex1 sampler to texture unit 0
    glUniform1iARB([pluginShader getUniformLocation:"drawColor"], reset);

    // move to VA for rendering
    GLfloat tex_coords[] =
    {
        1.0,1.0,
        0.0,1.0,
        0.0,0.0,
        1.0,0.0
    };
    
    GLfloat verts[] =
    {
        width,height,
        0.0,height,
        0.0,0.0,
        width,0.0
    };

    glClientActiveTexture(GL_TEXTURE3);
    glEnableClientState( GL_TEXTURE_COORD_ARRAY );
    glTexCoordPointer(2, GL_FLOAT, 0, tex_coords );

    glClientActiveTexture(GL_TEXTURE2);
    glEnableClientState( GL_TEXTURE_COORD_ARRAY );
    glTexCoordPointer(2, GL_FLOAT, 0, tex_coords );

    glClientActiveTexture(GL_TEXTURE1);
    glEnableClientState( GL_TEXTURE_COORD_ARRAY );
    glTexCoordPointer(2, GL_FLOAT, 0, tex_coords );
    
    glClientActiveTexture(GL_TEXTURE0);
    glEnableClientState( GL_TEXTURE_COORD_ARRAY );
    glTexCoordPointer(2, GL_FLOAT, 0, tex_coords );
    
    glEnableClientState(GL_VERTEX_ARRAY);
    glVertexPointer(2, GL_FLOAT, 0, verts );
    glDrawArrays( GL_TRIANGLE_FAN, 0, 4 );	// TODO: GL_QUADS or GL_TRIANGLE_FAN?
    
    // disable shader program
    glUseProgramObjectARB(NULL);
    
    GLenum resetbuffers[] = {GL_COLOR_ATTACHMENT0};
    glDrawBuffers(1, resetbuffers);

    glClampColorARB(GL_CLAMP_VERTEX_COLOR_ARB, GL_TRUE);
    glClampColorARB(GL_CLAMP_READ_COLOR_ARB, GL_TRUE);
    glClampColorARB(GL_CLAMP_FRAGMENT_COLOR_ARB, GL_TRUE);
    
    [pluginFBO detachFBO:cgl_ctx];
    [pluginFBO popFBO:cgl_ctx];
    [pluginFBO popAttributes:cgl_ctx];
    
    MRTResult* newResult = malloc(sizeof(MRTResult));
    
    newResult->colorResult = resultColorTexture;
    newResult->depthResult = resultDepthTexture;
    
    return newResult;
}


@end

