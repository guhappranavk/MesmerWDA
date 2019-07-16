/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBScreenshotCommands.h"

#import "XCUIDevice+FBHelpers.h"
#import "BSWDataModelHandler.h"

@implementation FBScreenshotCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute GET:@"/screenshot"].withoutSession respondWithTarget:self action:@selector(handleGetScreenshot:)],
    [[FBRoute GET:@"/screenshotHigh"].withoutSession respondWithTarget:self action:@selector(handleGetScreenshotHigh:)],
    [[FBRoute GET:@"/screenClassification"].withoutSession respondWithTarget:self action:@selector(handleGetScreenshotClassification:)],
    [[FBRoute GET:@"/screenshot"] respondWithTarget:self action:@selector(handleGetScreenshot:)],
  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleGetScreenshot:(FBRouteRequest *)request
{
  NSError *error;
  NSData *screenshotData = [[XCUIDevice sharedDevice] fb_screenshotWithError:&error];
  if (nil == screenshotData) {
    return FBResponseWithError(error);
  }
  NSString *screenshot = [screenshotData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
  return FBResponseWithObject(screenshot);
}

+ (id<FBResponsePayload>)handleGetScreenshotHigh:(FBRouteRequest *)request
{
  NSError *error;
  NSData *screenshotData = [[XCUIDevice sharedDevice] fb_screenshotHighWithError:&error];
  if (nil == screenshotData) {
    return FBResponseWithError(error);
  }
  NSString *screenshot = [screenshotData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
  return FBResponseWithObject(screenshot);
}

+ (id<FBResponsePayload>)handleGetScreenshotClassification:(FBRouteRequest *)request
{  
  NSError *error;
  UIImage *image  = [[XCUIDevice sharedDevice] fb_screenshotImageWithError:&error];
  if (nil == image) {
    return FBResponseWithError(error);
  }
  NSDictionary *values = [[BSWDataModelHandler sharedInstance] runModelOnImage:image];
  
  return FBResponseWithObject(values);
}

@end
