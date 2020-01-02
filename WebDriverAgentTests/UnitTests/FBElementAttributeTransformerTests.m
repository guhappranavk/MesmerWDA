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
  
  //This runs only on Xcode 10.x Simulators.
  NSLog(@"Testing setShouldAnonymizeFullImagePaths");
  
  NSString *desc = @"Cell, 0x6000035d7e20, {{336.0, 212.0}, {296.0, 165.0}}, identifier: 'SBAUICarouselCell-1'\nOther, 0x6000035d7d40, {{336.0, 212.0}, {296.0, 165.0}}\nButton, 0x6000035d7c60, {{336.0, 212.0}, {296.0, 165.0}}, identifier: '/Users/JohnDoe/Library/Developer/CoreSimulator/Devices/SOMEDEVICE-4847-4291-93F3-5A65121A6DFC/data/Containers/Data/Application/SOMEAPP-AC46-45D4-AA23-0DB9A803CE42/Library/Caches/Images/SomeImage.png', label: 'This is a Test'";
  NSString *updatedDesc = [FBElementAttributeTransformer anonymizeValuesInDescription:desc];
  
  NSString *expectedDesc = @"Cell, 0x6000035d7e20, {{336.0, 212.0}, {296.0, 165.0}}, identifier: 'SBAUICarouselCell-1'\nOther, 0x6000035d7d40, {{336.0, 212.0}, {296.0, 165.0}}\nButton, 0x6000035d7c60, {{336.0, 212.0}, {296.0, 165.0}}, identifier: 'mesmer_anonymized_img.png', label: 'This is a Test'";
  
  XCTAssertTrue([updatedDesc isEqualToString:expectedDesc]);
}

@end
