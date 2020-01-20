//
//  WebKitViewController.m
//  WebDriverAgentLib
//
//  Created by Guhappranav Karthikeyan on 17/01/20.
//  Copyright © 2020 Facebook. All rights reserved.
//

#import "WebKitViewController.h"

@interface WebKitViewController ()

@end

@implementation WebKitViewController

- (void)viewDidLoad {
    [super viewDidLoad];
  [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://id.atlassian.com/login"]]];
    // Do any additional setup after loading the view.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
