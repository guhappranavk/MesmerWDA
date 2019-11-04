//
//  FBElementAttributeTransformer.m
//  WebDriverAgentLib
//
//  Created by Taha Samad on 10/31/19.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import "FBElementAttributeTransformer.h"
#import "FBConfiguration.h"
#import "FBLogger.h"

@implementation FBElementAttributeTransformer

static const NSString *anonymizedImageName = @"mesmer_anonymized_img.png";

+ (NSString *)anonymizeValuesInDescription:(NSString *)description
{
  if (![FBConfiguration shouldAnonymizeFullImagePaths])
  {
    return description;
  }
  
  NSArray* lines = [description componentsSeparatedByString:@"\n"];
  NSMutableArray* morphedLines = [NSMutableArray new];
 
  NSUInteger count = lines.count;
  for (NSUInteger i = 0; i < count; i += 1)
  {
    NSString *line = [lines objectAtIndex:i];
    NSString *modifiedLine = [self anonymizedValueInLine:line forAttribute:@"identifier"];
    [morphedLines addObject:modifiedLine];
  }
  return [morphedLines componentsJoinedByString:@"\n"];
}

+ (NSString *)anonymizedValueFor:(NSString *)value
{
  if ([FBConfiguration shouldAnonymizeFullImagePaths] && value.length > 0)
  {
    NSString *lowerCaseValue = [value lowercaseString];
    if ([value containsString:@"/Library/Developer/CoreSimulator/"] &&
        [value containsString:@"/data/Containers/Data/Application/"] &&
        ([lowerCaseValue containsString:@".png"] ||
         [lowerCaseValue containsString:@".jpeg"] ||
         [lowerCaseValue containsString:@".jpg"] ||
         [lowerCaseValue containsString:@".gif"]))
    {
      [FBLogger logFmt:@"Anonamizing Full Image Path Value :: %@", value];
      value = (NSString *)anonymizedImageName;
    }
  }
  
  return value;
}

#pragma mark - private

+ (NSString *)anonymizedValueInLine:(NSString *)line forAttribute:(NSString *)attributeName
{
  NSString *attrNameSeq = [NSString stringWithFormat:@", %@: ", attributeName];
  NSRange attrNameRange = [line rangeOfString:attrNameSeq];
  if(attrNameRange.location != NSNotFound)
  {
    NSUInteger attrStartingIndex = attrNameRange.location + 2;//skipping ", "
    NSUInteger startingQuoteIndex = NSNotFound;
    NSUInteger endingQuoteIndex = NSNotFound;
    
    NSUInteger i = 0, len = line.length;
    for (i = attrStartingIndex; i < len; i += 1)
    {
      unichar character = [line characterAtIndex:i];
      if (character == '\'')
      {
        if (startingQuoteIndex == NSNotFound)
        {
          startingQuoteIndex = i;
        }
        else if (endingQuoteIndex == NSNotFound)
        {
          NSUInteger nextIndex = i + 1;
          NSUInteger nextIndexPl1 = nextIndex + 1;
          if (nextIndexPl1 < len && [line characterAtIndex:nextIndex] == ',' && [line characterAtIndex:nextIndexPl1] == ' ')
          {
            endingQuoteIndex = i;
            break;
          }
          else if (nextIndex == len)
          {
            endingQuoteIndex = i;
            break;
          }
        }
      }
    }
    
    if (startingQuoteIndex != NSNotFound && endingQuoteIndex != NSNotFound)
    {
      NSString *value = [[line substringToIndex:endingQuoteIndex] substringFromIndex:startingQuoteIndex];
      if (value != nil && value.length > 0)
      {
        NSString *anonymizedValue = [self anonymizedValueFor:value];
        if (![value isEqualToString:anonymizedValue])
        {
          NSRange replaceStringRange = NSMakeRange(attrStartingIndex, (endingQuoteIndex - attrStartingIndex + 1));
          NSString *replaceableString = [line substringWithRange:replaceStringRange];
          NSString *replacementString = [NSString stringWithFormat:@"%@: '%@'", attributeName, anonymizedValue];
          line = [line stringByReplacingOccurrencesOfString:replaceableString withString:replacementString];
        }
      }
    }
  }
  return line;
}

@end
