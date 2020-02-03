/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBCustomCommands.h"

#import <sys/utsname.h>

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
#import "FBElementCommands.h"
#import "FBMathUtils.h"
#import "FBElementUtils.h"

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
    [[FBRoute POST:@"/stopScreenCast"].withoutSession respondWithTarget:self action:@selector(handleStopScreenCast:)],
    [[FBRoute POST:@"/screenMirror"].withoutSession respondWithTarget:self action:@selector(handleScreenMirror:)],
    [[FBRoute POST:@"/stopScreenMirror"].withoutSession respondWithTarget:self action:@selector(handleStopScreenMirror:)],
    [[FBRoute POST:@"/restartScreenMirror"].withoutSession respondWithTarget:self action:@selector(handleRestartScreenMirror:)],
    [[FBRoute POST:@"/isScreenMirroring"].withoutSession respondWithTarget:self action:@selector(handleIsScreenMirroring:)],
    [[FBRoute POST:@"/terminate"].withoutSession respondWithTarget:self action:@selector(handleTerminate:)],
    [[FBRoute POST:@"/wifi"].withoutSession respondWithTarget:self action:@selector(handleWifi:)],
    [[FBRoute POST:@"/bluetooth"].withoutSession respondWithTarget:self action:@selector(handleBluetooth:)],
    [[FBRoute POST:@"/airplane"].withoutSession respondWithTarget:self action:@selector(handleAirplane:)],
    [[FBRoute POST:@"/cellular"].withoutSession respondWithTarget:self action:@selector(handleCellular:)],
    [[FBRoute POST:@"/orientationLock"].withoutSession respondWithTarget:self action:@selector(handleOrientationLock:)],
    [[FBRoute GET:@"/networkConditions"].withoutSession respondWithTarget:self action:@selector(handleNetworkConditions:)],
    [[FBRoute POST:@"/networkCondition"].withoutSession respondWithTarget:self action:@selector(handleNetworkCondition:)],
//    [[FBRoute GET:@"/url/:url/networkThroughput"].withoutSession respondWithTarget:self action:@selector(handleNetworkThroughput:)],
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
  NSData *screenshotData = [[XCUIDevice sharedDevice] fb_screenshotHighWithError:&error width:0.0 height:0.0];// quality:0.0 type:@"jpeg"];
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

+ (BOOL)isSwipeFromTopRight {
  struct utsname systemInfo;
  uname(&systemInfo);

  NSString *deviceName =  [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
  if ([deviceName caseInsensitiveCompare:@"iPhone9,1"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone9,2"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone9,3"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone9,4"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone10,1"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone10,2"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone10,3"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone10,4"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone10,5"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone10,6"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone11,2"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone11,4"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone11,6"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone11,8"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone12,1"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone12,3"] == NSOrderedSame ||
      [deviceName caseInsensitiveCompare:@"iPhone12,5"] == NSOrderedSame
      ) {
    return YES;
  }
  
  // simulators
  NSString *systemVersion = [[[UIDevice currentDevice] systemVersion] substringToIndex:2];
  if ([deviceName caseInsensitiveCompare:@"x86_64"] == NSOrderedSame &&
      [systemVersion integerValue] >= 12) {
    return YES;
  }
  
  // iPads
  if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
    if ([systemVersion integerValue] >= 12) {
      return YES;
    }
  }
  return NO;
}

+ (id<FBResponsePayload>)handleScreenMirror:(FBRouteRequest *)request
{
  NSString *airplayServer = request.arguments[@"airplay"];
  BOOL wait = [request.arguments[@"wait"] boolValue];
  BOOL restart = [request.arguments[@"restart"] boolValue];
  
  if (airplayServer == nil) {
    airplayServer = @"MesmAir";
  }
  
  XCUIApplication *app = [FBApplication fb_activeApplication];//  [[XCUIApplication alloc] initWithBundleIdentifier: @"com.apple.springboard"];
  NSArray *alerts = [[app alerts] allElementsBoundByIndex];
  if (alerts.count > 0) {
      return FBResponseWithStatus(FBCommandStatusUnexpectedAlertPresent, [FBElementUtils alertSource:alerts[0] withInfo:@"A modal dialog was open, blocking this operation"]);
  }
  CGRect frame = app.frame;
  CGSize screenSize = FBAdjustDimensionsForApplication(frame.size, request.session.activeApplication.interfaceOrientation);
  
//  FBApplication *application = [FBApplication fb_activeApplication];
//  CGRect frame = application.wdFrame;
//  CGRect frame = [[UIScreen mainScreen] bounds];
  UIInterfaceOrientation orientation = app.interfaceOrientation;
  
  if ([self isSwipeFromTopRight]) {
    if (UIInterfaceOrientationIsLandscape(orientation)) {
      CGFloat width = MAX(frame.size.width, frame.size.height);
      CGFloat height = MIN(frame.size.width, frame.size.height);
      [FBElementCommands drag:CGPointMake(width, 0) endPoint:CGPointMake(width, height/2) duration:.0001];
    }
    else {
      [FBElementCommands drag2:CGPointMake(frame.size.width, 0) endPoint:CGPointMake(frame.size.width/2, frame.size.height/4) duration:0.001 velocity:1500];
    }
  }
  else {
    //before iPhone X
    if (orientation == UIInterfaceOrientationPortrait) {
      [FBElementCommands drag2:CGPointMake(frame.size.width/2, frame.size.height) endPoint:CGPointMake(frame.size.width/2, frame.size.height/4) duration:0.001 velocity:1500];
    }
    else {
      [FBElementCommands drag2:CGPointMake(0, screenSize.height/2) endPoint:CGPointMake(frame.size.width/2, frame.size.height) duration:0.001 velocity:1500];
    }
  }
  
  FBResponseJSONPayload *response = nil;
  
  if (restart) {
    //stop if it is mirroring now
    FBResponseJSONPayload *response = (FBResponseJSONPayload* _Nullable)[FBElementCommands findAndTap:[FBApplication fb_activeApplication] type:@"Button" query:@"label" queryValue:airplayServer useButtonTap:NO];
    if ([[[response dictionary] objectForKey:@"status"] integerValue] != 0) {
      //try static text
      response = [FBElementCommands findAndTap:[FBApplication fb_activeApplication] type:@"StaticText" query:@"label" queryValue:airplayServer useButtonTap:NO];
    }
    [NSThread sleepForTimeInterval:0.2];
    response = [FBElementCommands findAndTap:[FBApplication fb_activeApplication] type:@"Button" query:@"label" queryValue:@"Stop Mirroring" useButtonTap:NO];
    if ([[[response dictionary] objectForKey:@"status"] integerValue] != 0) {
      //try static text
      [NSThread sleepForTimeInterval:0.2];
      response = [FBElementCommands findAndTap:[FBApplication fb_activeApplication] type:@"StaticText" query:@"label" queryValue:@"Stop Mirroring" useButtonTap:NO];
    }
  }
  
  int i = 3;
  while (i >= 0) {
    response = (FBResponseJSONPayload* _Nullable)[FBElementCommands findAndTap:[FBApplication fb_activeApplication] type:@"Button" query:@"label" queryValue:@"Screen Mirroring" useButtonTap:NO];
    if ([[[response dictionary] objectForKey:@"status"] integerValue] == 0) {
      break;
    }
    if (wait == NO) {
      i--;
    }
    [NSThread sleepForTimeInterval:(1.0f)];
  }
  
  i = 3;
  while (i >= 0) {
    response = [FBElementCommands findAndTap:[FBApplication fb_activeApplication] type:@"StaticText" query:@"label" queryValue:airplayServer useButtonTap:NO];
    if ([[[response dictionary] objectForKey:@"status"] integerValue] != 0) {
      //try button
      [NSThread sleepForTimeInterval:0.2];
      response = [FBElementCommands findAndTap:[FBApplication fb_activeApplication] type:@"Button" query:@"label" queryValue:airplayServer useButtonTap:NO];
    }
    if ([[[response dictionary] objectForKey:@"status"] integerValue] == 0) {
      break;
    }
    if (wait == NO) {
      i--;
    }
    [NSThread sleepForTimeInterval:(1.0f)];
  }
  [NSThread sleepForTimeInterval:0.2];
  [FBElementCommands tapCoordinate:[FBApplication fb_activeApplication] tapPoint:CGPointMake(1, 1)];
  [NSThread sleepForTimeInterval:0.2];
  [FBElementCommands tapCoordinate:[FBApplication fb_activeApplication] tapPoint:CGPointMake(1, 1)];
  
  return response;
}

+ (id<FBResponsePayload>)handleStopScreenMirror:(FBRouteRequest *)request
{
  NSString *airplayServer = request.arguments[@"airplay"];
  if (airplayServer == nil) {
    airplayServer = @"MesmAir";
  }
  
  XCUIApplication *app = [FBApplication fb_activeApplication];//  [[XCUIApplication alloc] initWithBundleIdentifier: @"com.apple.springboard"];
  
  NSArray *alerts = [[app alerts] allElementsBoundByIndex];
  if (alerts.count > 0) {
      return FBResponseWithStatus(FBCommandStatusUnexpectedAlertPresent, [FBElementUtils alertSource:alerts[0] withInfo:@"A modal dialog was open, blocking this operation"]);
  }
  
  CGRect frame = app.frame;
  CGSize screenSize = FBAdjustDimensionsForApplication(frame.size, request.session.activeApplication.interfaceOrientation);
  
  UIInterfaceOrientation orientation = app.interfaceOrientation;
  if ([self isSwipeFromTopRight]) {
    if (UIInterfaceOrientationIsLandscape(orientation)) {
      CGFloat width = MAX(frame.size.width, frame.size.height);
      CGFloat height = MIN(frame.size.width, frame.size.height);
      [FBElementCommands drag:CGPointMake(width, 0) endPoint:CGPointMake(width, height/2) duration:.0001];
    }
    else {
      [FBElementCommands drag2:CGPointMake(frame.size.width, 0) endPoint:CGPointMake(frame.size.width/2, frame.size.height/4) duration:0.001 velocity:1500];
    }
  }
  else {
    //before iPhone X
    if (orientation == UIInterfaceOrientationPortrait) {
      [FBElementCommands drag2:CGPointMake(frame.size.width/2, frame.size.height) endPoint:CGPointMake(frame.size.width/2, frame.size.height/4) duration:0.001 velocity:1500];
    }
    else {
      [FBElementCommands drag2:CGPointMake(0, screenSize.height/2) endPoint:CGPointMake(frame.size.width/2, frame.size.height) duration:0.001 velocity:1500];
    }
  }
  FBResponseJSONPayload *response = (FBResponseJSONPayload* _Nullable)[FBElementCommands findAndTap:[FBApplication fb_activeApplication] type:@"Button" query:@"label" queryValue:airplayServer useButtonTap:NO];
  if ([[[response dictionary] objectForKey:@"status"] integerValue] != 0) {
    //try static text
    response = [FBElementCommands findAndTap:[FBApplication fb_activeApplication] type:@"StaticText" query:@"label" queryValue:airplayServer useButtonTap:NO];
  }
  [NSThread sleepForTimeInterval:0.2];
  response = [FBElementCommands findAndTap:[FBApplication fb_activeApplication] type:@"Button" query:@"label" queryValue:@"Stop Mirroring" useButtonTap:NO];
  if ([[[response dictionary] objectForKey:@"status"] integerValue] != 0) {
    //try static text
    [NSThread sleepForTimeInterval:0.2];
    response = [FBElementCommands findAndTap:[FBApplication fb_activeApplication] type:@"StaticText" query:@"label" queryValue:@"Stop Mirroring" useButtonTap:NO];
  }
  [NSThread sleepForTimeInterval:0.5];
  [FBElementCommands tapCoordinate:[FBApplication fb_activeApplication] tapPoint:CGPointMake(24, 24)];
  
  return response;
}

+ (id<FBResponsePayload>)handleRestartScreenMirror:(FBRouteRequest *)request
{
  [self handleStopScreenMirror:request];
  return [self handleScreenMirror:request];
}

+ (id<FBResponsePayload>)handleIsScreenMirroring:(FBRouteRequest *)request
{
  NSString *airplayServer = request.arguments[@"airplay"];
  if (airplayServer == nil) {
    airplayServer = @"MesmAir";
  }
  
  XCUIApplication *app = [FBApplication fb_activeApplication];//  [[XCUIApplication alloc] initWithBundleIdentifier: @"com.apple.springboard"];
  NSArray *alerts = [[app alerts] allElementsBoundByIndex];
  if (alerts.count > 0) {
      return FBResponseWithStatus(FBCommandStatusUnexpectedAlertPresent, [FBElementUtils alertSource:alerts[0] withInfo:@"A modal dialog was open, blocking this operation"]);
  }
  
  CGRect frame = app.frame;
  CGSize screenSize = FBAdjustDimensionsForApplication(frame.size, request.session.activeApplication.interfaceOrientation);
  
  UIInterfaceOrientation orientation = app.interfaceOrientation;
  if ([self isSwipeFromTopRight]) {
    if (UIInterfaceOrientationIsLandscape(orientation)) {
      CGFloat width = MAX(frame.size.width, frame.size.height);
      CGFloat height = MIN(frame.size.width, frame.size.height);
      [FBElementCommands drag:CGPointMake(width, 0) endPoint:CGPointMake(width, height/2) duration:.0001];
    }
    else {
      [FBElementCommands drag2:CGPointMake(frame.size.width, 0) endPoint:CGPointMake(frame.size.width/2, frame.size.height/4) duration:0.001 velocity:1500];
    }
  }
  else {
    //before iPhone X
    if (orientation == UIInterfaceOrientationPortrait) {
      [FBElementCommands drag2:CGPointMake(frame.size.width/2, frame.size.height) endPoint:CGPointMake(frame.size.width/2, frame.size.height/4) duration:0.001 velocity:1500];
    }
    else {
      [FBElementCommands drag2:CGPointMake(0, screenSize.height/2) endPoint:CGPointMake(frame.size.width/2, frame.size.height) duration:0.001 velocity:1500];
    }
  }
  BOOL mirroring = [FBElementCommands find:[FBApplication fb_activeApplication] type:@"Button" query:@"label" queryValue:airplayServer] != nil;
  if (!mirroring) {
    //try static text
    mirroring = [FBElementCommands find:[FBApplication fb_activeApplication] type:@"StaticText" query:@"label" queryValue:airplayServer] != nil;
  }
  [FBElementCommands tapCoordinate:[FBApplication fb_activeApplication] tapPoint:CGPointMake(24, 24)];
  return FBResponseWithObject(@{@"mirroring" : @(mirroring)});
}

+ (id<FBResponsePayload>)handleTerminate:(FBRouteRequest *)request
{
  NSString *bundleId = request.arguments[@"bundleId"];
  if (bundleId == nil) {
    return FBResponseWithErrorFormat(@"Missing bundle id in terminate command");
  }
  XCUIApplication *app = [[XCUIApplication alloc] initWithBundleIdentifier: bundleId];
  if (app == nil || [app exists] == NO) {
      return FBResponseWithErrorFormat(@"%@ Not found", bundleId);
  }
  [app terminate];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleWifi:(FBRouteRequest *)request
{
  BOOL on = [request.arguments[@"set"] boolValue];
  return [self setPreference:@"Wi-Fi" innerPreference:nil on:on];
}

+ (id<FBResponsePayload>)handleBluetooth:(FBRouteRequest *)request
{
  BOOL on = [request.arguments[@"set"] boolValue];
  return [self setPreference:@"Bluetooth" innerPreference:nil on:on];
}

+ (id<FBResponsePayload>)handleAirplane:(FBRouteRequest *)request
{
  BOOL on = [request.arguments[@"set"] boolValue];
  return [self setPreference:nil innerPreference:@"Airplane Mode" on:on];
}

+ (id<FBResponsePayload>)handleCellular:(FBRouteRequest *)request
{
  BOOL on = [request.arguments[@"set"] boolValue];
  return [self setPreference:@"Cellular" innerPreference:@"Cellular Data" on:on];
}

+ (id<FBResponsePayload>)setPreference:(NSString *)preference innerPreference:(NSString *)innerPreference on:(BOOL)on
{
  if (innerPreference == nil) {
    innerPreference = preference;
  }
  XCUIApplication *app = [FBApplication fb_activeApplication];
  
  NSArray *alerts = [[app alerts] allElementsBoundByIndex];
  if (alerts.count > 0) {
    return FBResponseWithStatus(FBCommandStatusUnexpectedAlertPresent, [FBElementUtils alertSource:alerts[0] withInfo:@"A modal dialog was open, blocking this operation"]);
  }
  
  XCUIApplication *preferencesApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.Preferences"];
  [preferencesApp launch];
  
  if (preference != nil) {
    XCUIElement *cellElem = [FBElementCommands find:preferencesApp type:@"Cell" query:@"label" queryValue:preference];
    if (cellElem == nil || [cellElem isEnabled] == NO) {
      [self terminatePreferencesApp:preferencesApp andActivate:app];
      return FBResponseWithStatus(FBCommandStatusUnhandled, [NSString stringWithFormat:@"Couldn't set preference: %@", preference]);
    }
  }
  
  XCUIElement *switchElem = nil;
  while (switchElem == nil) {
    [NSThread sleepForTimeInterval:0.5];
    switchElem = [FBElementCommands find:preferencesApp type:@"Switch" query:@"label" queryValue:innerPreference];
  }
  
  if (switchElem) {
    BOOL isOn = [switchElem.value integerValue] == 1;
    if (isOn != on) {
      [switchElem tap];
    }
  }
 
  [self terminatePreferencesApp:preferencesApp andActivate:app];

  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleOrientationLock:(FBRouteRequest *)request
{
  BOOL on = [request.arguments[@"set"] boolValue];
  XCUIApplication *app = [FBApplication fb_activeApplication];
  NSArray *alerts = [[app alerts] allElementsBoundByIndex];
  if (alerts.count > 0) {
    return FBResponseWithStatus(FBCommandStatusUnexpectedAlertPresent, [FBElementUtils alertSource:alerts[0] withInfo:@"A modal dialog was open, blocking this operation"]);
  }
  
  CGRect frame = app.frame;
  CGSize screenSize = FBAdjustDimensionsForApplication(frame.size, request.session.activeApplication.interfaceOrientation);
  
  if ([self isSwipeFromTopRight]) {
    [FBElementCommands drag2:CGPointMake(frame.size.width, 0) endPoint:CGPointMake(frame.size.width/2, frame.size.height/4) duration:0.001 velocity:1500];
  }
  else {
    //before iPhone X
    UIInterfaceOrientation orientation = app.interfaceOrientation;
    if (orientation == UIInterfaceOrientationPortrait) {
      [FBElementCommands drag2:CGPointMake(frame.size.width/2, frame.size.height) endPoint:CGPointMake(frame.size.width/2, frame.size.height/4) duration:0.001 velocity:1500];
    }
    else {
      [FBElementCommands drag2:CGPointMake(0, screenSize.height/2) endPoint:CGPointMake(frame.size.width/2, frame.size.height) duration:0.001 velocity:1500];
    }
  }
  
  XCUIElement *ol = [FBElementCommands find:[FBApplication fb_activeApplication] type:@"Switch" query:@"label" queryValue:@"Lock Rotation"];
  if (ol) {
    BOOL isOn = [ol.value integerValue] == 1;
    if (isOn != on) {
      [ol tap];
    }
  }
  [NSThread sleepForTimeInterval:0.2];
  [FBElementCommands tapCoordinate:[FBApplication fb_activeApplication] tapPoint:CGPointMake(1, 1)];
  
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleNetworkConditions:(FBRouteRequest *)request
{
  XCUIApplication *app = [FBApplication fb_activeApplication];
  NSArray *alerts = [[app alerts] allElementsBoundByIndex];
  if (alerts.count > 0) {
    return FBResponseWithStatus(FBCommandStatusUnexpectedAlertPresent, [FBElementUtils alertSource:alerts[0] withInfo:@"A modal dialog was open, blocking this operation"]);
  }
  
  XCUIApplication *preferencesApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.Preferences"];
  [preferencesApp launch];
  FBResponseJSONPayload *response = nil;
  
  response = [FBElementCommands findAndTap:preferencesApp type:@"Cell" query:@"label" queryValue:@"Developer" useButtonTap:YES];
  if ([[[response dictionary] objectForKey:@"status"] integerValue] != 0) {
    [self terminatePreferencesApp:preferencesApp andActivate:app];
    return response;
  }

  response = [FBElementCommands findAndTap:preferencesApp type:@"Cell" query:@"label" queryValue:@"Network Link Conditioner" useButtonTap:YES];
  if ([[[response dictionary] objectForKey:@"status"] integerValue] != 0) {
    [self terminatePreferencesApp:preferencesApp andActivate:app];
    return response;
  }

  NSArray *cells = [[preferencesApp cells] allElementsBoundByIndex];
  if (cells.count == 0) {
    [self terminatePreferencesApp:preferencesApp andActivate:app];
    return FBResponseWithObject(@[]);
  }

  NSMutableArray *ret = [[NSMutableArray alloc] init];
  for (XCUIElement *cell in cells) {
    NSString *label = cell.label;
    if ([label caseInsensitiveCompare:@"Enable"] == NSOrderedSame ||
        [label caseInsensitiveCompare:@"Add a profile…"] == NSOrderedSame) {
      continue;
    }
    [ret addObject:label];
  }
  
  XCUIElement *switchElem = nil;
  while (switchElem == nil && switchElem.exists == NO) {
    [NSThread sleepForTimeInterval:0.5];
    switchElem = [FBElementCommands find:preferencesApp type:@"Switch" query:@"label" queryValue:@"Enable"];
  }
  BOOL enabled = [[switchElem value] integerValue] == 1;
  [self terminatePreferencesApp:preferencesApp andActivate:app];
  return FBResponseWithObject(@{@"enabled" : @(enabled), @"conditions" : ret});
}

//+ (id<FBResponsePayload>)handleNetworkThroughput:(FBRouteRequest *)request
//{
//  NSString *urlString = request.parameters[@"url"];
//  NSURL *url = [NSURL URLWithString:urlString];
//
//  NSURLSessionConfiguration *backgroundConfigurationObject = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:@"backgroundSessionIdentifier"];
//  NSURLSession *session = [NSURLSession sessionWithConfiguration:backgroundConfigurationObject delegate:self delegateQueue:[NSOperationQueue mainQueue]];
//
//  NSURLSessionDownloadTask *task = [session downloadTaskWithURL:url];
//  [task resume];
//  return FBResponseWithOK();
//}

+ (id<FBResponsePayload>)handleNetworkCondition:(FBRouteRequest *)request
{
  NSString *condition = request.arguments[@"condition"];
  
  XCUIApplication *app = [FBApplication fb_activeApplication];
  NSArray *alerts = [[app alerts] allElementsBoundByIndex];
  if (alerts.count > 0) {
    return FBResponseWithStatus(FBCommandStatusUnexpectedAlertPresent, [FBElementUtils alertSource:alerts[0] withInfo:@"A modal dialog was open, blocking this operation"]);
  }
  
  XCUIApplication *preferencesApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.apple.Preferences"];
  [preferencesApp launch];
  FBResponseJSONPayload *response = nil;
  
  response = [FBElementCommands findAndTap:preferencesApp type:@"Cell" query:@"label" queryValue:@"Developer" useButtonTap:YES];
  if ([[[response dictionary] objectForKey:@"status"] integerValue] != 0) {
    [self terminatePreferencesApp:preferencesApp andActivate:app];
    return response;
  }

  response = [FBElementCommands findAndTap:preferencesApp type:@"Cell" query:@"label" queryValue:@"Network Link Conditioner" useButtonTap:YES];
  if ([[[response dictionary] objectForKey:@"status"] integerValue] != 0) {
    [self terminatePreferencesApp:preferencesApp andActivate:app];
    return response;
  }
  
  XCUIElement *switchElem = nil;
  while (switchElem == nil && switchElem.exists == NO) {
    [NSThread sleepForTimeInterval:0.5];
    switchElem = [FBElementCommands find:preferencesApp type:@"Switch" query:@"label" queryValue:@"Enable"];
  }
  
  BOOL isOn = NO;
  if (switchElem) {
    isOn = [switchElem.value integerValue] == 1;
    if (condition == nil) {
      if (isOn) {
        [switchElem tap];
      }
      [self terminatePreferencesApp:preferencesApp andActivate:app];
      return FBResponseWithOK();
    }
  }
  else {
    [self terminatePreferencesApp:preferencesApp andActivate:app];
    return FBResponseWithStatus(FBCommandStatusUnhandled, [NSString stringWithFormat:@"Couldn't enable network link condition: %@", condition]);
  }
  
  XCUIElement *cellElem = [FBElementCommands find:preferencesApp type:@"Cell" query:@"label" queryValue:condition];
  if (cellElem != nil && cellElem.exists) {
    if (isOn == NO) {
      [switchElem tap];
    }
    [cellElem tap];
  }
  else {
    [self terminatePreferencesApp:preferencesApp andActivate:app];
    return FBResponseWithStatus(FBCommandStatusUnhandled, [NSString stringWithFormat:@"Couldn't enable network link condition: %@", condition]);
  }
  [self terminatePreferencesApp:preferencesApp andActivate:app];
  return FBResponseWithOK();
}

+ (void)terminatePreferencesApp:(XCUIApplication *)preferencesApp andActivate:(XCUIApplication *)app {
  if (UIInterfaceOrientationIsPortrait([app interfaceOrientation])) {
    // launching the original app causes issues with navigation links if you go back and forth between settings app and the original app.
    [FBElementCommands tapCoordinate:preferencesApp tapPoint:CGPointMake(15, 15)];
  }
  else {
    //  [[FBSession activeSession] launchApplicationWithBundleId:bundleId
    //                         shouldWaitForQuiescence:@(YES)
    //                                       arguments:nil
    //                                     environment:nil];
    
    // landscape mode doesn't have the app navigation button
    [app activate];
  }
  [preferencesApp terminate];
}

@end
