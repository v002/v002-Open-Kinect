//
//  v002_Open_Kinect_FurthestDepthImage.m
//  v002 Open Kinect
//
//  Created by vade on 5/30/15.
//
//

#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLMacro.h>

#import "v002FBO.h"
#import "v002Shader.h"

#import "v002_Open_Kinect_FurthestDepthImagePlugIn.h"

#define	kQCPlugIn_Name				@"v002 Open Kinect Furthest Depth"
#define	kQCPlugIn_Description		@"Provides the furthest seen depth and color pixels at the furthest depth providing you with best case, uninterrupted background."


@implementation v002_Open_Kinect_FurthestDepthImagePlugIn

@dynamic inputColorImage;
@dynamic inputDepthImage;

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
    if(self = [super init])
    {
    }
    return self;
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
    return YES;
}

// unload shader
- (void) stopExecution:(id<QCPlugInContext>)context
{
}

- (void) enableExecution:(id<QCPlugInContext>)context
{
}

- (void) disableExecution:(id<QCPlugInContext>)context
{
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
    
    
    return YES;
}

@end
