//
//  LKLog.h
//  LaunchKit
//
//  Created by Rizwan Sattar on 1/20/15.
//
//

#import <Foundation/Foundation.h>

extern BOOL LKLOG_ENABLED;

extern void LKLog(NSString *format, ...);
extern void LKLogWarning(NSString *format, ...);
extern void LKLogError(NSString *format, ...);

/*
#ifdef LAUNCHKIT_DEBUG
#define LKLog(...) LKLogFormat(nil, __VA_ARGS__)
#else
#define LKLog(...)
#endif


#ifdef LAUNCHKIT_WARN
#define LKLogWarning(...) LKLogFormat(@"warn", __VA_ARGS__)
#else
#define LKLogWarning(...)
#endif


#ifdef LAUNCHKIT_ERROR
#define LKLogError(...) LKLogFormat(@"error", __VA_ARGS__)
#else
#define LKLogError(...)
#endif

#endif
*/