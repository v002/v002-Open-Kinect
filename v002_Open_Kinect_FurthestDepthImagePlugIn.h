//
//  v002_Open_Kinect_FurthestDepthImage.h
//  v002 Open Kinect
//
//  Created by vade on 5/30/15.
//
//

#import <Quartz/Quartz.h>
#import <OpenGL/OpenGL.h>
#import "v002MasterPluginInterface.h"

@interface v002_Open_Kinect_FurthestDepthImagePlugIn : v002MasterPluginInterface
{
//    GLuint lastColorTexture;
//    GLuint lastDepthTexture;
}

@property (assign) id <QCPlugInInputImageSource> inputColorImage;
@property (assign) id <QCPlugInInputImageSource> inputDepthImage;
@property (assign) id <QCPlugInInputImageSource> inputLastColorImage;
@property (assign) id <QCPlugInInputImageSource> inputLastDepthImage;
@property (assign) BOOL inputReset;

@property (assign) id <QCPlugInOutputImageProvider> outputFurthestColorImage;
@property (assign) id <QCPlugInOutputImageProvider> outputFurthestDepthImage;

@end
