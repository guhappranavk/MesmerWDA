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
    // Put setup code here. This method is called before the invocation of each test method in the class.
    
    // In UI tests it is usually best to stop immediately when a failure occurs.
    

    // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
  self.allStateApp = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.mesmer.AllstateMobileApp"];
  [self.allStateApp launch];
    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
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
  BOOL retrun_val = [userName waitForExistenceWithTimeout:15.0f];
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

@end
