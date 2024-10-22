/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBElementCommands.h"

#import "FBApplication.h"
#import "FBConfiguration.h"
#import "FBKeyboard.h"
#import "FBPredicate.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBRunLoopSpinner.h"
#import "FBElementCache.h"
#import "FBElementUtils.h"
#import "FBErrorBuilder.h"
#import "FBSession.h"
#import "FBApplication.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "FBRuntimeUtils.h"
#import "NSPredicate+FBFormat.h"
#import "XCUICoordinate.h"
#import "XCUIDevice.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBPickerWheel.h"
#import "XCUIElement+FBScrolling.h"
#import "XCUIElement+FBTap.h"
#import "XCUIElement+FBForceTouch.h"
#import "XCUIElement+FBTyping.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "FBElementTypeTransformer.h"
#import "XCUIElement.h"
#import "XCUIElementQuery.h"
#import "FBXCodeCompatibility.h"
#import "XCEventGenerator.h"

@interface FBElementCommands ()
@end

@implementation FBElementCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute GET:@"/window/size"] respondWithTarget:self action:@selector(handleGetWindowSize:)],
    [[FBRoute GET:@"/element/:uuid/enabled"] respondWithTarget:self action:@selector(handleGetEnabled:)],
    [[FBRoute GET:@"/element/:uuid/rect"] respondWithTarget:self action:@selector(handleGetRect:)],
    [[FBRoute GET:@"/element/:uuid/attribute/:name"] respondWithTarget:self action:@selector(handleGetAttribute:)],
    [[FBRoute GET:@"/element/:uuid/text"] respondWithTarget:self action:@selector(handleGetText:)],
    [[FBRoute GET:@"/element/:uuid/displayed"] respondWithTarget:self action:@selector(handleGetDisplayed:)],
    [[FBRoute GET:@"/element/:uuid/name"] respondWithTarget:self action:@selector(handleGetName:)],
    [[FBRoute POST:@"/element/:uuid/value"] respondWithTarget:self action:@selector(handleSetValue:)],
    [[FBRoute POST:@"/element/:uuid/click"] respondWithTarget:self action:@selector(handleClick:)],
    [[FBRoute POST:@"/element/:uuid/clear"] respondWithTarget:self action:@selector(handleClear:)],
    // W3C element screenshot
    [[FBRoute GET:@"/element/:uuid/screenshot"] respondWithTarget:self action:@selector(handleElementScreenshot:)],
    // JSONWP element screenshot
    [[FBRoute GET:@"/screenshot/:uuid"] respondWithTarget:self action:@selector(handleElementScreenshot:)],
    [[FBRoute GET:@"/wda/element/:uuid/accessible"] respondWithTarget:self action:@selector(handleGetAccessible:)],
    [[FBRoute GET:@"/wda/element/:uuid/accessibilityContainer"] respondWithTarget:self action:@selector(handleGetIsAccessibilityContainer:)],
    [[FBRoute POST:@"/wda/element/:uuid/swipe"] respondWithTarget:self action:@selector(handleSwipe:)],
    [[FBRoute POST:@"/wda/element/:uuid/pinch"] respondWithTarget:self action:@selector(handlePinch:)],
    [[FBRoute POST:@"/wda/element/:uuid/doubleTap"] respondWithTarget:self action:@selector(handleDoubleTap:)],
    [[FBRoute POST:@"/wda/element/:uuid/twoFingerTap"] respondWithTarget:self action:@selector(handleTwoFingerTap:)],
    [[FBRoute POST:@"/wda/element/:uuid/touchAndHold"] respondWithTarget:self action:@selector(handleTouchAndHold:)],
    [[FBRoute POST:@"/wda/element/:uuid/scroll"] respondWithTarget:self action:@selector(handleScroll:)],
    [[FBRoute POST:@"/wda/element/:uuid/dragfromtoforduration"] respondWithTarget:self action:@selector(handleDrag:)],
    [[FBRoute POST:@"/wda/dragfromtoforduration"] respondWithTarget:self action:@selector(handleDragCoordinate:)],
    [[FBRoute POST:@"/wda/dragfromtoforduration2"] respondWithTarget:self action:@selector(handleDragCoordinate2:)],
    [[FBRoute POST:@"/wda/tap/:uuid"] respondWithTarget:self action:@selector(handleTap:)],
    [[FBRoute POST:@"/wda/tap"] respondWithTarget:self action:@selector(handleTapCoordinate:)],
    [[FBRoute POST:@"/wda/findAndTap"] respondWithTarget:self action:@selector(handleFindAndTap:)],
    [[FBRoute POST:@"/wda/touchAndHold"] respondWithTarget:self action:@selector(handleTouchAndHoldCoordinate:)],
    [[FBRoute POST:@"/wda/doubleTap"] respondWithTarget:self action:@selector(handleDoubleTapCoordinate:)],
    [[FBRoute POST:@"/wda/keys"] respondWithTarget:self action:@selector(handleKeys:)],
    [[FBRoute POST:@"/wda/pickerwheel/:uuid/select"] respondWithTarget:self action:@selector(handleWheelSelect:)],
    [[FBRoute POST:@"/wda/element/:uuid/forceTouch"] respondWithTarget:self action:@selector(handleForceTouch:)],
  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleGetEnabled:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  BOOL isEnabled = element.isWDEnabled;
  return FBResponseWithStatus(FBCommandStatusNoError, isEnabled ? @YES : @NO);
}

+ (id<FBResponsePayload>)handleGetRect:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  return FBResponseWithStatus(FBCommandStatusNoError, element.wdRect);
}

+ (id<FBResponsePayload>)handleGetAttribute:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  id attributeValue = [element fb_valueForWDAttributeName:request.parameters[@"name"]];
  attributeValue = attributeValue ?: [NSNull null];
  return FBResponseWithStatus(FBCommandStatusNoError, attributeValue);
}

+ (id<FBResponsePayload>)handleGetText:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  id text = FBFirstNonEmptyValue(element.wdValue, element.wdLabel);
  text = text ?: @"";
  return FBResponseWithStatus(FBCommandStatusNoError, text);
}

+ (id<FBResponsePayload>)handleGetDisplayed:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  BOOL isVisible = element.isWDVisible;
  return FBResponseWithStatus(FBCommandStatusNoError, isVisible ? @YES : @NO);
}

+ (id<FBResponsePayload>)handleGetAccessible:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  return FBResponseWithStatus(FBCommandStatusNoError, @(element.isWDAccessible));
}

+ (id<FBResponsePayload>)handleGetIsAccessibilityContainer:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  return FBResponseWithStatus(FBCommandStatusNoError, @(element.isWDAccessibilityContainer));
}

+ (id<FBResponsePayload>)handleGetName:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  id type = [element wdType];
  return FBResponseWithStatus(FBCommandStatusNoError, type);
}

static NSString *const PREFERRED_TYPE_STRATEGY_FB_WDA = @"fbwda";

+ (id<FBResponsePayload>)handleSetValue:(FBRouteRequest *)request
{
  NSString *preferredStrategy = request.parameters[@"preferredStrategy"] ?: @"";
  if (preferredStrategy.length > 0) {
    [FBLogger logFmt:@"handleSetValue received request with preferredStrategy: %@", preferredStrategy];
  }
  
  FBElementCache *elementCache = request.session.elementCache;
  NSString *elementUUID = request.parameters[@"uuid"];
  XCUIElement *element = [elementCache elementForUUID:elementUUID];
  id value = request.arguments[@"value"];
  if (!value) {
    return FBResponseWithErrorFormat(@"Missing 'value' parameter");
  }
  NSString *textToType = value;
  if ([value isKindOfClass:[NSArray class]]) {
    textToType = [value componentsJoinedByString:@""];
  }
  if (element.elementType == XCUIElementTypePickerWheel) {
    [element adjustToPickerWheelValue:textToType];
    return FBResponseWithOK();
  }
  if (element.elementType == XCUIElementTypeSlider) {
    CGFloat sliderValue = textToType.floatValue;
    if (sliderValue < 0.0 || sliderValue > 1.0 ) {
      return FBResponseWithErrorFormat(@"Value of slider should be in 0..1 range");
    }
    [element adjustToNormalizedSliderPosition:sliderValue];
    return FBResponseWithOK();
  }
  NSUInteger frequency = (NSUInteger)[request.arguments[@"frequency"] longLongValue] ?: [FBConfiguration maxTypingFrequency];
  NSError *error = nil;
  
  if ([preferredStrategy caseInsensitiveCompare:PREFERRED_TYPE_STRATEGY_FB_WDA] == NSOrderedSame) {
    
    [FBLogger logFmt:@"handleSetValue using preferredStrategy: %@", preferredStrategy];
    
    if (![element fb_wda_typeText:textToType frequency:frequency error:&error]) {
      return FBResponseWithError(error);
    }
  }
  else {
    if (![element fb_typeText:textToType frequency:frequency error:&error]) {
      return FBResponseWithError(error);
    }
  }
  
  return FBResponseWithElementUUID(elementUUID);
}

+ (id<FBResponsePayload>)handleClick:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  NSString *elementUUID = request.parameters[@"uuid"];
  XCUIElement *element = [elementCache elementForUUID:elementUUID];
  NSError *error = nil;
  if (![element fb_tapWithError:&error]) {
    return FBResponseWithError(error);
  }
  return FBResponseWithElementUUID(elementUUID);
}

+ (id<FBResponsePayload>)handleClear:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  NSString *elementUUID = request.parameters[@"uuid"];
  XCUIElement *element = [elementCache elementForUUID:elementUUID];
  NSError *error;
  if (![element fb_clearTextWithError:&error]) {
    return FBResponseWithError(error);
  }
  return FBResponseWithElementUUID(elementUUID);
}

+ (id<FBResponsePayload>)handleDoubleTap:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  [element doubleTap];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleDoubleTapCoordinate:(FBRouteRequest *)request
{
  CGPoint doubleTapPoint = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
  XCUICoordinate *doubleTapCoordinate = [self.class gestureCoordinateWithCoordinate:doubleTapPoint application:request.session.activeApplication shouldApplyOrientationWorkaround:isSDKVersionLessThan(@"11.0")];
  [doubleTapCoordinate doubleTap];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTwoFingerTap:(FBRouteRequest *)request
{
    FBElementCache *elementCache = request.session.elementCache;
    XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
    [element twoFingerTap];
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTouchAndHold:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  [element pressForDuration:[request.arguments[@"duration"] doubleValue]];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTouchAndHoldCoordinate:(FBRouteRequest *)request
{
  CGPoint touchPoint = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
  XCUICoordinate *pressCoordinate = [self.class gestureCoordinateWithCoordinate:touchPoint application:request.session.activeApplication shouldApplyOrientationWorkaround:isSDKVersionLessThan(@"11.0")];
  [pressCoordinate pressForDuration:[request.arguments[@"duration"] doubleValue]];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleForceTouch:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  double pressure = [request.arguments[@"pressure"] doubleValue];
  double duration = [request.arguments[@"duration"] doubleValue];
  NSError *error;
  if (nil != request.arguments[@"x"] && nil != request.arguments[@"y"]) {
    CGPoint forceTouchPoint = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
    if (![element fb_forceTouchCoordinate:forceTouchPoint pressure:pressure duration:duration error:&error]) {
      return FBResponseWithError(error);
    }
  } else {
    if (![element fb_forceTouchWithPressure:pressure duration:duration error:&error]) {
      return FBResponseWithError(error);
    }
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleScroll:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];

  // Using presence of arguments as a way to convey control flow seems like a pretty bad idea but it's
  // what ios-driver did and sadly, we must copy them.
  NSString *const name = request.arguments[@"name"];
  if (name) {
    XCUIElement *childElement = [[[[element descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:name] allElementsBoundByAccessibilityElement] lastObject];
    if (!childElement) {
      return FBResponseWithErrorFormat(@"'%@' identifier didn't match any elements", name);
    }
    return [self.class handleScrollElementToVisible:childElement withRequest:request];
  }

  NSString *const direction = request.arguments[@"direction"];
  if (direction) {
    NSString *const distanceString = request.arguments[@"distance"] ?: @"1.0";
    CGFloat distance = (CGFloat)distanceString.doubleValue;
    if ([direction isEqualToString:@"up"]) {
      [element fb_scrollUpByNormalizedDistance:distance];
    } else if ([direction isEqualToString:@"down"]) {
      [element fb_scrollDownByNormalizedDistance:distance];
    } else if ([direction isEqualToString:@"left"]) {
      [element fb_scrollLeftByNormalizedDistance:distance];
    } else if ([direction isEqualToString:@"right"]) {
      [element fb_scrollRightByNormalizedDistance:distance];
    }
    return FBResponseWithOK();
  }

  NSString *const predicateString = request.arguments[@"predicateString"];
  if (predicateString) {
    NSPredicate *formattedPredicate = [NSPredicate fb_formatSearchPredicate:[FBPredicate predicateWithFormat:predicateString]];
    XCUIElement *childElement = [[[[element descendantsMatchingType:XCUIElementTypeAny] matchingPredicate:formattedPredicate] allElementsBoundByAccessibilityElement] lastObject];
    if (!childElement) {
      return FBResponseWithErrorFormat(@"'%@' predicate didn't match any elements", predicateString);
    }
    return [self.class handleScrollElementToVisible:childElement withRequest:request];
  }

  if (request.arguments[@"toVisible"]) {
    return [self.class handleScrollElementToVisible:element withRequest:request];
  }
  return FBResponseWithErrorFormat(@"Unsupported scroll type");
}

+ (id<FBResponsePayload>)handleDragCoordinate:(FBRouteRequest *)request
{
  XCUIApplication *app = [[XCUIApplication alloc] initWithBundleIdentifier: @"com.apple.springboard"];
  NSArray *alerts = [[app alerts] allElementsBoundByIndex];
  if (alerts.count > 0) {
      return FBResponseWithStatus(FBCommandStatusUnexpectedAlertPresent, [FBElementUtils alertSource:alerts[0] withInfo:@"A modal dialog was open, blocking this operation"]);
  }
  
  FBSession *session = request.session;
  CGPoint startPoint = CGPointMake((CGFloat)[request.arguments[@"fromX"] doubleValue], (CGFloat)[request.arguments[@"fromY"] doubleValue]);
  CGPoint endPoint = CGPointMake((CGFloat)[request.arguments[@"toX"] doubleValue], (CGFloat)[request.arguments[@"toY"] doubleValue]);
  NSTimeInterval duration = [request.arguments[@"duration"] doubleValue];
  [self drag:startPoint endPoint:endPoint duration:duration];
  return FBResponseWithOK();
}

+ (void)drag:(CGPoint)startPoint endPoint:(CGPoint)endPoint duration:(double)duration {
  FBApplication *app = [FBApplication fb_activeApplication];
  XCUICoordinate *endCoordinate = [self.class gestureCoordinateWithCoordinate:endPoint application:app shouldApplyOrientationWorkaround:isSDKVersionLessThan(@"11.0")];
  XCUICoordinate *startCoordinate = [self.class gestureCoordinateWithCoordinate:startPoint application:app shouldApplyOrientationWorkaround:isSDKVersionLessThan(@"11.0")];
  [startCoordinate pressForDuration:duration thenDragToCoordinate:endCoordinate];
}

+ (id<FBResponsePayload>)handleDragCoordinate2:(FBRouteRequest *)request
{
  XCUIApplication *app = [[XCUIApplication alloc] initWithBundleIdentifier: @"com.apple.springboard"];
  NSArray *alerts = [[app alerts] allElementsBoundByIndex];
  if (alerts.count > 0) {
      return FBResponseWithStatus(FBCommandStatusUnexpectedAlertPresent, [FBElementUtils alertSource:alerts[0] withInfo:@"A modal dialog was open, blocking this operation"]);
  }
  
  //  FBSession *session = request.session;
  CGPoint startPoint = CGPointMake((CGFloat)[request.arguments[@"fromX"] doubleValue], (CGFloat)[request.arguments[@"fromY"] doubleValue]);
  CGPoint endPoint = CGPointMake((CGFloat)[request.arguments[@"toX"] doubleValue], (CGFloat)[request.arguments[@"toY"] doubleValue]);
  
  double duration = [request.arguments[@"duration"] doubleValue] / 1000;
  double velocity = [request.arguments[@"velocity"] doubleValue] * 100;
  
  if (velocity <= 50) {
    velocity = 50;
  }
  
  if (velocity > 1500) {
    velocity = 1500;
  }
  
  [self drag2:startPoint endPoint:endPoint duration:duration velocity:velocity];
  return FBResponseWithOK();
}

+ (void)drag2:(CGPoint)startPoint endPoint:(CGPoint)endPoint duration:(double)duration velocity:(double)velocity {
  FBApplication *app = [FBApplication fb_activeApplication]; // [[XCUIApplication alloc] initWithBundleIdentifier: @"com.apple.springboard"];
  NSObject *lock = [NSObject new];
  __block BOOL isHandlerCalled = NO;
  
  XCEventGenerator * eventGenerator = [XCEventGenerator sharedGenerator];
  [eventGenerator pressAtPoint:startPoint forDuration:duration liftAtPoint:endPoint velocity:velocity orientation:app.interfaceOrientation
                          name:nil handler:^(XCSynthesizedEventRecord *record, NSError *error) {
    NSLog(@"handleDragCoordinate2 Error: %@", error);
    @synchronized(lock) {
      isHandlerCalled = YES;
    }
  }];
  
  while(true) {
    @synchronized(lock) {
      if (isHandlerCalled) {
        //Exit from loop.
        break;
      }
    }
    //Keep the run loop running, so this thread isn't blocked.
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow:1]];
  }
}

+ (id<FBResponsePayload>)handleDrag:(FBRouteRequest *)request
{
  FBSession *session = request.session;
  FBElementCache *elementCache = session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  CGPoint startPoint = CGPointMake((CGFloat)(element.frame.origin.x + [request.arguments[@"fromX"] doubleValue]), (CGFloat)(element.frame.origin.y + [request.arguments[@"fromY"] doubleValue]));
  CGPoint endPoint = CGPointMake((CGFloat)(element.frame.origin.x + [request.arguments[@"toX"] doubleValue]), (CGFloat)(element.frame.origin.y + [request.arguments[@"toY"] doubleValue]));
  NSTimeInterval duration = [request.arguments[@"duration"] doubleValue];
  BOOL shouldApplyOrientationWorkaround = isSDKVersionGreaterThanOrEqualTo(@"10.0") && isSDKVersionLessThan(@"11.0");
  XCUICoordinate *endCoordinate = [self.class gestureCoordinateWithCoordinate:endPoint application:session.activeApplication shouldApplyOrientationWorkaround:shouldApplyOrientationWorkaround];
  XCUICoordinate *startCoordinate = [self.class gestureCoordinateWithCoordinate:startPoint application:session.activeApplication shouldApplyOrientationWorkaround:shouldApplyOrientationWorkaround];
  [startCoordinate pressForDuration:duration thenDragToCoordinate:endCoordinate];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleSwipe:(FBRouteRequest *)request
{
    FBElementCache *elementCache = request.session.elementCache;
    XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
    NSString *const direction = request.arguments[@"direction"];
    if (!direction) {
        return FBResponseWithErrorFormat(@"Missing 'direction' parameter");
    }
    if ([direction isEqualToString:@"up"]) {
        [element swipeUp];
    } else if ([direction isEqualToString:@"down"]) {
        [element swipeDown];
    } else if ([direction isEqualToString:@"left"]) {
        [element swipeLeft];
    } else if ([direction isEqualToString:@"right"]) {
        [element swipeRight];
    } else {
      return FBResponseWithErrorFormat(@"Unsupported swipe type");
    }
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTap:(FBRouteRequest *)request
{
  CGPoint tapPoint = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);

  XCUIApplication *app = [[XCUIApplication alloc] initWithBundleIdentifier: @"com.apple.springboard"];
  NSArray *alerts = [[app alerts] allElementsBoundByIndex];
  
  FBApplication *application = request.session.activeApplication ?: [FBApplication fb_activeApplication];
  NSArray *appAlerts = [[application alerts] allElementsBoundByIndex];
  
  NSArray *allAlerts = [alerts arrayByAddingObjectsFromArray:appAlerts];
  
//  NSLog(@"### TIVO DEBUG 2: alerts count: %lu", (unsigned long)allAlerts.count);
  if (allAlerts.count > 0) {
    XCUIElement *alert = allAlerts[0];
    NSArray *texts = [[alert staticTexts] allElementsBoundByIndex];
    NSString *title = [texts[0] label];
    NSString *subtitle = texts.count > 1 ? [texts[1] label] : @"";
    NSArray *buttons = [[alert buttons] allElementsBoundByIndex];
    for (XCUIElement *button in buttons) {
      BOOL contains = CGRectContainsPoint(button.frame, tapPoint);
      if (contains == NO) {
        // see if the device in landscape mode and translate the coordinates
        CGRect buttonFrame = button.frame;
        UIInterfaceOrientation orientation = FBApplication.fb_activeApplication.interfaceOrientation;
        CGSize screenSize = FBAdjustDimensionsForApplication(application.windows.fb_firstMatch.frame.size, orientation);
        CGPoint point = FBInvertPointForApplication(CGPointMake(buttonFrame.origin.x, buttonFrame.origin.y), screenSize, orientation);
        CGSize size = FBAdjustDimensionsForApplication(buttonFrame.size, orientation);
        buttonFrame = CGRectMake(point.x, point.y, size.width, size.height);
        contains = CGRectContainsPoint(buttonFrame, tapPoint);
      }
      if (contains == YES) {
        NSString *label = [button label];
//        NSLog(@"### TIVO DEBUG 2: found alert button to tap: %@", label);
        [button tap];
        return FBResponseWithStatus(FBCommandStatusNoError, @{
                                                              @"action": @"tap",
                                                              @"element": @"button",
                                                              @"id": label,
                                                              @"point": @{
                                                                  @"x": @(tapPoint.x),
                                                                  @"y": @(tapPoint.y)
                                                                  },
                                                              @"alert":@{
                                                                  @"title" : title != nil ? title : @"",
                                                                  @"subtitle" : subtitle != nil ? subtitle : @""
                                                                  }
                                                              });
      }
    }
    
    if (allAlerts.count > 0) {
      return FBResponseWithStatus(FBCommandStatusUnexpectedAlertPresent, [FBElementUtils alertSource:alert withInfo:@"A modal dialog was open, blocking this operation"]);
    }
  }
  
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  if (nil == element) {
    XCUICoordinate *tapCoordinate = [self.class gestureCoordinateWithCoordinate:tapPoint application:request.session.activeApplication shouldApplyOrientationWorkaround:isSDKVersionLessThan(@"11.0")];
    [tapCoordinate tap];
  } else {
    NSError *error;
    if (![element fb_tapCoordinate:tapPoint error:&error]) {
      return FBResponseWithError(error);
    }
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleTapCoordinate:(FBRouteRequest *)request {
  CGPoint tapPoint = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
  
  XCUIApplication *app = [[XCUIApplication alloc] initWithBundleIdentifier: @"com.apple.springboard"];
  NSArray *alerts = [[app alerts] allElementsBoundByIndex];
  
  FBApplication *application = request.session.activeApplication ?: [FBApplication fb_activeApplication];
  NSArray *appAlerts = [[application alerts] allElementsBoundByIndex];
  
  NSArray *allAlerts = [alerts arrayByAddingObjectsFromArray:appAlerts];
  
//  NSLog(@"### TIVO DEBUG 2: alerts count: %lu", (unsigned long)allAlerts.count);
  if (allAlerts.count > 0) {
    XCUIElement *alert = allAlerts[0];
    NSArray *texts = [[alert staticTexts] allElementsBoundByIndex];
    NSString *title = [texts[0] label];
    NSString *subtitle = texts.count > 1 ? [texts[1] label] : @"";
    NSArray *buttons = [[alert buttons] allElementsBoundByIndex];
    for (XCUIElement *button in buttons) {
      BOOL contains = CGRectContainsPoint(button.frame, tapPoint);
      if (contains == NO) {
        // see if the device in landscape mode and translate the coordinates
        CGRect buttonFrame = button.frame;
        UIInterfaceOrientation orientation = FBApplication.fb_activeApplication.interfaceOrientation;
        CGSize screenSize = FBAdjustDimensionsForApplication(application.frame.size, orientation);
        CGPoint point = FBInvertPointForApplication(CGPointMake(buttonFrame.origin.x, buttonFrame.origin.y), screenSize, orientation);
        CGSize size = FBAdjustDimensionsForApplication(buttonFrame.size, orientation);
        buttonFrame = CGRectMake(point.x, point.y, size.width, size.height);
        contains = CGRectContainsPoint(buttonFrame, tapPoint);
      }
      if (contains == YES) {
        NSString *label = [button label];
//        NSLog(@"### TIVO DEBUG 2: found alert button to tap: %@", label);
        [button tap];
        return FBResponseWithStatus(FBCommandStatusNoError, @{
                                                              @"action": @"tap",
                                                              @"element": @"button",
                                                              @"id": label,
                                                              @"point": @{
                                                                  @"x": @(tapPoint.x),
                                                                  @"y": @(tapPoint.y)
                                                                  },
                                                              @"alert":@{
                                                                  @"title" : title != nil ? title : @"",
                                                                  @"subtitle" : subtitle != nil ? subtitle : @""
                                                                  }
                                                              });
      }
    }
    
    if (allAlerts.count > 0) {
      return FBResponseWithStatus(FBCommandStatusUnexpectedAlertPresent, [FBElementUtils alertSource:allAlerts[0] withInfo:@"A modal dialog was open, blocking this operation"]);
    }
  }
    
  
  [self tapCoordinate:application tapPoint:tapPoint];
  
  return FBResponseWithOK();
}

+ (void)tapCoordinate:(XCUIApplication *)application tapPoint:(CGPoint)tapPoint {
  XCUICoordinate *tapCoordinate = [self.class gestureCoordinateWithCoordinate:tapPoint application:application shouldApplyOrientationWorkaround:isSDKVersionLessThan(@"11.0")];
  [tapCoordinate tap];
}

+ (id<FBResponsePayload>)handlePinch:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  CGFloat scale = (CGFloat)[request.arguments[@"scale"] doubleValue];
  CGFloat velocity = (CGFloat)[request.arguments[@"velocity"] doubleValue];
  [element pinchWithScale:scale velocity:velocity];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleKeys:(FBRouteRequest *)request
{
  NSString *textToType = [request.arguments[@"value"] componentsJoinedByString:@""];
  NSUInteger frequency = [request.arguments[@"frequency"] unsignedIntegerValue] ?: [FBConfiguration maxTypingFrequency];
  BOOL debug = [request.arguments[@"debug"] boolValue];

  NSError *error;
  if (![FBKeyboard typeText:textToType frequency:frequency error:&error]) {
    [FBLogger logFmt:@"/keys failed to type %@ with error: %@", textToType, error];
    return FBResponseWithError(error);
  }
  if (debug) {
    FBApplication *application = [FBApplication fb_activeApplication];
    NSArray *textFields = [[application textFields] allElementsBoundByIndex];
    NSArray *searchFields = [[application searchFields] allElementsBoundByIndex];
    NSArray *secureTextFields = [[application secureTextFields] allElementsBoundByIndex];
    NSArray *textViews = [[application textViews] allElementsBoundByIndex];
    NSArray *fields = [[[textFields arrayByAddingObjectsFromArray:searchFields] arrayByAddingObjectsFromArray:secureTextFields] arrayByAddingObjectsFromArray:textViews];
    if (fields.count > 0) {
      for (XCUIElement *textField in fields) {
        if (textField.hasKeyboardFocus) {
          NSString *text = textField.value;
          [FBLogger logFmt:@"/keys typed %@ and read %@", textToType, text];
          break;
        }
      }
    }
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleGetWindowSize:(FBRouteRequest *)request
{
  CGRect frame = request.session.activeApplication.wdFrame;
  CGSize screenSize = FBAdjustDimensionsForApplication(frame.size, request.session.activeApplication.interfaceOrientation);
  return FBResponseWithStatus(FBCommandStatusNoError, @{
    @"width": @(screenSize.width),
    @"height": @(screenSize.height),
  });
}

+ (id<FBResponsePayload>)handleElementScreenshot:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  NSError *error;
  NSData *screenshotData = [element fb_screenshotWithError:&error];
  if (nil == screenshotData) {
    return FBResponseWithError(error);
  }
  NSString *screenshot = [screenshotData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
  return FBResponseWithObject(screenshot);
}

static const CGFloat DEFAULT_OFFSET = (CGFloat)0.2;

+ (id<FBResponsePayload>)handleWheelSelect:(FBRouteRequest *)request
{
  FBElementCache *elementCache = request.session.elementCache;
  XCUIElement *element = [elementCache elementForUUID:request.parameters[@"uuid"]];
  if (element.elementType != XCUIElementTypePickerWheel) {
    return FBResponseWithErrorFormat(@"The element is expected to be a valid Picker Wheel control. '%@' was given instead", element.wdType);
  }
  NSString* order = [request.arguments[@"order"] lowercaseString];
  CGFloat offset = DEFAULT_OFFSET;
  if (request.arguments[@"offset"]) {
    offset = (CGFloat)[request.arguments[@"offset"] doubleValue];
    if (offset <= 0.0 || offset > 0.5) {
      return FBResponseWithErrorFormat(@"'offset' value is expected to be in range (0.0, 0.5]. '%@' was given instead", request.arguments[@"offset"]);
    }
  }
  BOOL isSuccessful = false;
  NSError *error;
  if ([order isEqualToString:@"next"]) {
    isSuccessful = [element fb_selectNextOptionWithOffset:offset error:&error];
  } else if ([order isEqualToString:@"previous"]) {
    isSuccessful = [element fb_selectPreviousOptionWithOffset:offset error:&error];
  } else {
    return FBResponseWithErrorFormat(@"Only 'previous' and 'next' order values are supported. '%@' was given instead", request.arguments[@"order"]);
  }
  if (!isSuccessful) {
    return FBResponseWithError(error);
  }
  return FBResponseWithOK();
}

#pragma mark - Helpers

+ (id<FBResponsePayload>)handleScrollElementToVisible:(XCUIElement *)element withRequest:(FBRouteRequest *)request
{
  NSError *error;
  if (!element.exists) {
    return FBResponseWithErrorFormat(@"Can't scroll to element that does not exist");
  }
  if (![element fb_scrollToVisibleWithError:&error]) {
    return FBResponseWithError(error);
  }
  return FBResponseWithOK();
}

/**
 Returns gesture coordinate for the application based on absolute coordinate

 @param coordinate absolute screen coordinates
 @param application the instance of current application under test
 @shouldApplyOrientationWorkaround whether to apply orientation workaround. This is to
 handle XCTest bug where it does not translate screen coordinates for elements if
 screen orientation is different from the default one (which is portrait).
 Different iOS version have different behavior, for example iOS 9.3 returns correct
 coordinates for elements in landscape, but iOS 10.0+ returns inverted coordinates as if
 the current screen orientation would be portrait.
 @return translated gesture coordinates ready to be passed to XCUICoordinate methods
 */
+ (XCUICoordinate *)gestureCoordinateWithCoordinate:(CGPoint)coordinate application:(XCUIApplication *)application shouldApplyOrientationWorkaround:(BOOL)shouldApplyOrientationWorkaround
{
  CGPoint point = coordinate;
  if (shouldApplyOrientationWorkaround) {
    point = FBInvertPointForApplication(coordinate, application.frame.size, application.interfaceOrientation);
  }

  /**
   If SDK >= 11, the tap coordinate based on application is not correct when
   the application orientation is landscape and
   tapX > application portrait width or tapY > application portrait height.
   Pass the window element to the method [FBElementCommands gestureCoordinateWithCoordinate:element:]
   will resolve the problem.
   More details about the bug, please see the following issues:
   #705: https://github.com/facebook/WebDriverAgent/issues/705
   #798: https://github.com/facebook/WebDriverAgent/issues/798
   #856: https://github.com/facebook/WebDriverAgent/issues/856
   Notice: On iOS 10, if the application is not launched by wda, no elements will be found.
   See issue #732: https://github.com/facebook/WebDriverAgent/issues/732
   */
  XCUIElement *element = application;
  if (isSDKVersionGreaterThanOrEqualTo(@"11.0")) {
    XCUIElement *window = application.windows.fb_firstMatch;
    if (window) {
      element = window;
      point.x -= element.frame.origin.x;
      point.y -= element.frame.origin.y;
    }
  }
  return [self gestureCoordinateWithCoordinate:point element:element];
}

/**
 Returns gesture coordinate based on the specified element.

 @param coordinate absolute coordinates based on the element
 @param element the element in the current application under test
 @return translated gesture coordinates ready to be passed to XCUICoordinate methods
 */
+ (XCUICoordinate *)gestureCoordinateWithCoordinate:(CGPoint)coordinate element:(XCUIElement *)element
{
  XCUICoordinate *appCoordinate = [[XCUICoordinate alloc] initWithElement:element normalizedOffset:CGVectorMake(0, 0)];
  return [[XCUICoordinate alloc] initWithCoordinate:appCoordinate pointsOffset:CGVectorMake(coordinate.x, coordinate.y)];
}

+ (id<FBResponsePayload>)handleFindAndTap:(FBRouteRequest *)request
{
//  CGFloat x = [request.arguments[@"x"] doubleValue];
//  CGFloat y = [request.arguments[@"y"] doubleValue];
//  CGFloat width = [request.arguments[@"width"] doubleValue];
//  CGFloat height = [request.arguments[@"height"] doubleValue];
  NSString *type = request.arguments[@"type"];
  NSString *query = request.arguments[@"query"];
  NSString *queryValue = request.arguments[@"queryValue"];
  FBApplication *application = [FBApplication fb_activeApplication];
  
  NSArray *alerts = [[application alerts] allElementsBoundByIndex];
  if (alerts.count > 0 && queryValue != nil) {
    XCUIElement *alert = alerts[0];
    NSArray *buttons = [[alert buttons] allElementsBoundByIndex];
    for (XCUIElement *button in buttons) {
      if ([button.label caseInsensitiveCompare:queryValue] == NSOrderedSame) {
        [button tap];
        return FBResponseWithStatus(FBCommandStatusNoError, @{@"tapTime" : @([[NSDate date] timeIntervalSince1970])});
      }
    }
  }
  
  return [self findAndTap:application type:type query:query queryValue:queryValue useButtonTap:NO];
}

+ (XCUIElementType)elementTypeFromName:(NSString *)name {
  static NSDictionary<NSString *, NSNumber *> *typeToNameDict;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    typeToNameDict = @{
                       @"Any" : @0,
                       @"Other" : @1,
                       @"Application" : @2,
                       @"Group" : @3,
                       @"Window" : @4,
                       @"Sheet" : @5,
                       @"Drawer" : @6,
                       @"Alert" : @7,
                       @"Dialog" : @8,
                       @"Button" : @9,
                       @"RadioButton" : @10,
                       @"RadioGroup" : @11,
                       @"CheckBox" : @12,
                       @"DisclosureTriangle" : @13,
                       @"PopUpButton" : @14,
                       @"ComboBox" : @15,
                       @"MenuButton" : @16,
                       @"ToolbarButton" : @17,
                       @"Popover" : @18,
                       @"Keyboard" : @19,
                       @"Key" : @20,
                       @"NavigationBar" : @21,
                       @"TabBar" : @22,
                       @"TabGroup" : @23,
                       @"Toolbar" : @24,
                       @"StatusBar" : @25,
                       @"Table" : @26,
                       @"TableRow" : @27,
                       @"TableColumn" : @28,
                       @"Outline" : @29,
                       @"OutlineRow" : @30,
                       @"Browser" : @31,
                       @"CollectionView" : @32,
                       @"Slider" : @33,
                       @"PageIndicator" : @34,
                       @"ProgressIndicator" : @35,
                       @"ActivityIndicator" : @36,
                       @"SegmentedControl" : @37,
                       @"Picker" : @38,
                       @"PickerWheel" : @39,
                       @"Switch" : @40,
                       @"Toggle" : @41,
                       @"Link" : @42,
                       @"Image" : @43,
                       @"Icon" : @44,
                       @"SearchField" : @45,
                       @"ScrollView" : @46,
                       @"ScrollBar" : @47,
                       @"StaticText" : @48,
                       @"TextField" : @49,
                       @"SecureTextField" : @50,
                       @"DatePicker" : @51,
                       @"TextView" : @52,
                       @"Menu" : @53,
                       @"MenuItem" : @54,
                       @"MenuBar" : @55,
                       @"MenuBarItem" : @56,
                       @"Map" : @57,
                       @"WebView" : @58,
                       @"IncrementArrow" : @59,
                       @"DecrementArrow" : @60,
                       @"Timeline" : @61,
                       @"RatingIndicator" : @62,
                       @"ValueIndicator" : @63,
                       @"SplitGroup" : @64,
                       @"Splitter" : @65,
                       @"RelevanceIndicator" : @66,
                       @"ColorWell" : @67,
                       @"HelpTag" : @68,
                       @"Matte" : @69,
                       @"DockItem" : @70,
                       @"Ruler" : @71,
                       @"RulerMarker" : @72,
                       @"Grid" : @73,
                       @"LevelIndicator" : @74,
                       @"Cell" : @75,
                       @"LayoutArea" : @76,
                       @"LayoutItem" : @77,
                       @"Handle" : @78,
                       @"Stepper" : @79,
                       @"Tab" : @80,
                       @"TouchBar" : @81,
                       @"StatusItem" : @82
                       };
  });
  
  NSNumber *ret = [typeToNameDict objectForKey:name];
  if (ret == nil) {
    return -1;
  }
  return [ret integerValue];
}

+ (id)find:(XCUIApplication *)application type:(NSString *)type query:(NSString *)query queryValue:(NSString *)queryValue {
  if (type == nil) {
    return nil;
  }
  
  XCUIElementType elementType = [self elementTypeFromName:type];
  if (elementType == (XCUIElementType)-1) {
    return nil;
  }
  
  //  if (elementType != XCUIElementTypeOther) {
  //    NSArray <XCUIElement *> *children = [application descendantsMatchingType:elementType].allElementsBoundByIndex;
  
  NSString *matchString = [NSString stringWithFormat: @".*\\b%@", queryValue];
  NSString *predicateString = [NSString stringWithFormat:@"%@ MATCHES[c] %%@", query];
  
  NSPredicate *predicate = [NSPredicate predicateWithFormat: predicateString, matchString];
  XCUIElement *element = [[application descendantsMatchingType:elementType] elementMatchingPredicate:predicate];
  if ([element exists]) {
    return element;
  }
  return nil;
}

+ (id<FBResponsePayload>)findAndTap:(XCUIApplication *)application type:(NSString *)type query:(NSString *)query queryValue:(NSString *)queryValue useButtonTap:(BOOL)useButtonTap {
  if (type == nil) {
    return FBResponseWithErrorFormat(@"type is missing");
  }
  
  XCUIElementType elementType = [self elementTypeFromName:type];
  if (elementType == (XCUIElementType)-1) {
    return FBResponseWithErrorFormat(@"Type %@ is invalid", type);
  }
  
  //  if (elementType != XCUIElementTypeOther) {
  //    NSArray <XCUIElement *> *children = [application descendantsMatchingType:elementType].allElementsBoundByIndex;
  
  NSString *matchString = [NSString stringWithFormat: @".*\\b%@.*", queryValue];
  NSString *predicateString = [NSString stringWithFormat:@"%@ MATCHES[c] %%@", query];
  
  NSPredicate *predicate = [NSPredicate predicateWithFormat: predicateString, matchString];
  XCUIElement *element = [[application descendantsMatchingType:elementType] elementMatchingPredicate:predicate];
  if ([element exists]) { //} && [element isEnabled]) {
    //      NSString *wdname = element.wdName;
    //      NSString *wdvalue = element.wdValue;
    //      id evalue = element.value;
    //      NSLog(@"%@, %@, %@", wdname, wdvalue, evalue);
    
    if (/*[type caseInsensitiveCompare:@"button"] == NSOrderedSame &&*/ useButtonTap) {
      [element tap];
    }
    else {
      NSDictionary *rect = [element wdRect];
      CGFloat x = [[rect objectForKey:@"x"] floatValue];
      CGFloat y = [[rect objectForKey:@"y"] floatValue];
      CGFloat width = [[rect objectForKey:@"width"] doubleValue];
      CGFloat height = [[rect objectForKey:@"height"] doubleValue];
      CGPoint tapPoint = CGPointMake(x + width/2, y + height/2);
      XCUICoordinate *tapCoordinate = [self.class gestureCoordinateWithCoordinate:tapPoint application:application shouldApplyOrientationWorkaround:isSDKVersionLessThan(@"11.0")];
      [tapCoordinate tap];
    }
    return FBResponseWithStatus(FBCommandStatusNoError, @{@"tapTime" : @([[NSDate date] timeIntervalSince1970])});
    //    }
    //    for (XCUIElement *child in children) {
    //      BOOL compare = NO;
    //      if (label != nil) {
    //        compare = [label caseInsensitiveCompare:child.label] == NSOrderedSame;
    //      }
    //      else if (name != nil) {
    //        compare = [name caseInsensitiveCompare:child.wdName] == NSOrderedSame;
    //      }
    //      else if (value != nil) {
    //        NSString *childValue = child.wdValue;
    //        compare = [value caseInsensitiveCompare:childValue] == NSOrderedSame;
    //      }
    //      if (compare) {
    //        NSDictionary *rect = [child wdRect];
    //        CGFloat x = [[rect objectForKey:@"x"] doubleValue];
    //        CGFloat y = [[rect objectForKey:@"y"] doubleValue];
    ////        CGFloat width = [[rect objectForKey:@"width"] doubleValue];
    ////        CGFloat height = [[rect objectForKey:@"height"] doubleValue];
    //        CGPoint tapPoint = CGPointMake(x, y); //(x + (width + x)/2, y + (height + y)/2);
    //        XCUICoordinate *tapCoordinate = [self.class gestureCoordinateWithCoordinate:tapPoint application:request.session.application shouldApplyOrientationWorkaround:isSDKVersionLessThan(@"11.0")];
    //        [tapCoordinate tap];
    //        return FBResponseWithStatus(FBCommandStatusNoError, @{@"tapTime" : @([[NSDate date] timeIntervalSince1970])});
    ////        NSError *error;
    ////        if ([child fb_tapCoordinate:tapPoint error:&error]) {
    ////          return FBResponseWithStatus(FBCommandStatusNoError, @{@"tapTime" : @([[NSDate date] timeIntervalSince1970])});
    ////        }
    //      }
    //    }
  }
  return FBResponseWithErrorFormat(@"%@ not found or not enabled", queryValue);
}
@end
