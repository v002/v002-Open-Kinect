//
//  v002_Open_Kinect_Background_ClipPlugIn.m
//  v002 Open Kinect
//
//  Created by vade on 6/4/15.
//
//

#import "v002_Open_Kinect_Background_ClipPlugIn.h"
#import <OpenGL/CGLMacro.h>


#define	kQCPlugIn_Name				@"v002 Open Kinect Depth Clip"
#define	kQCPlugIn_Description		@"Clips depth image giving you a near and far range"

#pragma mark -
#pragma mark Static Functions

static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
    glDeleteTextures(1, &name);
}

@implementation v002_Open_Kinect_Background_ClipPlugIn

@dynamic inputImage;
@dynamic inputFarClip;
@dynamic inputNearClip;
@dynamic outputImage;

+ (NSDictionary*) attributes
{
    return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey,
            [kQCPlugIn_Description stringByAppendingString:kv002DescriptionAddOnText], QCPlugInAttributeDescriptionKey,
            kQCPlugIn_Category, @"categories", nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
    if([key isEqualToString:@"inputImage"])
    {
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
    }
    
    if([key isEqualToString:@"inputFarClip"])
    {
        return @{QCPortAttributeNameKey :@"Far Clip",
                 QCPortAttributeMinimumValueKey : @(-1.5),
                 QCPortAttributeDefaultValueKey : @(-0.5),
                 QCPortAttributeMaximumValueKey : @0.0,
                 };
    }
   
    if([key isEqualToString:@"inputNearClip"])
    {
        return @{QCPortAttributeNameKey :@"Near Clip",
                 QCPortAttributeMinimumValueKey : @(0.0),
                 QCPortAttributeDefaultValueKey : @(0.5),
                 QCPortAttributeMaximumValueKey : @1.0,
                 };
    }

    if([key isEqualToString:@"outputImage"])
    {
        return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
    }
    return nil;
}

+ (NSArray*) sortedPropertyPortKeys
{
    return [NSArray arrayWithObjects:@"inputImage", @"inputNearClip", @"inputFarClip", @"inputAmount", nil];
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
    if(self = [super init])
    {
        self.pluginShaderName = @"v002.OpenKinectClipDepth";
        
        __unsafe_unretained typeof(self) weakSelf = self;
        
        self.shaderUniformBlock = ^void(CGLContextObj cgl_ctx)
        {
            if(weakSelf)
            {
                __strong typeof(self) strongSelf = weakSelf;
                
                glUniform1iARB([strongSelf->pluginShader getUniformLocation:"depth"], 0);
                // z negative is further away
                glUniform1fARB([strongSelf->pluginShader getUniformLocation:"minDepth"], strongSelf.inputFarClip);
                // z positive is closer
                glUniform1fARB([strongSelf->pluginShader getUniformLocation:"maxDepth"], strongSelf.inputNearClip);
            }
        };
    }
    
    return self;
}

@end

@implementation v002_Open_Kinect_Background_ClipPlugIn (Execution)

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
    CGLContextObj cgl_ctx = [context CGLContextObj];
    
    id<QCPlugInInputImageSource>   image = self.inputImage;
    
    CGColorSpaceRef cspace = ([image shouldColorMatch]) ? [context colorSpace] : [image imageColorSpace];
    
    if(image && [image lockTextureRepresentationWithColorSpace:cspace forBounds:[image imageBounds]])
    {
        [image bindTextureRepresentationToCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0 normalizeCoordinates:YES];
        
        BOOL useFloat = [self boundImageIsFloatingPoint:image inContext:cgl_ctx];
        
        // Render
        GLuint finalOutput = [self singleImageRenderWithContext:cgl_ctx image:image useFloat:useFloat];
        
        [image unbindTextureRepresentationFromCGLContext:[context CGLContextObj] textureUnit:GL_TEXTURE0];
        [image unlockTextureRepresentation];
        
        id provider = nil;
        
        if(finalOutput != 0)
        {
            provider = [context outputImageProviderFromTextureWithPixelFormat:[self pixelFormatIfUsingFloat:useFloat]
                                                                   pixelsWide:[image imageBounds].size.width
                                                                   pixelsHigh:[image imageBounds].size.height
                                                                         name:finalOutput
                                                                      flipped:NO
                                                              releaseCallback:_TextureReleaseCallback
                                                               releaseContext:NULL
                                                                   colorSpace:[context colorSpace]
                                                             shouldColorMatch:[image shouldColorMatch]];
            
            self.outputImage = provider;
        }
    }
    else
        self.outputImage = nil;
    
    return YES;
}

@end