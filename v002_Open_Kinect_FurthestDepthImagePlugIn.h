//
//  v002_Open_Kinect_FurthestDepthImage.h
//  v002 Open Kinect
//
//  Created by vade on 5/30/15.
//
//

#import <Quartz/Quartz.h>

@interface v002_Open_Kinect_FurthestDepthImagePlugIn : QCPlugIn
{
    
}

@property (assign) id <QCPlugInInputImageSource> inputColorImage;
@property (assign) id <QCPlugInInputImageSource> inputDepthImage;

@property (assign) id <QCPlugInOutputImageProvider> outputFurthestColorImage;
@property (assign) id <QCPlugInOutputImageProvider> outputFurthestDepthImage;

@end
