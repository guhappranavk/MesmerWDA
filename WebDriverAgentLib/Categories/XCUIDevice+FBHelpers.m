/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "XCUIDevice+FBHelpers.h"

#import <arpa/inet.h>
#import <ifaddrs.h>
#include <notify.h>
#import <objc/runtime.h>

#import "FBSpringboardApplication.h"
#import "FBErrorBuilder.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "FBXCodeCompatibility.h"

#import "XCUIDevice.h"
#import "XCUIScreen.h"
#import "XCAXClient_iOS.h"

static const NSTimeInterval FBHomeButtonCoolOffTime = 1.;
static const NSTimeInterval FBScreenLockTimeout = 5.;

@implementation XCUIDevice (FBHelpers)

static bool fb_isLocked;

+ (void)load
{
  [self fb_registerAppforDetectLockState];
}

+ (void)fb_registerAppforDetectLockState
{
  int notify_token;
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wstrict-prototypes"
  notify_register_dispatch("com.apple.springboard.lockstate", &notify_token, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^(int token) {
    uint64_t state = UINT64_MAX;
    notify_get_state(token, &state);
    fb_isLocked = state != 0;
  });
  #pragma clang diagnostic pop
}

- (BOOL)fb_goToHomescreenWithError:(NSError **)error
{
  [self pressButton:XCUIDeviceButtonHome];
  // This is terrible workaround to the fact that pressButton:XCUIDeviceButtonHome is not a synchronous action.
  // On 9.2 some first queries  will trigger additional "go to home" event
  // So if we don't wait here it will be interpreted as double home button gesture and go to application switcher instead.
  // On 9.3 pressButton:XCUIDeviceButtonHome can be slightly delayed.
  // Causing waitUntilApplicationBoardIsVisible not to work properly in some edge cases e.g. like starting session right after this call, while being on home screen
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:FBHomeButtonCoolOffTime]];
//  if (![[FBSpringboardApplication fb_springboard] fb_waitUntilApplicationBoardIsVisible:error]) {
//    return NO;
//  }
  return YES;
}

- (BOOL)fb_lockScreen:(NSError **)error
{
  if (fb_isLocked) {
    return YES;
  }
  [self pressLockButton];
  return [[[[FBRunLoopSpinner new]
            timeout:FBScreenLockTimeout]
           timeoutErrorMessage:@"Timed out while waiting until the screen gets locked"]
          spinUntilTrue:^BOOL{
            return fb_isLocked;
          } error:error];
}

- (BOOL)fb_isScreenLocked
{
  return fb_isLocked;
}

- (BOOL)fb_unlockScreen:(NSError **)error
{
  if (!fb_isLocked) {
    return YES;
  }
  [self pressButton:XCUIDeviceButtonHome];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:FBHomeButtonCoolOffTime]];
  if (SYSTEM_VERSION_LESS_THAN(@"10.0")) {
    [[FBApplication fb_activeApplication] swipeRight];
  } else {
    [self pressButton:XCUIDeviceButtonHome];
  }
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:FBHomeButtonCoolOffTime]];
  return [[[[FBRunLoopSpinner new]
            timeout:FBScreenLockTimeout]
           timeoutErrorMessage:@"Timed out while waiting until the screen gets unlocked"]
          spinUntilTrue:^BOOL{
            return !fb_isLocked;
          } error:error];
}

- (NSData *)fb_screenshotWithError:(NSError*__autoreleasing*)error
{
  FBApplication *activeApplication = FBApplication.fb_activeApplication;
  UIInterfaceOrientation orientation = activeApplication.interfaceOrientation;
  CGSize screenSize = FBAdjustDimensionsForApplication(activeApplication.frame.size, orientation);
  CGRect screenRect = CGRectMake(0, 0, screenSize.width, screenSize.height);
  // https://developer.apple.com/documentation/xctest/xctimagequality?language=objc
  // Select lower quality, since XCTest crashes randomly if the maximum quality (zero value) is selected
  // and the resulting screenshot does not fit the memory buffer preallocated for it by the operating system
  NSData *imageData = [self fb_rawScreenshotWithQuality:1 rect:screenRect error:error];
  if (nil == imageData) {
    return nil;
  }
  return FBAdjustScreenshotOrientationForApplication(imageData, orientation);
}

- (NSData *)fb_screenshotHighWithError:(NSError*__autoreleasing*)error width:(CGFloat)width height:(CGFloat)height
{
  Class xcScreenClass = objc_lookUpClass("XCUIScreen");
  if (nil == xcScreenClass) {
    NSData *result = [[XCAXClient_iOS sharedClient] screenshotData];
    if (nil == result) {
      if (error) {
        *error = [[FBErrorBuilder.builder withDescription:@"Cannot take a screenshot of the current screen state"] build];
      }
      return nil;
    }
    return result;
  }
  
  //  XCUIApplication *app = FBApplication.fb_activeApplication;
  //  CGSize screenSize = FBAdjustDimensionsForApplication(app.frame.size, app.interfaceOrientation);
  //  NSUInteger quality = 0;
  //  CGRect screenRect = CGRectMake(0, 0, screenSize.width, screenSize.height);
  //
  XCUIScreen *mainScreen = (XCUIScreen *)[xcScreenClass mainScreen];
  //  return [mainScreen screenshotDataForQuality:quality rect:screenRect error:error];
  
  XCUIScreenshot *screenshot = [mainScreen screenshot];
  
  UIImage *screenImage = [screenshot image];

  if (width <= 0.0 || height <= 0.0) {
    if (screenImage.size.height > screenImage.size.width) {
          return UIImagePNGRepresentation(screenImage);
    }
  }
  width = width <= 0.0 ? screenImage.size.width : width/[UIScreen mainScreen].nativeScale;
  height = height <= 0.0 ? screenImage.size.height : height/[UIScreen mainScreen].nativeScale;
  UIImage *scaledImage = [self scaleToSize:screenImage size:CGSizeMake(width, height)];
  return UIImagePNGRepresentation(scaledImage);
}

- (UIImage *)fb_screenshotImageWithError:(NSError*__autoreleasing*)error
{

  Class xcScreenClass = objc_lookUpClass("XCUIScreen");
  if (nil == xcScreenClass) {
    XCUIScreenshot *screenshotResult = [[XCAXClient_iOS sharedClient] screenshot];
    
    if (nil == screenshotResult) {
      if (error) {
        *error = [[FBErrorBuilder.builder withDescription:@"Cannot take a screenshot of the current screen state"] build];
      }
      return nil;
    }
    UIImage *screenImage = [screenshotResult image];
    if (screenImage.size.height <= 1.0) {
      return nil;
    }
    return screenImage;
  }

  XCUIScreen *mainScreen = (XCUIScreen* )[xcScreenClass mainScreen];
  
  @try {
    XCUIScreenshot *screenshot = [mainScreen screenshot];
    UIImage *screenImage = [screenshot image];
    if (screenImage.size.height <= 1.0) {
      return nil;
    }
    return screenImage;
  }
  @catch (NSException *exception) {
    NSLog(@"failed to get screenshot: %@", exception);
  }
  return nil;
}

- (NSData *)fb_screenshotHighWithError:(NSError*__autoreleasing*)error quality:(double)quality type:(NSString *)type
{
  Class xcScreenClass = objc_lookUpClass("XCUIScreen");
  if (nil == xcScreenClass) {
    NSData *result = [[XCAXClient_iOS sharedClient] screenshotData];
    if (nil == result) {
      if (error) {
        *error = [[FBErrorBuilder.builder withDescription:@"Cannot take a screenshot of the current screen state"] build];
      }
      return nil;
    }
    return result;
  }
  
  //  XCUIApplication *app = FBApplication.fb_activeApplication;
  //  CGSize screenSize = FBAdjustDimensionsForApplication(app.frame.size, app.interfaceOrientation);
  //  NSUInteger quality = 0;
  //  CGRect screenRect = CGRectMake(0, 0, screenSize.width, screenSize.height);
  //
  XCUIScreen *mainScreen = (XCUIScreen *)[xcScreenClass mainScreen];
  //  return [mainScreen screenshotDataForQuality:quality rect:screenRect error:error];
  
  NSData *result = nil;
  
  @try {
    XCUIScreenshot *screenshot = [mainScreen screenshot];
    if (type == nil || [type caseInsensitiveCompare:@"jpeg"] == NSOrderedSame) {
      UIImage *screenImage = [screenshot image];
      if (screenImage.size.height <= 1.0) {
        return nil;
      }
      result = UIImageJPEGRepresentation(screenImage, (CGFloat)quality);
    }
    else {
      result = [screenshot PNGRepresentation];
    }
  }
  @catch (NSException *exception) {
    NSLog(@"failed to get screenshot: %@", exception);
  }
  return result;
}

- (NSData *)fb_rawScreenshotWithQuality:(NSUInteger)quality rect:(CGRect)rect error:(NSError*__autoreleasing*)error
{
  NSData *imageData = [XCUIScreen.mainScreen screenshotDataForQuality:quality rect:rect error:error];
  if (nil == imageData) {
    return nil;
  }
  return imageData;
}

- (BOOL)fb_fingerTouchShouldMatch:(BOOL)shouldMatch
{
  const char *name;
  if (shouldMatch) {
    name = "com.apple.BiometricKit_Sim.fingerTouch.match";
  } else {
    name = "com.apple.BiometricKit_Sim.fingerTouch.nomatch";
  }
  return notify_post(name) == NOTIFY_STATUS_OK;
}

- (UIImage*)rotateInNeeded:(UIImage *)image {
  CGSize size = image.size;
  UIImageOrientation orientation = image.imageOrientation;
  
  if (size.width > size.height && orientation != UIImageOrientationUp) {
    // new devices are not properly orienting the image
    // rotate it
    CGFloat degrees = 0.0f;
    if (orientation == UIImageOrientationLeft) {
      degrees = -90;
    }
    else if (orientation == UIImageOrientationRight) {
      degrees = 90;
    }
    
    CGAffineTransform t = CGAffineTransformMakeRotation(degrees * M_PI / 180);
    CGRect originalImageRect = CGRectMake(0, 0, image.size.width, image.size.height);
    CGRect rotatedImageRect = CGRectApplyAffineTransform(originalImageRect, t);
    CGSize rotatedSize = rotatedImageRect.size;
    UIGraphicsBeginImageContext(rotatedSize);
    
    CGContextRef bitmap = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(bitmap, rotatedSize.width/2, rotatedSize.height/2);
    
    CGContextRotateCTM(bitmap, degrees * M_PI / 180);
    CGContextScaleCTM(bitmap, 1.0, -1.0);
    
    CGContextDrawImage(bitmap, CGRectMake(-image.size.width / 2, -image.size.height / 2, image.size.width, image.size.height), [image CGImage]);
    
    UIImage *rotatedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return rotatedImage;
  }
  return image;
}

- (UIImage *)scaleToSize:(UIImage *)image size:(CGSize)size {
  UIGraphicsBeginImageContextWithOptions(size, false, [UIScreen mainScreen].nativeScale);
  [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
  UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();
  return newImage;
}

- (NSString *)fb_usbIPAddress
{
  NSString *ip = [self fb_usbIPAddressInternal];
  static int i = 0;
  while (ip == nil) {
    NSLog(@"#### trying to get usb interface: %d", ++i);
    [NSThread sleepForTimeInterval:1];
    ip = [self fb_usbIPAddressInternal];
  }
  i = 0;
  return ip;
}

- (NSString *)fb_usbIPAddressInternal {
  struct ifaddrs *interfaces = NULL;
  struct ifaddrs *temp_addr = NULL;
  int success = getifaddrs(&interfaces);
  if (success != 0) {
    freeifaddrs(interfaces);
    return nil;
  }

  NSString *address = nil;
  temp_addr = interfaces;
  while(temp_addr != NULL) {
    if(temp_addr->ifa_addr->sa_family != AF_INET) {
      temp_addr = temp_addr->ifa_next;
      continue;
    }
    NSString *interfaceName = [NSString stringWithUTF8String:temp_addr->ifa_name];
    if(![interfaceName containsString:@"en"] || [interfaceName containsString:@"en0"]) { //ignore wi-fi interface
      temp_addr = temp_addr->ifa_next;
      continue;
    }
    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
    break;
  }
  freeifaddrs(interfaces);
  return address;
}

- (NSString *)fb_wifiIPAddress {
  struct ifaddrs *interfaces = NULL;
  struct ifaddrs *temp_addr = NULL;
  int success = getifaddrs(&interfaces);
  if (success != 0) {
    freeifaddrs(interfaces);
    return nil;
  }

  NSString *address = nil;
  temp_addr = interfaces;
  while(temp_addr != NULL) {
    if(temp_addr->ifa_addr->sa_family != AF_INET) {
      temp_addr = temp_addr->ifa_next;
      continue;
    }
    NSString *interfaceName = [NSString stringWithUTF8String:temp_addr->ifa_name];
    if(![interfaceName containsString:@"en0"]) {
      temp_addr = temp_addr->ifa_next;
      continue;
    }
    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
    break;
  }
  freeifaddrs(interfaces);
  return address;
}

- (BOOL)fb_openUrl:(NSString *)url error:(NSError **)error
{
  NSURL *parsedUrl = [NSURL URLWithString:url];
  if (nil == parsedUrl) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"'%@' is not a valid URL", url]
            buildError:error];
  }
  
  id siriService = [self valueForKey:@"siriService"];
  if (nil != siriService) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [siriService performSelector:NSSelectorFromString(@"activateWithVoiceRecognitionText:")
                      withObject:[NSString stringWithFormat:@"Open {%@}", url]];
#pragma clang diagnostic pop
    return YES;
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  // The link never gets opened by this method: https://forums.developer.apple.com/thread/25355
  if (![[UIApplication sharedApplication] openURL:parsedUrl]) {
#pragma clang diagnostic pop
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"The URL %@ cannot be opened", url]
            buildError:error];
  }
  return YES;
}

- (BOOL)fb_pressButton:(NSString *)buttonName error:(NSError **)error
{
  NSMutableArray<NSString *> *supportedButtonNames = [NSMutableArray array];
  XCUIDeviceButton dstButton = 0;
  if ([buttonName.lowercaseString isEqualToString:@"home"]) {
    dstButton = XCUIDeviceButtonHome;
  }
  [supportedButtonNames addObject:@"home"];
#if !TARGET_OS_SIMULATOR
  if ([buttonName.lowercaseString isEqualToString:@"volumeup"]) {
    dstButton = XCUIDeviceButtonVolumeUp;
  }
  if ([buttonName.lowercaseString isEqualToString:@"volumedown"]) {
    dstButton = XCUIDeviceButtonVolumeDown;
  }
  [supportedButtonNames addObject:@"volumeUp"];
  [supportedButtonNames addObject:@"volumeDown"];
#endif
  if (dstButton == 0) {
    return [[[FBErrorBuilder builder]
             withDescriptionFormat:@"The button '%@' is unknown. Only the following button names are supported: %@", buttonName, supportedButtonNames]
            buildError:error];
  }
  [self pressButton:dstButton];
  return YES;
}

@end
