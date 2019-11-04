//
//  FBElementAttributeTransformerTests.m
//  WebDriverAgentRunner
//
//  Created by Taha Samad on 10/31/19.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <WebDriverAgentLib/WebDriverAgentLib.h>

@interface FBElementAttributeTransformerTests : XCTestCase

@end

@implementation FBElementAttributeTransformerTests

- (void)setUp {
  [FBConfiguration setShouldAnonymizeFullImagePaths:YES];
}

- (void)tearDown {
}

- (void)testDescription {
  NSString *desc = @"Cell, 0x6000035d7e20, {{336.0, 212.0}, {296.0, 165.0}}, identifier: 'SBAUICarouselCell-1'\nOther, 0x6000035d7d40, {{336.0, 212.0}, {296.0, 165.0}}\nButton, 0x6000035d7c60, {{336.0, 212.0}, {296.0, 165.0}}, identifier: '/Users/taha.samad/Library/Developer/CoreSimulator/Devices/FDA7FE17-4847-4291-93F3-5A65121A6DFC/data/Containers/Data/Application/29CF97FC-AC46-45D4-AA23-0DB9A803CE42/Library/Caches/Images/-7757036882996523168.png', label: 'Each visit gets you closer to free food and drinks'";
  NSString *updatedDesc = [FBElementAttributeTransformer anonymizeValuesInDescription:desc];
  
  NSLog(@"Original Desc:\n%@", desc);
  NSLog(@"Updated Desc:\n%@", updatedDesc);
}

@end
