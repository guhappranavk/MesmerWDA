/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBConfiguration.h"

#import <UIKit/UIKit.h>

#include "TargetConditionals.h"
#import "FBXCodeCompatibility.h"
#import "XCTestPrivateSymbols.h"
#import "XCElementSnapshot.h"

static NSUInteger const DefaultStartingPort = 8100;
static NSUInteger const DefaultMjpegServerPort = 9110;
static NSUInteger const DefaultPortRange = 100;

static BOOL FBShouldUseTestManagerForVisibilityDetection = NO;
static BOOL FBShouldUseSingletonTestManager = YES;
static BOOL FBShouldUseCompactResponses = YES;
static BOOL FBShouldWaitForQuiescence = NO;
static NSString *FBElementResponseAttributes = @"type,label";
static NSUInteger FBMaxTypingFrequency = 60;
static BOOL FBShouldAnonymizeFullImagePaths = NO;

@implementation FBConfiguration

#pragma mark Public

+ (void)disableRemoteQueryEvaluation
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"XCTDisableRemoteQueryEvaluation"];
}

+ (void)disableAttributeKeyPathAnalysis
{
  [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"XCTDisableAttributeKeyPathAnalysis"];
}

+ (NSRange)bindingPortRange
{
  // 'WebDriverAgent --port 8080' can be passed via the arguments to the process
  if (self.bindingPortRangeFromArguments.location != NSNotFound) {
    return self.bindingPortRangeFromArguments;
  }

  // Existence of USE_PORT in the environment implies the port range is managed by the launching process.
  if (NSProcessInfo.processInfo.environment[@"USE_PORT"] &&
      [NSProcessInfo.processInfo.environment[@"USE_PORT"] length] > 0) {
    return NSMakeRange([NSProcessInfo.processInfo.environment[@"USE_PORT"] integerValue] , 1);
  }

  return NSMakeRange(DefaultStartingPort, DefaultPortRange);
}

+ (NSInteger)mjpegServerPort
{
  if (NSProcessInfo.processInfo.environment[@"MJPEG_SERVER_PORT"] &&
      [NSProcessInfo.processInfo.environment[@"MJPEG_SERVER_PORT"] length] > 0) {
    return [NSProcessInfo.processInfo.environment[@"MJPEG_SERVER_PORT"] integerValue];
  }

  return DefaultMjpegServerPort;
}

+ (BOOL)useMesmair {
  NSString *useMesmair = NSProcessInfo.processInfo.environment[@"USE_MESMAIR"];
  if (useMesmair == nil) {
    return NO;
  }
  return [useMesmair boolValue];
}

+ (BOOL)verboseLoggingEnabled
{
  return [NSProcessInfo.processInfo.environment[@"VERBOSE_LOGGING"] boolValue];
}

+ (void)setShouldUseTestManagerForVisibilityDetection:(BOOL)value
{
  FBShouldUseTestManagerForVisibilityDetection = value;
}

+ (BOOL)shouldUseTestManagerForVisibilityDetection
{
  return FBShouldUseTestManagerForVisibilityDetection;
}

+ (void)setShouldUseCompactResponses:(BOOL)value
{
  FBShouldUseCompactResponses = value;
}

+ (BOOL)shouldUseCompactResponses
{
  return FBShouldUseCompactResponses;
}

+ (void)setElementResponseAttributes:(NSString *)value
{
  FBElementResponseAttributes = value;
}

+ (NSString *)elementResponseAttributes
{
  return FBElementResponseAttributes;
}

+ (void)setMaxTypingFrequency:(NSUInteger)value
{
  FBMaxTypingFrequency = value;
}

+ (NSUInteger)maxTypingFrequency
{
  return FBMaxTypingFrequency;
}

+ (void)setShouldUseSingletonTestManager:(BOOL)value
{
  FBShouldUseSingletonTestManager = value;
}

+ (BOOL)shouldUseSingletonTestManager
{
  return FBShouldUseSingletonTestManager;
}

+ (BOOL)shouldLoadSnapshotWithAttributes
{
  return [XCElementSnapshot fb_attributesForElementSnapshotKeyPathsSelector] != nil;
}

+ (BOOL)shouldWaitForQuiescence
{
  return FBShouldWaitForQuiescence;
}

+ (void)setShouldWaitForQuiescence:(BOOL)value
{
  FBShouldWaitForQuiescence = value;
}

+ (BOOL)shouldAnonymizeFullImagePaths
{
  return FBShouldAnonymizeFullImagePaths;
}

+ (void)setShouldAnonymizeFullImagePaths:(BOOL)value
{
  FBShouldAnonymizeFullImagePaths = value;
}

#pragma mark Private

+ (NSRange)bindingPortRangeFromArguments
{
  NSArray *arguments = NSProcessInfo.processInfo.arguments;
  NSUInteger index = [arguments indexOfObject:@"--port"];
  if (index == NSNotFound || index == arguments.count - 1) {
    return NSMakeRange(NSNotFound, 0);
  }
  NSString *portNumberString = arguments[index + 1];
  NSUInteger port = (NSUInteger)[portNumberString integerValue];
  if (port == 0) {
    return NSMakeRange(NSNotFound, 0);
  }
  return NSMakeRange(port, 1);
}

@end
