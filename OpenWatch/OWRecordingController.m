//
//  OWRecordingController.m
//  OpenWatch
//
//  Created by Christopher Ballinger on 11/13/12.
//  Copyright (c) 2012 OpenWatch FPC. All rights reserved.
//

#import "OWRecordingController.h"
#import "OWRecording.h"
#import "OWCaptureAPIClient.h"

@interface OWRecordingController()
@property (nonatomic, strong) NSMutableDictionary *recordings;
@end

@implementation OWRecordingController
@synthesize recordings;

+ (OWRecordingController *)sharedInstance {
    static OWRecordingController *_sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedClient = [[OWRecordingController alloc] init];
    });
    return _sharedClient;
}

- (id) init {
    if (self = [super init]) {
        self.recordings = [NSMutableDictionary dictionary];
        [self scanDirectoryForChanges];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self scanRecordingsForUnsubmittedData];
        });
    }
    return self;
}

- (void) scanRecordingsForUnsubmittedData {
    for (OWRecording *recording in [self allRecordings]) {
        if (recording.failedFileUploadCount > 0) {
            NSLog(@"Unsubmitted data found for recording: %@", recording.recordingPath);
            [self uploadFailedFileURLs:recording.failedFileUploadURLs forRecording:recording];
        }
    }
}

- (void) uploadFailedFileURLs:(NSArray*)failedFileURLs forRecording:(OWRecording*)recording {
    for (NSURL *url in failedFileURLs) {
        [[OWCaptureAPIClient sharedClient] uploadFileURL:url recording:recording priority:NSOperationQueuePriorityVeryLow];
    }
}

- (void) addRecording:(OWRecording *)recording {
    if (!recording) {
        NSLog(@"Recording is nil!");
        return;
    }
    [recordings setObject:recording forKey:recording.recordingPath];
}

- (void) removeRecording:(OWRecording *)recording {
    [recordings removeObjectForKey:recording.recordingPath];
    NSError *error = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:recording.recordingPath error:&error];
    if (error) {
        NSLog(@"Error removing recording: %@%@", [error localizedDescription], [error userInfo]);
        error = nil;
    }
}

- (NSArray*) allRecordings {
    return [recordings allValues];
}

- (void) scanDirectoryForChanges {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSError *error = nil;
    NSArray *recordingFileNames = [fileManager contentsOfDirectoryAtPath:basePath error:&error];
    if (error) {
        NSLog(@"Error loading directory of recordings: %@%@", [error localizedDescription], [error userInfo]);
        error = nil;
    }
    
    NSArray *currentRecordings = [self allRecordings];
    
    for (OWRecording *recording in currentRecordings) {
        if (![fileManager fileExistsAtPath:recording.recordingPath]) {
            NSLog(@"Recording no longer exists, removing: %@", recording.recordingPath);
            [recordings removeObjectForKey:recording.recordingPath];
        }
    }
    
    for (NSString *recordingFileName in recordingFileNames) {
        if ([recordingFileName rangeOfString:@"recording"].location != NSNotFound) {
            NSString *recordingPath = [basePath stringByAppendingPathComponent:recordingFileName];
            if (![recordings objectForKey:recordingPath]) {
                OWRecording *recording = [[OWRecording alloc] initWithRecordingPath:recordingPath];
                [self addRecording:recording];
            }
        }
    }
}

@end
