//
//  BSWDataModelHandler.h
//  WebDriverAgentLib
//
//  Created by Suman Cherukuri on 6/28/19.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>

@interface BSWDataModelHandler : NSObject

+ (BSWDataModelHandler *)sharedInstance;
- (BOOL)loadModel:(NSString *)modelFileName modelFileExtn:(NSString *)modelFileExtn labels:(NSString *)labelFileName labelsFileExtn:(NSString *)labelFileExtn;
- (BOOL)runModelOnFrame:(CVPixelBufferRef)pixelBuffer;
- (NSDictionary *)runModelOnImage:(UIImage *)image;

@end


