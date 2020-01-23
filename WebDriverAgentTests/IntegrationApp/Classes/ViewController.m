/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ViewController.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *orentationLabel;
@end

@implementation ViewController

- (void)viewWillAppear:(BOOL)animated {
  [[UIDevice currentDevice] setValue:[NSNumber numberWithInt:UIDeviceOrientationPortrait] forKey:@"orientation"];
}

- (IBAction)deadlockApp:(id)sender
{
  dispatch_sync(dispatch_get_main_queue(), ^{
    // This will never execute
  });
}

- (IBAction)didTapButton:(UIButton *)button
{
  button.selected = !button.selected;
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  [self updateOrentationLabel];
}

- (void)updateOrentationLabel
{
  NSString *orientation = nil;
  switch (self.interfaceOrientation) {
    case UIInterfaceOrientationPortrait:
      orientation = @"Portrait";
      break;
    case UIInterfaceOrientationPortraitUpsideDown:
      orientation = @"PortraitUpsideDown";
      break;
    case UIInterfaceOrientationLandscapeLeft:
      orientation = @"LandscapeLeft";
      break;
    case UIInterfaceOrientationLandscapeRight:
      orientation = @"LandscapeRight";
      break;
    case UIInterfaceOrientationUnknown:
      orientation = @"Unknown";
      break;
  }
  self.orentationLabel.text = [NSString stringWithFormat:@"CURRENT ORIENTATION: %@", orientation];
}

- (IBAction)textEditingDidEnd:(UITextField *)sender {
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Password Content" message:[sender text] preferredStyle:UIAlertControllerStyleAlert];
  [alert addAction:[UIAlertAction actionWithTitle:@"Okay" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
    [alert dismissViewControllerAnimated:YES completion:nil];
  }]];
  [self presentViewController:alert animated:YES completion:nil];
}

@end
