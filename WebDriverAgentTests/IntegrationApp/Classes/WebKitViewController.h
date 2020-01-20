//
//  WebKitViewController.h
//  WebDriverAgentLib
//
//  Created by Guhappranav Karthikeyan on 17/01/20.
//  Copyright © 2020 Facebook. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

@interface WebKitViewController : UIViewController

@property(nonatomic, unsafe_unretained) IBOutlet WKWebView *webView;

@end
