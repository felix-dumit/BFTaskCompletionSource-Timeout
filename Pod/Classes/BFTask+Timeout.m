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

NSInteger const kBFTimeoutError = 80175555;

@interface NSError (BFCancel)

+(NSError*)boltsTimeoutError;

@end

@interface BFTaskCompletionSource (Timeout)

@property (nonatomic) BFTaskCompletionSource *timeoutTaskCompletion;
@property NSTimeInterval timeout;

@end

@implementation BFTaskCompletionSource (Timeout)

+ (instancetype)taskCompletionSourceWithExpiration:(NSTimeInterval)timeout {
    BFTaskCompletionSource *taskCompletion = [self taskCompletionSource];
    taskCompletion.timeout = timeout;
    taskCompletion.timeoutTaskCompletion = [BFTaskCompletionSource taskCompletionSource];
    [[taskCompletion.timeoutTaskCompletion.task setTimeout:timeout * 1000] continueWithBlock:^id _Nullable(BFTask * _Nonnull t) {
        if (!t.isCancelled)
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
    // Cancel previous task
    [self.timeoutTaskCompletion trySetCancelled];
    // Start new one
    self.timeoutTaskCompletion = [BFTaskCompletionSource taskCompletionSource];
    [[self.timeoutTaskCompletion.task setTimeout:self.timeout * 1000] continueWithBlock:^id _Nullable(BFTask * _Nonnull t) {
        if (!t.isCancelled)
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
