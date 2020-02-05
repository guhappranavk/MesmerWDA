//
//  HomeViewController.m
//  IntegrationApp
//
//  Created by Guhappranav Karthikeyan on 05/02/20.
//  Copyright © 2020 Facebook. All rights reserved.
//

#import "HomeViewController.h"

@interface HomeViewController ()

@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  [self.inputView resignFirstResponder];
}


@end
