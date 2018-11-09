//
//  BSSystemInfo.m
//  WebDriverAgentLib
//
//  Created by Suman Cherukuri on 11/8/18.
//  Copyright © 2018 Bytesized. All rights reserved.
//
// This source code is licensed under the BSD-style license found in the
// LICENSE file in the root directory of this source tree. An additional grant
// of patent rights can be found in the PATENTS file in the same directory.
//

#import "BSSystemInfo.h"
#import <UIKit/UIKit.h>

//typedef struct {
//  unsigned int system;
//  unsigned int user;
//  unsigned int nice;
//  unsigned int idle;
//} CPUUsage;

//
double systemCpu(void) {
  kern_return_t kr;
  mach_msg_type_number_t count;
  static host_cpu_load_info_data_t previous_info = {0, 0, 0, 0};
  host_cpu_load_info_data_t info;
  
  //  CPUUsage usage = {0, 0, 0, 1};
  count = HOST_CPU_LOAD_INFO_COUNT;
  
  kr = host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&info, &count);
  if (kr != KERN_SUCCESS) {
    return 0;
  }
  
  natural_t user   = info.cpu_ticks[CPU_STATE_USER] - previous_info.cpu_ticks[CPU_STATE_USER];
  natural_t nice   = info.cpu_ticks[CPU_STATE_NICE] - previous_info.cpu_ticks[CPU_STATE_NICE];
  natural_t system = info.cpu_ticks[CPU_STATE_SYSTEM] - previous_info.cpu_ticks[CPU_STATE_SYSTEM];
  natural_t idle   = info.cpu_ticks[CPU_STATE_IDLE] - previous_info.cpu_ticks[CPU_STATE_IDLE];
  natural_t total  = user + nice + system + idle;
  previous_info    = info;
  
  //  usage.user = user;
  //  usage.system = system;
  //  usage.nice = nice;
  //  usage.idle = idle;
  return (user + nice + system) * 100.0 / total;
  //  return usage;
}

//
double agentCpu(void) {
  kern_return_t kr;
  task_info_data_t tinfo;
  mach_msg_type_number_t task_info_count;
  
  task_info_count = TASK_INFO_MAX;
  kr = task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)tinfo, &task_info_count);
  if (kr != KERN_SUCCESS) {
    return -1;
  }
  
  thread_array_t         thread_list;
  mach_msg_type_number_t thread_count;
  
  thread_info_data_t     thinfo;
  mach_msg_type_number_t thread_info_count;
  
  thread_basic_info_t basic_info_th;
  
  // get threads in the task
  kr = task_threads(mach_task_self(), &thread_list, &thread_count);
  if (kr != KERN_SUCCESS) {
    return -1;
  }
  
  long total_time     = 0;
  long total_userTime = 0;
  double total_cpu   = 0;
  int j;
  
  // for each thread
  for (j = 0; j < (int)thread_count; j++) {
    thread_info_count = THREAD_INFO_MAX;
    kr = thread_info(thread_list[j], THREAD_BASIC_INFO,
                     (thread_info_t)thinfo, &thread_info_count);
    if (kr != KERN_SUCCESS) {
      return -1;
    }
    
    basic_info_th = (thread_basic_info_t)thinfo;
    
    if (!(basic_info_th->flags & TH_FLAGS_IDLE)) {
      total_time     = total_time + basic_info_th->user_time.seconds + basic_info_th->system_time.seconds;
      total_userTime = total_userTime + basic_info_th->user_time.microseconds + basic_info_th->system_time.microseconds;
      total_cpu = total_cpu + basic_info_th->cpu_usage / (float)TH_USAGE_SCALE * 100;
    }
  }
  
  kr = vm_deallocate(mach_task_self(), (vm_offset_t)thread_list, thread_count * sizeof(thread_t));
  if (kr != KERN_SUCCESS) {
    return -1;
  }
  return total_cpu;
}

//
vm_size_t agentMemory(void) {
  struct task_basic_info info;
  mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
  kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
  return (kerr == KERN_SUCCESS) ? info.resident_size : 0;
}

//
typedef struct {
  vm_size_t system;
  vm_size_t free;
} MemoryStats;

MemoryStats systemMemory(void) {
  mach_port_t host_port = mach_host_self();
  mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
  vm_size_t pagesize;
  vm_statistics_data_t vm_stat;
  
  host_page_size(host_port, &pagesize);
  (void) host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
  MemoryStats memStats = {(vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count) * pagesize,
    vm_stat.free_count * pagesize
  };
  return memStats;
}

//
NSDictionary* diskUsage(void) {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSDictionary *dictionary = [[NSFileManager defaultManager] attributesOfFileSystemForPath:(id)[paths lastObject] error:nil];
  
  if (dictionary) {
    NSNumber *fileSystemSizeInBytes = [dictionary objectForKey: NSFileSystemSize];
    NSNumber *freeFileSystemSizeInBytes = [dictionary objectForKey:NSFileSystemFreeSize];
    unsigned long long total = [fileSystemSizeInBytes unsignedLongLongValue];
    unsigned long long free = [freeFileSystemSizeInBytes unsignedLongLongValue];
    return @{@"used" : @(total - free), @"free" : @(free)};
  }
  return @{@"used" : @(0), @"free" : @(0)};
}

//
float batteryLevel(void) {
  [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
  float level = [[UIDevice currentDevice] batteryLevel];
  level = level < 0 ? 1.0 : level;
  return level * 100;
}

NSDictionary *cpuUsage(void) {
  return @{@"agent": @(agentCpu()), @"other" : @(systemCpu())};
}

NSDictionary *memoryUsage(void) {
  MemoryStats memStats = systemMemory();
  return @{@"agent": @(agentMemory()), @"other" : @(memStats.system), @"free" : @(memStats.free)};
}

NSDictionary *systemInfo(void) {
  return @{@"cpu" : cpuUsage(),
           @"mem" : memoryUsage(),
           @"disk" : diskUsage(),
           @"battery" : @(batteryLevel()),
           };
}
