/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBDebugCommands.h"

#import "FBApplication.h"
#import "FBRouteRequest.h"
#import "FBSession.h"
#import "XCUIApplication+FBHelpers.h"
#import "XCUIElement+FBUtilities.h"
#import "FBXPath.h"

@implementation FBDebugCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute GET:@"/sourceAppium"] respondWithTarget:self action:@selector(handleGetSourceCommandAppium:)],
    [[FBRoute GET:@"/sourceAppium"].withoutSession respondWithTarget:self action:@selector(handleGetSourceCommandAppium:)],
    [[FBRoute GET:@"/source"] respondWithTarget:self action:@selector(handleGetSourceCommand:)],
    [[FBRoute GET:@"/source"].withoutSession respondWithTarget:self action:@selector(handleGetSourceCommand:)],
    [[FBRoute GET:@"/attr/:attributes/source"].withoutSession respondWithTarget:self action:@selector(handleGetSourceCommand:)],
    [[FBRoute GET:@"/attr/:attributes/format/:sourceType/source"].withoutSession respondWithTarget:self action:@selector(handleGetSourceCommand:)],
    [[FBRoute GET:@"/wda/accessibleSource"] respondWithTarget:self action:@selector(handleGetAccessibleSourceCommand:)],
    [[FBRoute GET:@"/wda/accessibleSource"].withoutSession respondWithTarget:self action:@selector(handleGetAccessibleSourceCommand:)],
  ];
}


#pragma mark - Commands

static NSString *const SOURCE_FORMAT_XML = @"xml";
static NSString *const SOURCE_FORMAT_JSON = @"json";
static NSString *const SOURCE_FORMAT_DESCRIPTION = @"description";

+ (id<FBResponsePayload>)handleGetSourceCommandAppium:(FBRouteRequest *)request
{
  FBApplication *application = request.session.activeApplication ?: [FBApplication fb_activeApplication];
  NSString *sourceType = request.parameters[@"format"] ?: SOURCE_FORMAT_XML;
  id result;
  if ([sourceType caseInsensitiveCompare:SOURCE_FORMAT_XML] == NSOrderedSame) {
    result = application.fb_xmlRepresentation;
  } else if ([sourceType caseInsensitiveCompare:SOURCE_FORMAT_JSON] == NSOrderedSame) {
    result = application.fb_tree;
  } else if ([sourceType caseInsensitiveCompare:SOURCE_FORMAT_DESCRIPTION] == NSOrderedSame) {
    result = application.fb_descriptionRepresentation;
  } else {
    return FBResponseWithStatus(
                                FBCommandStatusUnsupported,
                                [NSString stringWithFormat:@"Unknown source format '%@'. Only %@ source formats are supported.",
                                 sourceType, @[SOURCE_FORMAT_XML, SOURCE_FORMAT_JSON, SOURCE_FORMAT_DESCRIPTION]]
                                );
  }
  if (nil == result) {
    return FBResponseWithErrorFormat(@"Cannot get '%@' source of the current application", sourceType);
  }
  return FBResponseWithObject(result);
}

+ (id<FBResponsePayload>)handleGetSourceCommand:(FBRouteRequest *)request
{
  FBApplication *application = request.session.activeApplication ?: [FBApplication fb_activeApplication];
  
//  if ([application.bundleID caseInsensitiveCompare:@"com.apple.mobilesafari"] == NSOrderedSame) {
//    CGRect frame = application.fb_lastSnapshot.frame;
//    NSString *ret = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<XCUIElementTypeApplication type=\"XCUIElementTypeApplication\" class=\"UIApplication\" name=\"Safari\" label=\"Safari\" enabled=\"true\" hasFocus=\"false\" x=\"0\" y=\"0\" width=\"%.0f\" height=\"%.0f\">\n</XCUIElementTypeApplication>", frame.size.width, frame.size.height];
//    return FBResponseWithObject(ret);
//  }
  
  NSString *attributes = request.parameters[@"attributes"];
  if (attributes != nil) {
    attributes = [attributes stringByReplacingOccurrencesOfString:@":" withString:@" @"];
    attributes = [NSString stringWithFormat:@" @%@ ", attributes];
  }
  NSString *maxCells = request.parameters[@"maxcells"];
  NSInteger maxCellsToReturn = -1;
  if (maxCells != nil) {
    maxCellsToReturn = [maxCells integerValue];
  }

  NSString *sourceType = request.parameters[@"format"] ?: SOURCE_FORMAT_XML;
  id result;
  if ([sourceType caseInsensitiveCompare:SOURCE_FORMAT_XML] == NSOrderedSame) {
    [application fb_waitUntilSnapshotIsStable];
    result = [FBXPath xmlStringWithSnapshot:application.fb_lastSnapshot query:attributes maxCells:maxCellsToReturn];
  } else if ([sourceType caseInsensitiveCompare:SOURCE_FORMAT_JSON] == NSOrderedSame) {
    result = application.fb_tree;
  } else if ([sourceType caseInsensitiveCompare:SOURCE_FORMAT_DESCRIPTION] == NSOrderedSame) {
    result = application.fb_descriptionRepresentation;
  } else {
    return FBResponseWithStatus(
      FBCommandStatusUnsupported,
      [NSString stringWithFormat:@"Unknown source format '%@'. Only %@ source formats are supported.",
       sourceType, @[SOURCE_FORMAT_XML, SOURCE_FORMAT_JSON, SOURCE_FORMAT_DESCRIPTION]]
    );
  }
  if (nil == result) {
    return FBResponseWithErrorFormat(@"Cannot get '%@' source of the current application", sourceType);
  }
  return FBResponseWithObject(result);
}

+ (id<FBResponsePayload>)handleGetAccessibleSourceCommand:(FBRouteRequest *)request
{
  FBApplication *application = request.session.activeApplication;
  return FBResponseWithObject(application.fb_accessibilityTree ?: @{});
}

@end
