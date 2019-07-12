//
//  BSWDataModelHandler.m
//  WebDriverAgentLib
//
//  Created by Suman Cherukuri on 6/28/19.
//  Copyright © 2019 Facebook. All rights reserved.
//

#import <Accelerate/Accelerate.h>

#import "BSWDataModelHandler.h"

#include <fstream>
#include <iostream>
#include <queue>

#include "tensorflow/lite/kernels/register.h"
#include "tensorflow/lite/model.h"
#include "tensorflow/lite/op_resolver.h"
#include "tensorflow/lite/string_util.h"
#if TFLITE_USE_GPU_DELEGATE
#include "tensorflow/lite/delegates/gpu/metal_delegate.h"
#endif

const int _wanted_input_width = 224;
const int _wanted_input_height = 224;
const int _wanted_input_channels = 3;
const float _input_mean = 127.5f;
const float _input_std = 127.5f;
const std::string _input_layer_name = "input";
const std::string _output_layer_name = "softmax1";

void PixelBufferReleaseCallback(void *releaseRefCon, const void *baseAddress) {
  free((void *)baseAddress);
}

// Preprocess the input image and feed the TFLite interpreter buffer for a float model.
void ProcessInputWithFloatModel(
                                uint8_t* input, float* buffer, int image_width, int image_height, int image_channels) {
  for (int y = 0; y < _wanted_input_height; ++y) {
    float* out_row = buffer + (y * _wanted_input_width * _wanted_input_channels);
    for (int x = 0; x < _wanted_input_width; ++x) {
      const int in_x = (y * image_width) / _wanted_input_width;
      const int in_y = (x * image_height) / _wanted_input_height;
      uint8_t* input_pixel =
      input + (in_y * image_width * image_channels) + (in_x * image_channels);
      float* out_pixel = out_row + (x * _wanted_input_channels);
      for (int c = 0; c < _wanted_input_channels; ++c) {
        out_pixel[c] = (input_pixel[c] - _input_mean) / _input_std;
      }
    }
  }
}

// Preprocess the input image and feed the TFLite interpreter buffer for a quantized model.
void ProcessInputWithQuantizedModel(
                                    uint8_t* input, uint8_t* output, int image_width, int image_height, int image_channels) {
  for (int y = 0; y < _wanted_input_height; ++y) {
    uint8_t* out_row = output + (y * _wanted_input_width * _wanted_input_channels);
    for (int x = 0; x < _wanted_input_width; ++x) {
      const int in_x = (y * image_width) / _wanted_input_width;
      const int in_y = (x * image_height) / _wanted_input_height;
      uint8_t* in_pixel = input + (in_y * image_width * image_channels) + (in_x * image_channels);
      uint8_t* out_pixel = out_row + (x * _wanted_input_channels);
      for (int c = 0; c < _wanted_input_channels; ++c) {
        out_pixel[c] = in_pixel[c];
      }
    }
  }
}

void GetTopN(
             const float* prediction, const int prediction_size, const int num_results,
             const float threshold, std::vector<std::pair<float, int> >* top_results) {
  // Will contain top N results in ascending order.
  std::priority_queue<std::pair<float, int>, std::vector<std::pair<float, int> >,
  std::greater<std::pair<float, int> > >
  top_result_pq;
  
  const long count = prediction_size;
  for (int i = 0; i < count; ++i) {
    const float value = prediction[i];
    // Only add it if it beats the threshold and has a chance at being in
    // the top N.
    if (value < threshold) {
      continue;
    }
    
    top_result_pq.push(std::pair<float, int>(value, i));
    
    // If at capacity, kick the smallest value out.
    if (top_result_pq.size() > num_results) {
      top_result_pq.pop();
    }
  }
  
  // Copy to output vector and reverse into descending order.
  while (!top_result_pq.empty()) {
    top_results->push_back(top_result_pq.top());
    top_result_pq.pop();
  }
  std::reverse(top_results->begin(), top_results->end());
}

@implementation BSWDataModelHandler {
  std::unique_ptr<tflite::FlatBufferModel> _model;
  tflite::ops::builtin::BuiltinOpResolver _resolver;
  std::unique_ptr<tflite::Interpreter> _interpreter;
  
  std::vector<std::string> _labels;
  TfLiteDelegate* _delegate;
  
  double _total_latency;
  int _total_count;
  
  NSMutableDictionary* _oldPredictionValues;
}

+ (BSWDataModelHandler *) sharedInstance {
  static BSWDataModelHandler *_sharedInstance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _sharedInstance = [[BSWDataModelHandler alloc] init];
  });
  return _sharedInstance;
}

- (BOOL)loadModel:(NSString *)modelFileName modelFileExtn:(NSString *)modelFileExtn labels:(NSString *)labelFileName labelsFileExtn:(NSString *)labelFileExtn {
  NSBundle *testBundle = [NSBundle bundleForClass:[self class]];
  NSString *modelFilePath = [testBundle pathForResource:modelFileName ofType:modelFileExtn];
  if (modelFilePath == nil) {
    NSLog(@"Coildn't find %@", modelFileName);
    return NO;
  }
  NSString* labelFilePath = [testBundle pathForResource:labelFileName ofType:labelFileExtn];
  if (labelFilePath == nil) {
    NSLog(@"Coildn't find %@", labelFileName);
    return NO;
  }
  
  _model = tflite::FlatBufferModel::BuildFromFile([modelFilePath UTF8String]);
  if (!_model) {
    NSLog(@"Failed to map model: %@", modelFilePath);
  }
  
  _model->error_reporter();
  
  std::ifstream t;
  t.open([labelFilePath UTF8String]);
  std::string line;
  while (t) {
    std::getline(t, line);
    _labels.push_back(line);
  }
  t.close();
    tflite::ops::builtin::BuiltinOpResolver resolver;
  tflite::InterpreterBuilder(*_model, resolver)(&_interpreter);

  int input = _interpreter->inputs()[0];
  std::vector<int> sizes = {1, 224, 224, 3};
  _interpreter->ResizeInputTensor(input, sizes);
  if (!_interpreter) {
    NSLog(@"Failed to construct interpreter");
  }
  if (_interpreter->AllocateTensors() != kTfLiteOk) {
    NSLog(@"Failed to allocate tensors!");
  }
  
  return YES;
}

- (NSDictionary *)runModelOnImage:(UIImage *)image {
  CVPixelBufferRef pixelBuffer = [self pixelBufferFromCGImage:[image CGImage]];
  OSType sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
  if (sourcePixelFormat != kCVPixelFormatType_32ARGB &&
      sourcePixelFormat != kCVPixelFormatType_32BGRA) {
    NSLog(@"Invalid pixel buffer");
    return nil;
  }
  
  // Crops the image to the biggest square in the center and scales it down to model dimensions.
  CGSize scaledSize = CGSizeMake(224, 224);
  CVPixelBufferRef thumbnailPixelBuffer = [self centerThumbnail:scaledSize pixelBuffer:pixelBuffer];
  if (thumbnailPixelBuffer == nil) {
    return nil;
  }
  
  UIImage *thumbnailImage = [self imageFromPixelBuffer:thumbnailPixelBuffer];
  
  CVPixelBufferRelease(thumbnailPixelBuffer);
  CVPixelBufferRelease(pixelBuffer);
  
  // Remove the alpha component from the image buffer to get the RGB data.
  NSData *rgbData = [self rgbDataFromImage:[thumbnailImage CGImage]];
  
  uint8_t* in = (uint8_t *)[rgbData bytes];
  
  int input = _interpreter->inputs()[0];
  TfLiteTensor *input_tensor = _interpreter->tensor(input);
  
  bool is_quantized;
  switch (input_tensor->type) {
    case kTfLiteFloat32:
      is_quantized = false;
      break;
    case kTfLiteUInt8:
      is_quantized = true;
      break;
    default:
      NSLog(@"Input data type is not supported by this demo app.");
      return nil;
  }
  
  const int image_channels = 4;
  if (image_channels < _wanted_input_channels) {
    NSLog(@"Invalid image_channels");
  }
  if (is_quantized) {
    uint8_t* out = _interpreter->typed_tensor<uint8_t>(input);
    ProcessInputWithQuantizedModel(in, out, thumbnailImage.size.width, thumbnailImage.size.height, 4);
  } else {
    float* out = _interpreter->typed_tensor<float>(input);
    ProcessInputWithFloatModel(in, out, thumbnailImage.size.width, thumbnailImage.size.height, 4);
  }
  
  double start = [[NSDate new] timeIntervalSince1970];
  if (_interpreter->Invoke() != kTfLiteOk) {
    NSLog(@"Failed to invoke!");
  }
  double end = [[NSDate new] timeIntervalSince1970];
  _total_latency += (end - start);
  _total_count += 1;
  NSLog(@"Time: %.4lf, avg: %.4lf, count: %d", end - start, _total_latency / _total_count,
        _total_count);
  
  // read output size from the output sensor
  const int output_tensor_index = _interpreter->outputs()[0];
  TfLiteTensor* output_tensor = _interpreter->tensor(output_tensor_index);
  TfLiteIntArray* output_dims = output_tensor->dims;
  if (output_dims->size != 2 || output_dims->data[0] != 1) {
    NSLog(@"Output of the model is in invalid format.");
  }
  const int output_size = output_dims->data[1];
  
  const int kNumResults = 5;
  const float kThreshold = 0.1f;
  
  std::vector<std::pair<float, int> > top_results;
  
  if (is_quantized) {
    uint8_t* quantized_output = _interpreter->typed_output_tensor<uint8_t>(0);
    int32_t zero_point = input_tensor->params.zero_point;
    float scale = input_tensor->params.scale;
    float output[output_size];
    for (int i = 0; i < output_size; ++i) {
      output[i] = (quantized_output[i] - zero_point) * scale;
    }
    GetTopN(output, output_size, kNumResults, kThreshold, &top_results);
  }
  else {
    float* output = _interpreter->typed_output_tensor<float>(0);
    GetTopN(output, output_size, kNumResults, kThreshold, &top_results);
  }
  
  NSMutableDictionary* newValues = [NSMutableDictionary dictionary];
  for (const auto& result : top_results) {
    const float confidence = result.first;
    const int index = result.second;
    NSString* labelObject = [NSString stringWithUTF8String:_labels[index].c_str()];
    NSNumber* valueObject = [NSNumber numberWithFloat:confidence];
    [newValues setObject:valueObject forKey:labelObject];
  }
//  dispatch_async(dispatch_get_main_queue(), ^(void) {
//    [self setPredictionValues:newValues];
//  });
  
  return newValues;
}

- (BOOL)runModelOnFrame:(CVPixelBufferRef)pixelBuffer {
  if (pixelBuffer == NULL) {
    NSLog(@"Invalid pixel buffer");
    return NO;
  }
  
  OSType sourcePixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
  if (sourcePixelFormat != kCVPixelFormatType_32ARGB &&
      sourcePixelFormat != kCVPixelFormatType_32BGRA) {
    NSLog(@"Invalid pixel buffer");
    return NO;
  }
  
  const int sourceRowBytes = (int)CVPixelBufferGetBytesPerRow(pixelBuffer);
  const int image_width = (int)CVPixelBufferGetWidth(pixelBuffer);
  const int fullHeight = (int)CVPixelBufferGetHeight(pixelBuffer);
  
  CVPixelBufferLockFlags unlockFlags = kNilOptions;
  CVPixelBufferLockBaseAddress(pixelBuffer, unlockFlags);
  
  unsigned char* sourceBaseAddr = (unsigned char*)(CVPixelBufferGetBaseAddress(pixelBuffer));
  int image_height;
  unsigned char* sourceStartAddr;
  if (fullHeight <= image_width) {
    image_height = fullHeight;
    sourceStartAddr = sourceBaseAddr;
  } else {
    image_height = image_width;
    const int marginY = ((fullHeight - image_width) / 2);
    sourceStartAddr = (sourceBaseAddr + (marginY * sourceRowBytes));
  }

  uint8_t* in = sourceStartAddr;
  
  int input = _interpreter->inputs()[0];
  TfLiteTensor *input_tensor = _interpreter->tensor(input);
  
  bool is_quantized;
  switch (input_tensor->type) {
    case kTfLiteFloat32:
      is_quantized = false;
      break;
    case kTfLiteUInt8:
      is_quantized = true;
      break;
    default:
      NSLog(@"Input data type is not supported by this demo app.");
      return NO;
  }
  
  const int image_channels = 4;
  if (image_channels < _wanted_input_channels) {
    NSLog(@"Invalid image_channels");
  }
  if (is_quantized) {
    uint8_t* out = _interpreter->typed_tensor<uint8_t>(input);
    ProcessInputWithQuantizedModel(in, out, image_width, image_height, image_channels);
  } else {
    float* out = _interpreter->typed_tensor<float>(input);
    ProcessInputWithFloatModel(in, out, image_width, image_height, image_channels);
  }
  
  double start = [[NSDate new] timeIntervalSince1970];
  if (_interpreter->Invoke() != kTfLiteOk) {
    NSLog(@"Failed to invoke!");
  }
  double end = [[NSDate new] timeIntervalSince1970];
  _total_latency += (end - start);
  _total_count += 1;
  NSLog(@"Time: %.4lf, avg: %.4lf, count: %d", end - start, _total_latency / _total_count,
        _total_count);
  
  // read output size from the output sensor
  const int output_tensor_index = _interpreter->outputs()[0];
  TfLiteTensor* output_tensor = _interpreter->tensor(output_tensor_index);
  TfLiteIntArray* output_dims = output_tensor->dims;
  if (output_dims->size != 2 || output_dims->data[0] != 1) {
    NSLog(@"Output of the model is in invalid format.");
  }
  const int output_size = output_dims->data[1];
  
  const int kNumResults = 5;
  const float kThreshold = 0.1f;
  
  std::vector<std::pair<float, int> > top_results;
  
  if (is_quantized) {
    uint8_t* quantized_output = _interpreter->typed_output_tensor<uint8_t>(0);
    int32_t zero_point = input_tensor->params.zero_point;
    float scale = input_tensor->params.scale;
    float output[output_size];
    for (int i = 0; i < output_size; ++i) {
      output[i] = (quantized_output[i] - zero_point) * scale;
    }
    GetTopN(output, output_size, kNumResults, kThreshold, &top_results);
  }
  else {
    float* output = _interpreter->typed_output_tensor<float>(0);
    GetTopN(output, output_size, kNumResults, kThreshold, &top_results);
  }
  
  NSMutableDictionary* newValues = [NSMutableDictionary dictionary];
  for (const auto& result : top_results) {
    const float confidence = result.first;
    const int index = result.second;
    NSString* labelObject = [NSString stringWithUTF8String:_labels[index].c_str()];
    NSNumber* valueObject = [NSNumber numberWithFloat:confidence];
    [newValues setObject:valueObject forKey:labelObject];
  }
  dispatch_async(dispatch_get_main_queue(), ^(void) {
    [self setPredictionValues:newValues];
  });
  
  CVPixelBufferUnlockBaseAddress(pixelBuffer, unlockFlags);
  CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
  return YES;
}

- (void)setPredictionValues:(NSDictionary*)newValues {
  const float decayValue = 0.75f;
  const float updateValue = 0.25f;
  const float minimumThreshold = 0.01f;
  
  NSMutableDictionary* decayedPredictionValues = [[NSMutableDictionary alloc] init];
  for (NSString* label in _oldPredictionValues) {
    NSNumber* oldPredictionValueObject = [_oldPredictionValues objectForKey:label];
    const float oldPredictionValue = [oldPredictionValueObject floatValue];
    const float decayedPredictionValue = (oldPredictionValue * decayValue);
    if (decayedPredictionValue > minimumThreshold) {
      NSNumber* decayedPredictionValueObject = [NSNumber numberWithFloat:decayedPredictionValue];
      [decayedPredictionValues setObject:decayedPredictionValueObject forKey:label];
    }
  }
  _oldPredictionValues = decayedPredictionValues;
  
  for (NSString* label in newValues) {
    NSNumber* newPredictionValueObject = [newValues objectForKey:label];
    NSNumber* oldPredictionValueObject = [_oldPredictionValues objectForKey:label];
    if (!oldPredictionValueObject) {
      oldPredictionValueObject = [NSNumber numberWithFloat:0.0f];
    }
    const float newPredictionValue = [newPredictionValueObject floatValue];
    const float oldPredictionValue = [oldPredictionValueObject floatValue];
    const float updatedPredictionValue = (oldPredictionValue + (newPredictionValue * updateValue));
    NSNumber* updatedPredictionValueObject = [NSNumber numberWithFloat:updatedPredictionValue];
    [_oldPredictionValues setObject:updatedPredictionValueObject forKey:label];
  }
  NSArray* candidateLabels = [NSMutableArray array];
  for (NSString* label in _oldPredictionValues) {
    NSNumber* oldPredictionValueObject = [_oldPredictionValues objectForKey:label];
    const float oldPredictionValue = [oldPredictionValueObject floatValue];
    if (oldPredictionValue > 0.05f) {
      NSDictionary* entry = @{@"label" : label, @"value" : oldPredictionValueObject};
      candidateLabels = [candidateLabels arrayByAddingObject:entry];
    }
  }
  NSSortDescriptor* sort = [NSSortDescriptor sortDescriptorWithKey:@"value" ascending:NO];
  NSArray* sortedLabels =
  [candidateLabels sortedArrayUsingDescriptors:[NSArray arrayWithObject:sort]];
  
//  const float leftMargin = 10.0f;
//  const float topMargin = 10.0f;
//
//  const float valueWidth = 48.0f;
//  const float valueHeight = 18.0f;
//
//  const float labelWidth = 246.0f;
//  const float labelHeight = 18.0f;
//
//  const float labelMarginX = 5.0f;
//  const float labelMarginY = 5.0f;
  
//  [self removeAllLabelLayers];
  
  int labelCount = 0;
  for (NSDictionary* entry in sortedLabels) {
    NSString* label = [entry objectForKey:@"label"];
    NSNumber* valueObject = [entry objectForKey:@"value"];
    const float value = [valueObject floatValue];
//    const float originY = topMargin + ((labelHeight + labelMarginY) * labelCount);
    const int valuePercentage = (int)roundf(value * 100.0f);
    
//    const float valueOriginX = leftMargin;
    NSString* valueText = [NSString stringWithFormat:@"%d%%", valuePercentage];
    NSLog(@"Value: %@, ValueText: %@", label, valueText);
    
//    [self addLabelLayerWithText:valueText
//                        originX:valueOriginX
//                        originY:originY
//                          width:valueWidth
//                         height:valueHeight
//                      alignment:kCAAlignmentRight];
    
//    const float labelOriginX = (leftMargin + valueWidth + labelMarginX);
    
//    [self addLabelLayerWithText:[label capitalizedString]
//                        originX:labelOriginX
//                        originY:originY
//                          width:labelWidth
//                         height:labelHeight
//                      alignment:kCAAlignmentLeft];
    
    labelCount += 1;
    if (labelCount > 4) {
      break;
    }
  }
}

- (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef)image {
  
  CGSize frameSize = CGSizeMake(CGImageGetWidth(image), CGImageGetHeight(image));
  NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys: [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey, [NSNumber numberWithBool:YES],kCVPixelBufferCGBitmapContextCompatibilityKey, nil];
  CVPixelBufferRef pxbuffer = NULL;
  
  CVReturn status = CVPixelBufferCreate(
                                        kCFAllocatorDefault, frameSize.width, frameSize.height,
                                        kCVPixelFormatType_32BGRA, (__bridge CFDictionaryRef)options,
                                        &pxbuffer);
  NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
  
  CVPixelBufferLockBaseAddress(pxbuffer, 0);
  void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
  
  CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = CGBitmapContextCreate(
                                               pxdata, frameSize.width, frameSize.height,
                                               8, CVPixelBufferGetBytesPerRow(pxbuffer),
                                               rgbColorSpace,
                                               (CGBitmapInfo)kCGBitmapByteOrder32Little |
                                               kCGImageAlphaPremultipliedFirst);
  
  CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                         CGImageGetHeight(image)), image);
  CGColorSpaceRelease(rgbColorSpace);
  CGContextRelease(context);
  
  CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
  
  return pxbuffer;
}

- (UIImage *)imageFromPixelBuffer:(CVPixelBufferRef)pixelBuffer {
  CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
  CIContext *context = [CIContext contextWithOptions:nil];
  CGImageRef myImage = [context createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer))];
  UIImage *image = [UIImage imageWithCGImage:myImage];
  
  CGImageRelease(myImage);
  
  return image;
}

- (CVPixelBufferRef) centerThumbnail:(CGSize)size pixelBuffer:(CVPixelBufferRef)pixelBuffer {
  CGFloat imageWidth = CVPixelBufferGetWidth(pixelBuffer);
  CGFloat imageHeight = CVPixelBufferGetHeight(pixelBuffer);
  OSType pixelBufferType = CVPixelBufferGetPixelFormatType(pixelBuffer);
  
  size_t inputImageRowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer);
  size_t imageChannels = 4;
  
  size_t thumbnailSize = MIN(imageWidth, imageHeight);
  CVPixelBufferLockBaseAddress(pixelBuffer, kNilOptions);
  
  int originX = 0;
  int originY = 0;
  
  if (imageWidth > imageHeight) {
    originX = (imageWidth - imageHeight) / 2;
  }
  else {
    originY = (imageHeight - imageWidth) / 2;
  }

  unsigned char* inputBaseAddress = (unsigned char*)(CVPixelBufferGetBaseAddress(pixelBuffer));
  inputBaseAddress += originY * inputImageRowBytes + originX * imageChannels;
  
  // Gets vImage Buffer from input image
  vImage_Buffer inputVImageBuffer = {
    .data = (void *)inputBaseAddress,
    .height = thumbnailSize,
    .width = thumbnailSize,
    .rowBytes = inputImageRowBytes
  };
  
  int thumbnailRowBytes = size.width * imageChannels;
  unsigned char *thumbnailBytes = (unsigned char *)malloc(size.height * thumbnailRowBytes);
  
  // Allocates a vImage buffer for thumbnail image.
  vImage_Buffer thumbnailVImageBuffer = {
    .data = (void *)thumbnailBytes,
    .height = (size_t)size.height,
    .width = (size_t)size.width,
    .rowBytes = (size_t)thumbnailRowBytes
  };
  
  // Performs the scale operation on input image buffer and stores it in thumbnail image buffer.
  vImage_Error scaleError = vImageScale_ARGB8888(&inputVImageBuffer, &thumbnailVImageBuffer, nil, vImage_Flags(0));
  
  CVPixelBufferUnlockBaseAddress(pixelBuffer, kNilOptions);
  
  if (scaleError != kvImageNoError) {
    return nil;
  }
  
  CVPixelBufferRef thumbnailPixelBuffer;
  
  // Converts the thumbnail vImage buffer to CVPixelBuffer
  CVReturn conversionStatus = CVPixelBufferCreateWithBytes(nil, (size_t)size.width, (size_t)size.height, pixelBufferType, thumbnailBytes, thumbnailRowBytes, PixelBufferReleaseCallback, nil, nil, &thumbnailPixelBuffer);
  
  if (conversionStatus != kCVReturnSuccess) {
    free(thumbnailBytes);
    return nil;
  }
  
  return thumbnailPixelBuffer;
}

- (NSData *) rgbDataFromImage:(CGImageRef)image {
  CGContextRef context = CGBitmapContextCreate(nil, CGImageGetWidth(image), CGImageGetHeight(image), 8, CGImageGetWidth(image) * 4, CGColorSpaceCreateDeviceRGB(), kCGImageAlphaNoneSkipFirst);
  
  CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                         CGImageGetHeight(image)), image);
  
  unsigned char *imageData = (unsigned char *)CGBitmapContextGetData(context);
  NSMutableArray *array = [[NSMutableArray alloc] init];
  for (int row = 0; row < 224; row++) {
    for (int col = 0; col < 224; col++) {
      long offset = 4 * (col * CGBitmapContextGetWidth(context) + row);
      // (Ignore offset 0, the unused alpha channel)
      int red = (int)imageData[offset+1];
      int green = (int)imageData[offset+2];
      int blue = (int)imageData[offset+3];
      
      // Normalize channel values to [0.0, 1.0]. This requirement varies
      // by model. For example, some models might require values to be
      // normalized to the range [-1.0, 1.0] instead, and others might
      // require fixed-point values or the original bytes.
      int normalizedRed = Float32(red) / 255.0;
      int normalizedGreen = Float32(green) / 255.0;
      int normalizedBlue = Float32(blue) / 255.0;
      
      [array addObject:@(normalizedRed)];
      [array addObject:@(normalizedGreen)];
      [array addObject:@(normalizedBlue)];
      
      //            [array addObject:@(red)];
      //            [array addObject:@(green)];
      //            [array addObject:@(blue)];
      
    }
  }
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:array];
  
  return data;
}

@end
