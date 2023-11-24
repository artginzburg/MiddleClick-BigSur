#import "Controller.h"
#import "PreferenceKeys.h"
#include "TrayMenu.h"
#import <Cocoa/Cocoa.h>
#include <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#include <math.h>
#include <unistd.h>

#pragma mark Multitouch API

typedef struct {
  float x, y;
} mtPoint;
typedef struct {
  mtPoint pos, vel;
} mtReadout;

typedef struct {
  int frame;
  double timestamp;
  int identifier, state, foo3, foo4;
  mtReadout normalized;
  float size;
  int zero1;
  float angle, majorAxis, minorAxis; // ellipsoid
  mtReadout mm;
  int zero2[2];
  float unk2;
} Finger;

typedef void* MTDeviceRef;
typedef int (*MTContactCallbackFunction)(int, Finger*, int, double, int);
MTDeviceRef MTDeviceCreateDefault(void);
CFMutableArrayRef MTDeviceCreateList(void);
void MTDeviceRelease(MTDeviceRef);
void MTRegisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
void MTUnregisterContactFrameCallback(MTDeviceRef, MTContactCallbackFunction);
void MTDeviceStart(MTDeviceRef, int); // thanks comex
void MTDeviceStop(MTDeviceRef);

#pragma mark Globals

NSDate* touchStartTime;
float middleclickX, middleclickY;
float middleclickX2, middleclickY2;

BOOL needToClick;
long fingersQua;
BOOL threeDown;
BOOL maybeMiddleClick;
BOOL wasThreeDown;
NSMutableArray* currentDeviceList;
CFMachPortRef currentEventTap;
CFRunLoopSourceRef currentRunLoopSource;

#pragma mark Implementation

@implementation Controller {
  NSTimer* _restartTimer __weak; // Using `weak` so that the pointer is automatically set to `nil` when the referenced object is released ( https://en.wikipedia.org/wiki/Automatic_Reference_Counting#Zeroing_Weak_References ). This helps preventing fatal EXC_BAD_ACCESS.
}

- (void)start
{
  NSLog(@"Starting all listeners...");

  threeDown = NO;
  wasThreeDown = NO;
  
  fingersQua = [[NSUserDefaults standardUserDefaults] integerForKey:kFingersNum];
  
  NSString* needToClickNullable = [[NSUserDefaults standardUserDefaults] valueForKey:@"needClick"];
  needToClick = needToClickNullable ? [[NSUserDefaults standardUserDefaults] boolForKey:@"needClick"] : [self getIsSystemTapToClickDisabled];
  
  NSAutoreleasePool* pool = [NSAutoreleasePool new];
  [NSApplication sharedApplication];
  
  registerTouchCallback();
  
  // register a callback to know when osx come back from sleep
  [[[NSWorkspace sharedWorkspace] notificationCenter]
   addObserver:self
   selector:@selector(receiveWakeNote:)
   name:NSWorkspaceDidWakeNotification
   object:NULL];
  
  // Register IOService notifications for added devices.
  IONotificationPortRef port = IONotificationPortCreate(kIOMasterPortDefault);
  CFRunLoopAddSource(CFRunLoopGetMain(),
                     IONotificationPortGetRunLoopSource(port),
                     kCFRunLoopDefaultMode);
  io_iterator_t handle;
  kern_return_t err = IOServiceAddMatchingNotification(
                                                       port, kIOFirstMatchNotification,
                                                       IOServiceMatching("AppleMultitouchDevice"), multitouchDeviceAddedCallback,
                                                       self, &handle);
  if (err) {
    NSLog(@"Failed to register notification for touchpad attach: %xd, will not "
          @"handle newly "
          @"attached devices",
          err);
    IONotificationPortDestroy(port);
  } else {
    io_object_t item;
    while ((item = IOIteratorNext(handle))) {
      IOObjectRelease(item);
    }
  }
  
  // when displays are reconfigured restart of the app is needed, so add a calback to the
  // reconifguration of Core Graphics
  CGDisplayRegisterReconfigurationCallback(displayReconfigurationCallBack, self);
  
  [self registerMouseCallback:pool];
}

static void stopUnstableListeners(void)
{
    NSLog(@"Stopping unstable listeners...");

    unregisterTouchCallback();
    unregisterMouseCallback();
}

- (void)startUnstableListeners
{
  NSLog(@"Starting unstable listeners...");
    
  NSAutoreleasePool* pool = [NSAutoreleasePool new];

  registerTouchCallback();
  [self registerMouseCallback:pool];
}

static void registerTouchCallback(void)
{
    /// Get list of all multi touch devices
    NSMutableArray* deviceList = (NSMutableArray*)MTDeviceCreateList(); // grab our device list
    currentDeviceList = deviceList;

    // Iterate and register callbacks for multitouch devices.
    for (int i = 0; i < [deviceList count]; i++) // iterate available devices
    {
      registerMTDeviceCallback((MTDeviceRef)[deviceList objectAtIndex:i], touchCallback);
    }
}
static void unregisterTouchCallback(void)
{
    /// Get list of all multi touch devices
    NSMutableArray* deviceList = currentDeviceList; // grab our device list

    // Iterate and unregister callbacks for multitouch devices.
    for (int i = 0; i < [deviceList count]; i++) // iterate available devices
    {
      unregisterMTDeviceCallback((MTDeviceRef)[deviceList objectAtIndex:i], touchCallback);
    }
}

- (void)registerMouseCallback:(NSAutoreleasePool*)pool
{
    /// we only want to see left mouse down and left mouse up, because we only want
    /// to change that one
    CGEventMask eventMask = (CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventLeftMouseUp));

    /// create eventTap which listens for core grpahic events with the filter
    /// specified above (so left mouse down and up again)
    CFMachPortRef eventTap = CGEventTapCreate(
                                              kCGHIDEventTap, kCGHeadInsertEventTap, kCGEventTapOptionListenOnly,
                                              eventMask, mouseCallback, NULL);
    currentEventTap = eventTap;

    if (eventTap) {
        // Add to the current run loop.
        CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
        currentRunLoopSource = runLoopSource;
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource,
                           kCFRunLoopCommonModes);

        // Enable the event tap.
        CGEventTapEnable(eventTap, true);

        // release pool before exit
        [pool release];
    } else {
        NSLog(@"Couldn't create event tap! Check accessibility permissions.");
        [[NSUserDefaults standardUserDefaults] setBool:1 forKey:@"NSStatusItem Visible Item-0"];
        [self scheduleRestart:5];
    }
}
static void unregisterMouseCallback(void)
{
    // Remove from the current run loop.
    if (currentRunLoopSource) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), currentRunLoopSource, kCFRunLoopCommonModes);
    }
    // Disable the event tap.
    if (currentEventTap) {
        CGEventTapEnable(currentEventTap, false);
    }
}

/// Schedule listeners to be restarted, if a restart is pending, delay it.
- (void)scheduleRestart:(NSTimeInterval)delay
{
  if (_restartTimer != nil) { // Check whether the timer object was not released.
    [_restartTimer invalidate]; // Invalidate any existing timer.
  }
  
  _restartTimer = [NSTimer scheduledTimerWithTimeInterval:delay
                                                  repeats:NO
                                                    block:^(NSTimer* timer) {
                                                      [self restartListeners];
                                                    }];
}

/// Callback for system wake up. This restarts the app to initialize callbacks.
/// Can be tested by entering `pmset sleepnow` in the Terminal
- (void)receiveWakeNote:(NSNotification*)note
{
  NSLog(@"System woke up, restarting...");
  [self scheduleRestart:10];
}

- (BOOL)getClickMode
{
  return needToClick;
}

- (void)setMode:(BOOL)click
{
  [[NSUserDefaults standardUserDefaults] setBool:click forKey:@"needClick"];
  needToClick = click;
}
- (void)resetClickMode
{
  [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"needClick"];
  needToClick = [self getIsSystemTapToClickDisabled];
}

/// listening to mouse clicks to replace them with middle clicks if there are 3
/// fingers down at the time of clicking this is done by replacing the left click
/// down with a other click down and setting the button number to middle click
/// when 3 fingers are down when clicking, and by replacing left click up with
/// other click up and setting three button number to middle click when 3 fingers
/// were down when the last click went down.
CGEventRef mouseCallback(CGEventTapProxy proxy, CGEventType type,
                         CGEventRef event, void* refcon)
{
  if (needToClick) {
    if (threeDown && type == kCGEventLeftMouseDown) {
      wasThreeDown = YES;
      CGEventSetType(event, kCGEventOtherMouseDown);
      CGEventSetIntegerValueField(event, kCGMouseEventButtonNumber,
                                  kCGMouseButtonCenter);
      threeDown = NO;
    }
    
    if (wasThreeDown && type == kCGEventLeftMouseUp) {
      wasThreeDown = NO;
      CGEventSetType(event, kCGEventOtherMouseUp);
      CGEventSetIntegerValueField(event, kCGMouseEventButtonNumber,
                                  kCGMouseButtonCenter);
    }
  }
  return event;
}

/// Mulittouch callback, see what is touched. If 3 are on the mouse set
/// threedowns, else unset threedowns.
int touchCallback(int device, Finger* data, int nFingers, double timestamp,
                  int frame)
{
  NSAutoreleasePool* pool = [NSAutoreleasePool new];
  fingersQua = [[NSUserDefaults standardUserDefaults] integerForKey:kFingersNum];
  float maxDistanceDelta = [[NSUserDefaults standardUserDefaults] floatForKey:kMaxDistanceDelta];
  float maxTimeDelta = [[NSUserDefaults standardUserDefaults] integerForKey:kMaxTimeDeltaMs] / 1000.f;
  
  if (needToClick) {
    threeDown = nFingers == fingersQua;
  } else {
    if (nFingers == 0) {
      NSTimeInterval elapsedTime = touchStartTime ? -[touchStartTime timeIntervalSinceNow] : 0;
      touchStartTime = NULL;
      if (middleclickX + middleclickY && elapsedTime <= maxTimeDelta) {
        float delta = ABS(middleclickX - middleclickX2) + ABS(middleclickY - middleclickY2);
        if (delta < maxDistanceDelta) {
          // Emulate a middle click
          
          // get the current pointer location
          CGEventRef ourEvent = CGEventCreate(NULL);
          CGPoint ourLoc = CGEventGetLocation(ourEvent);
          CFRelease(ourEvent);
          
          CGMouseButton buttonType = kCGMouseButtonCenter;
          
          postMouseEvent(kCGEventOtherMouseDown, buttonType, ourLoc);
          postMouseEvent(kCGEventOtherMouseUp, buttonType, ourLoc);
        }
      }
    } else if (nFingers > 0 && touchStartTime == NULL) {
      NSDate* now = [NSDate new];
      touchStartTime = [now retain];
      [now release];
      
      maybeMiddleClick = YES;
      middleclickX = 0.0f;
      middleclickY = 0.0f;
    } else {
      if (maybeMiddleClick == YES) {
        NSTimeInterval elapsedTime = -[touchStartTime timeIntervalSinceNow];
        if (elapsedTime > maxTimeDelta)
          maybeMiddleClick = NO;
      }
    }
    
    if (nFingers > fingersQua) {
      maybeMiddleClick = NO;
      middleclickX = 0.0f;
      middleclickY = 0.0f;
    }
    
    if (nFingers == fingersQua) {
      if (maybeMiddleClick == YES) {
        for (int i = 0; i < fingersQua; i++)
        {
          mtPoint pos = ((Finger *)&data[i])->normalized.pos;
          middleclickX += pos.x;
          middleclickY += pos.y;
        }
        middleclickX2 = middleclickX;
        middleclickY2 = middleclickY;
        maybeMiddleClick = NO;
      } else {
        middleclickX2 = 0.0f;
        middleclickY2 = 0.0f;
        for (int i = 0; i < fingersQua; i++)
        {
          mtPoint pos = ((Finger *)&data[i])->normalized.pos;
          middleclickX2 += pos.x;
          middleclickY2 += pos.y;
        }
      }
    }
  }
  
  [pool release];
  return 0;
}

/// Restart the listeners when devices are connected/invalidated.
- (void)restartListeners
{
  NSLog(@"Restarting app functionality...");
  stopUnstableListeners();
  [self startUnstableListeners];
}

/// Callback when a multitouch device is added.
void multitouchDeviceAddedCallback(void* _controller,
                                   io_iterator_t iterator)
{
  io_object_t item;
  while ((item = IOIteratorNext(iterator))) {
    IOObjectRelease(item);
  }
  
  NSLog(@"Multitouch device added, restarting...");
  Controller* controller = (Controller*)_controller;
  [controller scheduleRestart:2];
}

void displayReconfigurationCallBack(CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void* _controller)
{
  if(flags & kCGDisplaySetModeFlag || flags & kCGDisplayAddFlag || flags & kCGDisplayRemoveFlag || flags & kCGDisplayDisabledFlag)
  {
    NSLog(@"Display reconfigured, restarting...");
    Controller* controller = (Controller*)_controller;
    [controller scheduleRestart:2];
  }
}

static void registerMTDeviceCallback(MTDeviceRef device, MTContactCallbackFunction callback) {
    MTRegisterContactFrameCallback(device, callback); // assign callback for device
    MTDeviceStart(device, 0); // start sending events
}
static void unregisterMTDeviceCallback(MTDeviceRef device, MTContactCallbackFunction callback) {
    MTUnregisterContactFrameCallback(device, callback); // unassign callback for device
    MTDeviceStop(device); // stop sending events
    MTDeviceRelease(device);
}

static void postMouseEvent(CGEventType eventType, CGMouseButton buttonType, CGPoint ourLoc) {
    CGEventRef mouseEvent = CGEventCreateMouseEvent(NULL, eventType, ourLoc, buttonType);
    CGEventPost(kCGHIDEventTap, mouseEvent);
    CFRelease(mouseEvent);
}

- (BOOL)getIsSystemTapToClickDisabled {
  NSString* isSystemTapToClickEnabled = [self runCommand:(@"defaults read com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking")];
  return [isSystemTapToClickEnabled isEqualToString:@"0\n"];
}

- (NSString *)runCommand:(NSString *)commandToRun {
  NSPipe* pipe = [NSPipe pipe];
  
  NSTask* task = [NSTask new];
  [task setLaunchPath: @"/bin/sh"];
  [task setArguments:@[@"-c", [NSString stringWithFormat:@"%@", commandToRun]]];
  [task setStandardOutput:pipe];
  
  NSFileHandle* file = [pipe fileHandleForReading];
  [task launch];
  
  NSString *output = [[NSString alloc] initWithData:[file readDataToEndOfFile] encoding:NSUTF8StringEncoding];
  
  [task release];
  
  return [output autorelease];
}

@end
