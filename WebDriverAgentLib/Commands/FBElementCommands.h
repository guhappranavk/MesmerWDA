/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#import <WebDriverAgentLib/FBCommandHandler.h>
#import <WebDriverAgentLib/FBApplication.h>

@interface FBElementCommands : NSObject <FBCommandHandler>

+ (void)drag:(CGPoint)startPoint endPoint:(CGPoint)endPoint duration:(double)duration;
+ (void)drag2:(CGPoint)startPoint endPoint:(CGPoint)endPoint duration:(double)duration velocity:(double)velocity;
+ (id)find:(XCUIApplication *)application type:(NSString *)type query:(NSString *)query queryValue:(NSString *)queryValue;
+ (id<FBResponsePayload>)findAndTap:(XCUIApplication *)application type:(NSString *)type query:(NSString *)query queryValue:(NSString *)queryValue useButtonTap:(BOOL)useButtonTap;
+ (void)tapCoordinate:(XCUIApplication *)application tapPoint:(CGPoint)tapPoint;

@end

