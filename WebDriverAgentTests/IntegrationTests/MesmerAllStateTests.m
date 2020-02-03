//
//  MesmerAllStateTests.m
//  IntegrationTests_1
//
//  Created by Guhappranav Karthikeyan on 23/01/20.
//  Copyright © 2020 Facebook. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "FBIntegrationTestCase.h"

@interface MesmerAllStateTests : FBIntegrationTestCase

@property (nonatomic, strong) XCUIApplication *allStateApp;

@end

@implementation MesmerAllStateTests

- (void)setUp {
//  self.allStateApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.mesmer.AllstateMobileApp"];
//  [self.allStateApp launch];
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)test_logout {
  [self do_login];
  
  XCUIElement *welcome_message = self.allStateApp.staticTexts[@"What can we help with today?"];
  [welcome_message waitForExistenceWithTimeout:60.0f];
    
  NSArray *imagesList = [self.allStateApp.images allElementsBoundByIndex];
  XCUIElement *bread_crumb = imagesList[0];
  [bread_crumb tap];
  
  XCUIElement *logoutBtn = self.allStateApp.buttons[@"Log Out"];
  [logoutBtn tap];
    
  XCUIElement *alert = self.allStateApp.alerts[@"Do you enjoy Allstate℠ Mobile - DEV?"];
  BOOL is_visible = [alert waitForExistenceWithTimeout:10.0f];
  if (is_visible) {
    XCUIElement *alert_no_btn = self.allStateApp.buttons[@"No"];
    [alert_no_btn tap];
    
    XCUIElement *cancel_btn = self.allStateApp.buttons[@"Cancel"];
    [cancel_btn tap];
  }
  
  [self do_login];
  
  [welcome_message waitForExistenceWithTimeout:60.0f];
  
}

- (void)do_login {
  XCUIElement *userName = self.allStateApp.textFields[@"User ID"];
//  BOOL retrun_val = [userName waitForExistenceWithTimeout:15.0f];
  [userName tap];
  
  if ([userName value]) {
    [self.allStateApp.buttons[@"Clear text"] tap];
  }
  
  [userName typeText:@"u_703935"];
  
  XCUIElement *password = self.allStateApp.secureTextFields[@"Password"];
  [password tap];
  [password typeText:@"Password1"];
  
  XCUIElement *loginBtn = self.allStateApp.buttons[@"LOG IN"];
  [loginBtn tap];

}

- (void)test_ring_orientation {
  XCUIApplication *ringApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.mesmer.ring"];
  [ringApp launch];
  
  XCUIElement *loginBtn = ringApp.buttons[@"LOG IN"];
  BOOL retrun_val = [loginBtn waitForExistenceWithTimeout:5.0f];
  if (retrun_val) {
    [loginBtn tap];
    
    XCUIElement *userName = ringApp.textFields[@"Email Address"];
    retrun_val = [userName waitForExistenceWithTimeout:15.0f];
    [userName tap];
    
    [userName typeText:@"ring@mesmerhq.com"];
    
    XCUIElement *password = ringApp.secureTextFields[@"Password"];
    [password tap];
    [password typeText:@"P@ss2020"];
    
    loginBtn = ringApp.buttons[@"LOG IN"];
    [loginBtn tap];
  }
  
  XCUIElement *homescreen_cell = ringApp.cells[@"dashboard.neighborhood.view"];
  retrun_val = [homescreen_cell waitForExistenceWithTimeout:30.0f];
  
  if (retrun_val) {
    XCUIElement *cell = ringApp.cells[@"Front Door cell"];
    [cell tap];
    
    XCUIElement *fullScreen_btn = ringApp.buttons[@"player.button.fullscreen"];
    [fullScreen_btn tap];
    
    XCUIElement *stream_btn = ringApp.buttons[@"button.start.stream"];
    [stream_btn tap];

    XCUIElement *endCall_btn = ringApp.buttons[@"button.end.call"];
    retrun_val = [endCall_btn waitForExistenceWithTimeout:30.0f];
    if (retrun_val)
      [endCall_btn tap];

    [fullScreen_btn tap];

    [fullScreen_btn tap];
    [fullScreen_btn tap];
    [fullScreen_btn tap];
    
  }
}


@end
