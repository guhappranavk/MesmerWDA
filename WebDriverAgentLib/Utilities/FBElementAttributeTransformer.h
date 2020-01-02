//
//  FBElementAttributeTransformer.h
//  WebDriverAgentLib
//
//  Created by Taha Samad on 10/31/19.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FBElementAttributeTransformer : NSObject

+ (NSString *)anonymizeValuesInDescription:(NSString *)description;
+ (NSString *)anonymizedValueFor:(NSString *)value;

@end

NS_ASSUME_NONNULL_END
