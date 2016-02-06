//
//  AudioPlayerManager.m
//  AudioPlayerManager
//
//  Created by Joshua Sierles on 15/04/15.
//  Copyright (c) 2015 Joshua Sierles. All rights reserved.
//

#import "AudioPlayerManager.h"
#import "RCTConvert.h"
#import "RCTBridge.h"
#import "RCTEventDispatcher.h"
#import <AVFoundation/AVFoundation.h>

NSString *const AudioPlayerEventProgress = @"playerProgress";
NSString *const AudioPlayerEventFinished = @"playerFinished";

@implementation AudioPlayerManager {

  AVAudioPlayer *_audioPlayer;

  NSTimeInterval _currentTime;
  id _progressUpdateTimer;
  int _progressUpdateInterval;
  NSDate *_prevProgressUpdateTime;
  NSURL *_audioFileURL;
}

@synthesize bridge = _bridge;

RCT_EXPORT_MODULE();

- (void)sendProgressUpdate {
  if (_audioPlayer && _audioPlayer.playing) {
    _currentTime = _audioPlayer.currentTime;
  }

  // If audioplayer stopped, reset current time to 0
//  if (_audioPlayer && !_audioPlayer.playing) {
//    _currentTime = 0;
//  }


  if ((_prevProgressUpdateTime == nil ||
   (([_prevProgressUpdateTime timeIntervalSinceNow] * -1000.0) >= _progressUpdateInterval)) && _audioPlayer.playing) {

      [_bridge.eventDispatcher sendDeviceEventWithName:AudioPlayerEventProgress body:@{
      @"currentTime": [NSNumber numberWithFloat:_currentTime]
    }];
    _prevProgressUpdateTime = [NSDate date];
  }
}

- (void)stopProgressTimer {
  [_progressUpdateTimer invalidate];
}

- (void)startProgressTimer {
  _progressUpdateInterval = 150;
  _prevProgressUpdateTime = nil;

  [self stopProgressTimer];

  _progressUpdateTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(sendProgressUpdate)];
  [_progressUpdateTimer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)recorder successfully:(BOOL)flag {
  
  //Stop progress when finished...
  if (_audioPlayer.playing) {
    [_audioPlayer stop];
  }
  [self stopProgressTimer];
  [self sendProgressUpdate];
  
  [_bridge.eventDispatcher sendDeviceEventWithName:AudioPlayerEventFinished body:@{
      @"finished": flag ? @"true" : @"false"
    }];
}

- (NSString *) applicationDocumentsDirectory
{
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
  return basePath;
}

RCT_EXPORT_METHOD(play:(NSString *)path time:(NSTimeInterval) time)
{
  NSError * err;
  AVAudioSession *playbackSession = [AVAudioSession sharedInstance];
  [playbackSession setCategory:AVAudioSessionCategoryPlayback error:&err];

  NSError *error;

  NSString *audioFilePath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:path];

  _audioFileURL = [NSURL fileURLWithPath:audioFilePath];

  _audioPlayer = [[AVAudioPlayer alloc]
    initWithContentsOfURL:_audioFileURL

    error:&error];
  _audioPlayer.delegate = self;

  if (error) {
    [self stopProgressTimer];
    NSLog(@"audio playback loading error: %@", [error localizedDescription]);
    // TODO: dispatch error over the bridge
  } else {
    [_audioPlayer prepareToPlay];
    [self startProgressTimer];
    [_audioPlayer setCurrentTime: time];
    if (![_audioPlayer play]) {
      NSLog(@"Could not play audio");
    };
  }
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player
                                 error:(NSError *)error
{
  NSLog(@"audioPlayerDecodeErrorDidOccur %@", error.localizedDescription);
}

RCT_EXPORT_METHOD(playWithUrl:(NSURL *) url)
{
  NSError *error;
  NSData* data = [NSData dataWithContentsOfURL: url];

  _audioPlayer = [[AVAudioPlayer alloc] initWithData:data  error:&error];
  _audioPlayer.delegate = self;
  if (error) {
    [self stopProgressTimer];
    NSLog(@"audio playback loading error: %@", [error localizedDescription]);
    // TODO: dispatch error over the bridge
  } else {
    [self startProgressTimer];
    [_audioPlayer play];
  }
}

RCT_EXPORT_METHOD(pause)
{
  if (_audioPlayer.playing) {
    [_audioPlayer pause];
  }
}

RCT_EXPORT_METHOD(unpause)
{
  if (!_audioPlayer.playing) {
    [_audioPlayer play];
  }
}

RCT_EXPORT_METHOD(stop)
{
  if (_audioPlayer.playing) {
    [_audioPlayer stop];
    [self stopProgressTimer];
    [self sendProgressUpdate];
  }
}

RCT_EXPORT_METHOD(setCurrentTime:(NSTimeInterval) time)
{
  if (_audioPlayer.playing) {
     [_audioPlayer setCurrentTime: time];
  }
}

RCT_EXPORT_METHOD(getDuration:(RCTResponseSenderBlock)callback)
{
  NSTimeInterval duration = _audioPlayer.duration;
  callback(@[[NSNull null], [NSNumber numberWithDouble:duration]]);
}

@end
