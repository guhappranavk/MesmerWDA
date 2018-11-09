//
//  BSSystemInfo.h
//  WebDriverAgentLib
//
//  Created by Suman Cherukuri on 11/8/18.
//  Copyright © 2018 Bytesized. All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import <Foundation/Foundation.h>
#include <mach/mach.h>

NSDictionary *cpuUsage(void);
NSDictionary *memoryUsage(void);
NSDictionary* diskUsage(void);
float batteryLevel(void);
NSDictionary *systemInfo(void);
