//
//  BFTaskCompletionSource+Expire.m
//  Umwho
//
//  Created by Felix Dumit on 3/29/15.
//  Copyright (c) 2015 Umwho. All rights reserved.
//

#import "BFTask+Result.h"
#import "BFTask+Timeout.h"
#import "BFTaskCompletionSource+Task.h"
#import <objc/runtime.h>

NSInteger const kBFTimeoutError = 80175555;

@interface NSError (BFCancel)

+(NSError*)boltsTimeoutError;

@end

// Keys for the new ivars
static void *timeoutKey;
static void *timeoutTaskIdKey;

@implementation BFTaskCompletionSource (Timeout)

// Accessors for the new ivars

- (void)setTimeoutTaskId:(NSString *)value {
    objc_setAssociatedObject(self,
                             &timeoutTaskIdKey,
                             value,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)timeoutTaskId {
    return objc_getAssociatedObject(self, &timeoutTaskIdKey);
}

- (void)setTimeoutValue:(NSNumber *)value {
    objc_setAssociatedObject(self,
                             &timeoutKey,
                             value,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSNumber *)timeoutValue {
    return objc_getAssociatedObject(self, &timeoutKey);
}

+ (instancetype)taskCompletionSourceWithExpiration:(NSTimeInterval)timeout {
    BFTaskCompletionSource *taskCompletion = [self taskCompletionSource];
    taskCompletion.timeoutValue = @(timeout);
    
    // No easy way to cancel task so we'll just keep track of the current timeout task
    NSString *taskId = [[NSUUID UUID] UUIDString];
    taskCompletion.timeoutTaskId = taskId;
    [[BFTask taskWithDelay:timeout * 1000] continueWithBlock:^id _Nullable(BFTask * _Nonnull t) {
        if ([taskCompletion.timeoutTaskId isEqualToString:taskId])
            [taskCompletion trySetTimedOut];
        return nil;
    }];

    return taskCompletion;
}

-(void)setTimedOut {
    [self setError:[NSError boltsTimeoutError]];
}

-(void)trySetTimedOut {
    [self trySetError:[NSError boltsTimeoutError]];
}

- (void)resetTimeout {
    // Do nothing if completed
    if (self.task.completed) return;
    // Start new timeout task
    NSString *taskId = [[NSUUID UUID] UUIDString];
    self.timeoutTaskId = taskId;
    [[BFTask taskWithDelay:self.timeoutValue.doubleValue * 1000] continueWithBlock:^id _Nullable(BFTask * _Nonnull t) {
        if ([self.timeoutTaskId isEqualToString:taskId])
            [self trySetTimedOut];
        return nil;
    }];
}

@end


@implementation BFTask (Timeout)

- (instancetype)setTimeout:(NSTimeInterval)timeout {
    return [self _continueTaskWithTimeout:timeout];
}

- (BFTask *)_continueTaskWithTimeout:(NSTimeInterval)timeout {
    BFTaskCompletionSource *tcs = [BFTaskCompletionSource taskCompletionSourceWithExpiration:timeout];
    [tcs setResultBasedOnTask:self];
    return tcs.task;
}

-(BOOL)hasTimedOut {
    return [self.error isTimeoutError];
}

+(BFTask *)timedOutTask {
    return [BFTask taskWithError:[NSError boltsTimeoutError]];
}

@end


@implementation NSError (BFCancel)

+(NSError *)boltsTimeoutError {
    NSDictionary* userInfo = @{ NSLocalizedDescriptionKey: NSLocalizedString(@"The task timed out", nil) };
    return [NSError errorWithDomain:BFTaskErrorDomain code:kBFTimeoutError userInfo:userInfo];
}

@end

@implementation NSError (TimeoutError)

-(BOOL)isTimeoutError {
    NSError* timeoutError = [NSError boltsTimeoutError];
    return [self.domain isEqualToString:timeoutError.domain] && self.code == timeoutError.code;
}

@end
