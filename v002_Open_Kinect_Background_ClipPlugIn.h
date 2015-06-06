//
//  v002_Open_Kinect_Background_ClipPlugIn.h
//  v002 Open Kinect
//
//  Created by vade on 6/4/15.
//
//

#import "v002MasterPluginInterface.h"
#import "v002MasterPluginInterface.h"

@interface v002_Open_Kinect_Background_ClipPlugIn : v002MasterPluginInterface
{
}
@property (assign) id<QCPlugInInputImageSource> inputImage;
@property (assign) double inputFarClip;
@property (assign) double inputNearClip;
@property (assign) id<QCPlugInOutputImageProvider> outputImage;

@end
