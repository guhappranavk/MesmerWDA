/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBCustomCommands.h"

#import <XCTest/XCUIDevice.h>

#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBExceptionHandler.h"
#import "FBPasteboard.h"
#import "FBResponsePayload.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBRunLoopSpinner.h"
#import "FBScreen.h"
#import "FBSession.h"
#import "FBXCodeCompatibility.h"
#import "FBSpringboardApplication.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIDevice+FBHelpers.h"
#import "XCUIElement.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElementQuery.h"
#import "FBFindElementCommands.h"
#import "SocketRocket.h"

@implementation FBCustomCommands

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute POST:@"/timeouts"] respondWithTarget:self action:@selector(handleTimeouts:)],
    [[FBRoute GET:@"/bundleid/:bundleId/appState"].withoutSession respondWithTarget:self action:@selector(handleAppState:)],
    [[FBRoute POST:@"/wda/homescreen"].withoutSession respondWithTarget:self action:@selector(handleHomescreenCommand:)],
    [[FBRoute POST:@"/wda/deactivateApp"] respondWithTarget:self action:@selector(handleDeactivateAppCommand:)],
    [[FBRoute POST:@"/wda/keyboard/dismiss"] respondWithTarget:self action:@selector(handleDismissKeyboardCommand:)],
    [[FBRoute POST:@"/wda/lock"].withoutSession respondWithTarget:self action:@selector(handleLock:)],
    [[FBRoute POST:@"/wda/lock"] respondWithTarget:self action:@selector(handleLock:)],
    [[FBRoute POST:@"/wda/unlock"].withoutSession respondWithTarget:self action:@selector(handleUnlock:)],
    [[FBRoute POST:@"/wda/unlock"] respondWithTarget:self action:@selector(handleUnlock:)],
    [[FBRoute GET:@"/wda/locked"].withoutSession respondWithTarget:self action:@selector(handleIsLocked:)],
    [[FBRoute GET:@"/wda/locked"] respondWithTarget:self action:@selector(handleIsLocked:)],
    [[FBRoute GET:@"/wda/screen"] respondWithTarget:self action:@selector(handleGetScreen:)],
    [[FBRoute GET:@"/wda/activeAppInfo"] respondWithTarget:self action:@selector(handleActiveAppInfo:)],
    [[FBRoute GET:@"/wda/activeAppInfo"].withoutSession respondWithTarget:self action:@selector(handleActiveAppInfo:)],
    [[FBRoute POST:@"/wda/setPasteboard"] respondWithTarget:self action:@selector(handleSetPasteboard:)],
    [[FBRoute POST:@"/wda/getPasteboard"] respondWithTarget:self action:@selector(handleGetPasteboard:)],
    [[FBRoute GET:@"/wda/batteryInfo"] respondWithTarget:self action:@selector(handleGetBatteryInfo:)],
    [[FBRoute POST:@"/wda/pressButton"] respondWithTarget:self action:@selector(handlePressButtonCommand:)],
    [[FBRoute POST:@"/wda/resetLocation"].withoutSession respondWithTarget:self action:@selector(handleResetLocationCommand:)],
    [[FBRoute POST:@"/screenCast"].withoutSession respondWithTarget:self action:@selector(handleScreenCast:)],
    [[FBRoute POST:@"/stopScreenCast"].withoutSession respondWithTarget:self action:@selector(handleStopScreenCast:)]
  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleHomescreenCommand:(FBRouteRequest *)request
{
  NSError *error;
  if (![[XCUIDevice sharedDevice] fb_goToHomescreenWithError:&error]) {
    return FBResponseWithError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleDeactivateAppCommand:(FBRouteRequest *)request
{
  NSNumber *requestedDuration = request.arguments[@"duration"];
  NSTimeInterval duration = (requestedDuration ? requestedDuration.doubleValue : 3.);
  NSError *error;
  if (![request.session.activeApplication fb_deactivateWithDuration:duration error:&error]) {
    return FBResponseWithError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTimeouts:(FBRouteRequest *)request
{
  // This method is intentionally not supported.
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleAppState:(FBRouteRequest *)request
{
  NSString *bundleId = request.parameters[@"bundleId"];
  XCUIApplication *app = [[XCUIApplication alloc] initWithBundleIdentifier:bundleId];
  XCUIApplicationState state = app.state;
  return FBResponseWithStatus(FBCommandStatusNoError, @(state));
}

+ (id<FBResponsePayload>)handleDismissKeyboardCommand:(FBRouteRequest *)request
{
  [request.session.activeApplication dismissKeyboard];
  NSError *error;
  NSString *errorDescription = @"The keyboard cannot be dismissed. Try to dismiss it in the way supported by your application under test.";
  if ([UIDevice.currentDevice userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
    errorDescription = @"The keyboard on iPhone cannot be dismissed because of a known XCTest issue. Try to dismiss it in the way supported by your application under test.";
  }
  BOOL isKeyboardNotPresent =
  [[[[FBRunLoopSpinner new]
     timeout:5]
    timeoutErrorMessage:errorDescription]
   spinUntilTrue:^BOOL{
     XCUIElement *foundKeyboard = [request.session.activeApplication descendantsMatchingType:XCUIElementTypeKeyboard].fb_firstMatch;
     return !(foundKeyboard && foundKeyboard.fb_isVisible);
   }
   error:&error];
  if (!isKeyboardNotPresent) {
    return FBResponseWithError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetScreen:(FBRouteRequest *)request
{
  FBSession *session = request.session;
  CGSize statusBarSize = [FBScreen statusBarSizeForApplication:session.activeApplication];
  return FBResponseWithObject(
  @{
    @"statusBarSize": @{@"width": @(statusBarSize.width),
                        @"height": @(statusBarSize.height),
                        },
    @"scale": @([FBScreen scale]),
    });
}

+ (id<FBResponsePayload>)handleLock:(FBRouteRequest *)request
{
  NSError *error;
  if (![[XCUIDevice sharedDevice] fb_lockScreen:&error]) {
    return FBResponseWithError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleIsLocked:(FBRouteRequest *)request
{
  BOOL isLocked = [XCUIDevice sharedDevice].fb_isScreenLocked;
  return FBResponseWithStatus(FBCommandStatusNoError, isLocked ? @YES : @NO);
}

+ (id<FBResponsePayload>)handleUnlock:(FBRouteRequest *)request
{
  NSError *error;
  if (![[XCUIDevice sharedDevice] fb_unlockScreen:&error]) {
    return FBResponseWithError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleActiveAppInfo:(FBRouteRequest *)request
{
  XCUIApplication *app = FBApplication.fb_activeApplication;
  return FBResponseWithStatus(FBCommandStatusNoError, @{
    @"pid": @(app.processID),
    @"bundleId": app.bundleID,
    @"name": app.identifier
  });
}

+ (id<FBResponsePayload>)handleSetPasteboard:(FBRouteRequest *)request
{
  NSString *contentType = request.arguments[@"contentType"] ?: @"plaintext";
  NSData *content = [[NSData alloc] initWithBase64EncodedString:(NSString *)request.arguments[@"content"]
                                                        options:NSDataBase64DecodingIgnoreUnknownCharacters];
  if (nil == content) {
    return FBResponseWithStatus(FBCommandStatusInvalidArgument, @"Cannot decode the pasteboard content from base64");
  }
  NSError *error;
  if (![FBPasteboard setData:content forType:contentType error:&error]) {
    return FBResponseWithError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetPasteboard:(FBRouteRequest *)request
{
  NSString *contentType = request.arguments[@"contentType"] ?: @"plaintext";
  NSError *error;
  id result = [FBPasteboard dataForType:contentType error:&error];
  if (nil == result) {
    return FBResponseWithError(error);
  }
  return FBResponseWithStatus(FBCommandStatusNoError,
                              [result base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength]);
}

+ (id<FBResponsePayload>)handleGetBatteryInfo:(FBRouteRequest *)request
{
  if (![[UIDevice currentDevice] isBatteryMonitoringEnabled]) {
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
  }
  return FBResponseWithStatus(FBCommandStatusNoError, @{
    @"level": @([UIDevice currentDevice].batteryLevel),
    @"state": @([UIDevice currentDevice].batteryState)
  });
}

+ (id<FBResponsePayload>)handlePressButtonCommand:(FBRouteRequest *)request
{
  NSError *error;
  if (![XCUIDevice.sharedDevice fb_pressButton:(id)request.arguments[@"name"] error:&error]) {
    return FBResponseWithError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleResetLocationCommand:(FBRouteRequest *)request
{
  XCUIApplication *app = [[XCUIApplication alloc] initWithBundleIdentifier: @"com.apple.Preferences"];
  [app activate];
  
  if ([self tap:@"Reset Location & Privacy" app:app]) {
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
      [self tapButton:@"Reset" element:@"Reset Warnings" app:app];
    }
    else {
      [self tap:@"Reset Warnings" app:app];
    }
  }
  else {
    [self tap:@"General" app:app];
    [self tap:@"Reset" app:app];
    [self tap:@"Reset Location & Privacy" app:app];
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ) {
      [self tapButton:@"Reset" element:@"Reset Warnings" app:app];
    }
    else {
      [self tap:@"Reset Warnings" app:app];
    }
  }
  return FBResponseWithOK();
}

+ (BOOL)tap:(NSString *)name app:(XCUIApplication *)app {
  NSArray *elements = [FBFindElementCommands elementsUsing:@"id" withValue:name under:app shouldReturnAfterFirstMatch:NO];
  if (elements.count > 0) {
    XCUIElement *element = elements[0];
    return [element fb_tapWithError:nil];
  }
  return NO;
}

+ (BOOL)tapButton:(NSString *)name element:(NSString *)element app:(XCUIApplication *)app {
  NSArray *elements = [FBFindElementCommands elementsUsing:@"id" withValue:element under:app shouldReturnAfterFirstMatch:NO];
  if (elements.count > 0) {
    NSArray *buttons = [elements[0] buttons].allElementsBoundByIndex;
    for (XCUIElement *button in buttons) {
      NSString *label = button.label;
      if ([label caseInsensitiveCompare:name] == NSOrderedSame) {
        [button tap];
        return YES;
      }
    }
  }
  return NO;
}

static NSTimer *kTimer = nil;
static SRWebSocket *kSRWebSocket;
static NSData *kLastImageData;

+ (id<FBResponsePayload>)handleScreenCast:(FBRouteRequest *)request
{
  NSInteger fps = [request.arguments[@"fps"] integerValue];
  NSString *url = request.arguments[@"url"];
  
  if (fps <= 0) {
    fps = 10;
  }
  if (url == nil) {
    return FBResponseWithObject(@"Missing URL");
  }
  
  if (kTimer != nil) {
    [kTimer invalidate];
  }
  if (kSRWebSocket != nil) {
    [kSRWebSocket close];
  }
  
  NSURL *nsURL = [NSURL URLWithString:url];
  kSRWebSocket = [[SRWebSocket alloc] initWithURL:nsURL securityPolicy:[SRSecurityPolicy defaultPolicy]];
  [kSRWebSocket open];
  kTimer = [NSTimer scheduledTimerWithTimeInterval:1/fps target:self selector:@selector(performScreenCast:) userInfo:nil repeats:YES];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleStopScreenCast:(FBRouteRequest *)request
{
  if (kTimer != nil) {
    [kTimer invalidate];
    kTimer = nil;
  }
  if (kSRWebSocket != nil) {
    [kSRWebSocket close];
  }
  kLastImageData = nil;
  return FBResponseWithOK();
}

+ (void)performScreenCast:(NSTimer*)timer {
  //  dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
  NSError *error = nil;
  NSData *screenshotData = [[XCUIDevice sharedDevice] fb_screenshotHighWithError:&error quality:0.0 type:@"jpeg"];
  if (screenshotData != nil && error == nil) {
    if ([kLastImageData isEqualToData:screenshotData]) {
      return;
    }
    kLastImageData = screenshotData;
    [kSRWebSocket sendData:screenshotData error:&error];
    if (error) {
      NSLog(@"Error sending screenshot: %@", error);
    }
    else {
      //log the time it took to transport
    }
  }
  else {
    NSLog(@"Error taking screenshot: %@", error == nil ? @"Unknown error" : error);
  }
  //  });
}

@end
