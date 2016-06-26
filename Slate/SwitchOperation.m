//
//  SwitchOperation.m
//  Slate
//
//  Created by Jigish Patel on 3/9/12.
//  Copyright 2012 Jigish Patel. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see http://www.gnu.org/licenses

#import "SwitchOperation.h"
#import "SwitchWindow.h"
#import "SwitchView.h"
#import "SwitchAppView.h"
#import "SlateLogger.h"
#import "SlateConfig.h"
#import "Constants.h"
#import "RunningApplications.h"
#import "Binding.h"
#import "StringTokenizer.h"

@interface SwitchOperation() {
  NSArray *apps;
  NSMutableArray *appsToQuit;
  NSMutableArray *appsToForceQuit;
  NSInteger currentApp;
}
@end

@implementation SwitchOperation

static const NSString *DEFAULT_BACK_KEY = @"`";
static const NSString *DEFAULT_QUIT_KEY = @"q";
static const NSString *DEFAULT_FQUIT_KEY = @"f";
static const NSString *DEFAULT_HIDE_KEY = @"h";

@synthesize modifiers;

- (id)init {
  self = [super init];
  if (self) {
    backKeyCode = [[[Binding asciiToCodeDict] objectForKey:DEFAULT_BACK_KEY] unsignedIntValue];
    quitKeyCode = [[[Binding asciiToCodeDict] objectForKey:DEFAULT_QUIT_KEY] unsignedIntValue];
    fquitKeyCode = [[[Binding asciiToCodeDict] objectForKey:DEFAULT_FQUIT_KEY] unsignedIntValue];
    hideKeyCode = [[[Binding asciiToCodeDict] objectForKey:DEFAULT_HIDE_KEY] unsignedIntValue];
    appsToQuit = [NSMutableArray array];
    appsToForceQuit = [NSMutableArray array];
    apps = nil;
    currentApp = -1;
    switchers = [NSMutableArray array];
    switchersToViews = [NSMutableArray array];
  }
  return self;
}

- (id)initWithOptions:(NSString *)_options {
  self = [super init];
  if (self) {
    backKeyCode = [[[Binding asciiToCodeDict] objectForKey:DEFAULT_BACK_KEY] unsignedIntValue];
    quitKeyCode = [[[Binding asciiToCodeDict] objectForKey:DEFAULT_QUIT_KEY] unsignedIntValue];
    fquitKeyCode = [[[Binding asciiToCodeDict] objectForKey:DEFAULT_FQUIT_KEY] unsignedIntValue];
    hideKeyCode = [[[Binding asciiToCodeDict] objectForKey:DEFAULT_HIDE_KEY] unsignedIntValue];
    NSMutableArray *optionsArr = [NSMutableArray array];
    [StringTokenizer tokenize:_options into:optionsArr];
    for (NSString *option in optionsArr) {
      NSArray *optionTokens = [option componentsSeparatedByString:COLON];
      if ([optionTokens count] != 2) continue;
      NSString *keyName = [optionTokens objectAtIndex:0];
      NSString *keyValue = [optionTokens objectAtIndex:1];
      NSNumber *keyCode = [[Binding asciiToCodeDict] objectForKey:keyValue];
      if (keyCode == nil) continue;
      if ([keyName isEqualToString:BACK]) {
        backKeyCode = [keyCode unsignedIntValue];
      } else if ([keyName isEqualToString:QUIT]) {
        quitKeyCode = [keyCode unsignedIntValue];
      } else if ([keyName isEqualToString:FORCE_QUIT]) {
        fquitKeyCode = [keyCode unsignedIntValue];
      } else if ([keyName isEqualToString:HIDE]) {
        hideKeyCode = [keyCode unsignedIntValue];
      }
    }
    appsToQuit = [NSMutableArray array];
    appsToForceQuit = [NSMutableArray array];
    apps = nil;
    currentApp = -1;
    switchers = [NSMutableArray array];
    switchersToViews = [NSMutableArray array];
  }
  return self;
}

- (BOOL)doOperation {
  SlateLogger(@"----------------- Begin Switch Operation -----------------");
  ScreenWrapper *sw = [[ScreenWrapper alloc] init];
  BOOL success = [self doOperationWithAccessibilityWrapper:nil screenWrapper:sw];
  SlateLogger(@"-----------------  End Switch Operation  -----------------");
  return success;
}

- (BOOL)doOperationWithAccessibilityWrapper:(AccessibilityWrapper *)aw screenWrapper:(ScreenWrapper *)sw {
  [self evalOptionsWithAccessibilityWrapper:aw screenWrapper:sw];
  apps = [NSArray arrayWithArray:[[RunningApplications getInstance] apps]];
  for (NSRunningApplication *app __attribute__((unused)) in apps) {
    [appsToQuit addObject:[NSNumber numberWithBool:NO]];
    [appsToForceQuit addObject:[NSNumber numberWithBool:NO]];
  }
  float iconSize = [[SlateConfig getInstance] getFloatConfig:SWITCH_ICON_SIZE];
  float iconPadding = [[SlateConfig getInstance] getFloatConfig:SWITCH_ICON_PADDING];
  float iconViewSize = iconSize + 2*iconPadding;
  float selectedPadding = [[SlateConfig getInstance] getFloatConfig:SWITCH_SELECTED_PADDING];
  NSInteger switcherId = 0;
  BOOL showTitle = [[SlateConfig getInstance] getBoolConfig:SWITCH_SHOW_TITLES];
  float titleHeight = 0;
  float titleWidth = 0;
  if (showTitle) {
    NSString *testString = @"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:[NSFont fontWithName:[[SlateConfig getInstance] getConfig:SWITCH_FONT_NAME]
                                                                                          size:[[SlateConfig getInstance] getFloatConfig:SWITCH_FONT_SIZE]],
                                                                          NSFontAttributeName, nil];
    NSSize size = [testString sizeWithAttributes:attributes];
    titleHeight = size.height + iconPadding;
    if ([[[SlateConfig getInstance] getConfig:SWITCH_ORIENTATION] isEqualToString:SWITCH_ORIENTATION_VERTICAL]) {
      // loop through all apps and check size to set title width
      for (NSRunningApplication *app in apps) {
        size = [[app localizedName] sizeWithAttributes:attributes];
        if (titleWidth < size.width) titleWidth = size.width;
        if (titleHeight < size.height) titleHeight = size.height;
      }
    }
  }
  for (NSScreen *screen in [sw screens]) {
    NSRect frame;
    if ([[[SlateConfig getInstance] getConfig:SWITCH_ORIENTATION] isEqualToString:SWITCH_ORIENTATION_VERTICAL]) {
      frame = NSMakeRect([screen frame].size.width/2 - (iconViewSize + titleWidth)/2 - selectedPadding,
                         [screen frame].size.height/2 - ([apps count]*iconViewSize)/2 - selectedPadding,
                         iconViewSize + titleWidth + selectedPadding*2,
                         [apps count]*iconViewSize + selectedPadding*2);
    } else {
      frame = NSMakeRect([screen frame].size.width/2 - ([apps count]*iconViewSize)/2 - selectedPadding,
                         [screen frame].size.height/2 - (iconViewSize + titleHeight)/2 - selectedPadding,
                         [apps count]*iconViewSize + selectedPadding*2,
                         iconViewSize + titleHeight + selectedPadding*2);
    }
    NSWindow *window = [[SwitchWindow alloc] initWithContentRect:frame
                                                       styleMask:NSBorderlessWindowMask
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO
                                                          screen:screen];
    [window setReleasedWhenClosed:NO];
    [window setOpaque:NO];
    [window setBackgroundColor:[NSColor colorWithDeviceRed:0.0 green:0.0 blue:0.0 alpha:0.0]];
    [window makeKeyAndOrderFront:NSApp];
    [window setLevel:(NSScreenSaverWindowLevel - 1)];
    SwitchView *view = [[SwitchView alloc] initWithFrame:frame];
    [window setContentView:view];
    NSWindowController *wc = [[NSWindowController alloc] initWithWindow:window];
    [switchers addObject:wc];
    [switchersToViews addObject:[NSMutableArray array]];
    NSInteger i = 0;
    for (NSRunningApplication *app in apps) {
      SwitchAppView *appView;
      if ([[[SlateConfig getInstance] getConfig:SWITCH_ORIENTATION] isEqualToString:SWITCH_ORIENTATION_VERTICAL]) {
        appView = [[SwitchAppView alloc] initWithFrame:NSMakeRect(selectedPadding, ([apps count] - i - 1)*iconViewSize + selectedPadding, iconViewSize + titleWidth, iconViewSize)];
      } else {
        appView = [[SwitchAppView alloc] initWithFrame:NSMakeRect(i*iconViewSize + selectedPadding, selectedPadding, iconViewSize, iconViewSize + titleHeight)];
      }
      [appView updateApp:app];
      [(NSView *)[[wc window] contentView] addSubview:appView];
      [[switchersToViews objectAtIndex:switcherId] addObject:appView];
      i++;
    }
    currentApp = [apps count] > 0 ? 1 : 0;
    [[[switchersToViews objectAtIndex:switcherId] objectAtIndex:currentApp] setSelected:YES];
    switcherId++;
  }
  EventHotKeyID backHotKeyID;
  backHotKeyID.signature = *[@"switchKeyBack" cStringUsingEncoding:NSASCIIStringEncoding];
  backHotKeyID.id = 1000;
  RegisterEventHotKey(backKeyCode, modifiers, backHotKeyID, GetEventMonitorTarget(), 0, &backHotKeyRef);
  EventHotKeyID quitHotKeyID;
  quitHotKeyID.signature = *[@"switchKeyQuit" cStringUsingEncoding:NSASCIIStringEncoding];
  quitHotKeyID.id = 1001;
  RegisterEventHotKey(quitKeyCode, modifiers, quitHotKeyID, GetEventMonitorTarget(), 0, &quitHotKeyRef);
  EventHotKeyID fquitHotKeyID;
  fquitHotKeyID.signature = *[@"switchKeyFQuit" cStringUsingEncoding:NSASCIIStringEncoding];
  fquitHotKeyID.id = 1002;
  RegisterEventHotKey(fquitKeyCode, modifiers, fquitHotKeyID, GetEventMonitorTarget(), 0, &fquitHotKeyRef);
  EventHotKeyID hideHotKeyID;
  hideHotKeyID.signature = *[@"switchKeyHide" cStringUsingEncoding:NSASCIIStringEncoding];
  hideHotKeyID.id = 1003;
  RegisterEventHotKey(hideKeyCode, modifiers, hideHotKeyID, GetEventMonitorTarget(), 0, &hideHotKeyRef);
  return YES;
}

- (BOOL)testOperation {
  return YES;
}

- (void)activateSwitchKey:(EventHotKeyID)key isRepeat:(BOOL)isRepeat {
  SlateLogger(@"Activate Switch Key");
  NSInteger selectedApp = currentApp+1;
  if (key.id == 1000) {
    selectedApp = currentApp == 0 ? (isRepeat && [[SlateConfig getInstance] getBoolConfig:SWITCH_STOP_REPEAT_AT_EDGE] ? 0 : [apps count] - 1) : currentApp - 1;
    SlateLogger(@"  Back: %ld",selectedApp);
  } else if (key.id == 1001) {
    if (isRepeat) return;
    SlateLogger(@"  Quit: %ld",currentApp);
    if ([[appsToForceQuit objectAtIndex:currentApp] boolValue]) {
      [appsToForceQuit replaceObjectAtIndex:currentApp withObject:[NSNumber numberWithBool:NO]];
      for (NSInteger switcherId = 0; switcherId < [switchers count]; switcherId++) {
        [[[switchersToViews objectAtIndex:switcherId] objectAtIndex:currentApp] updateForceQuitting:NO];
      }
    }
    [appsToQuit replaceObjectAtIndex:currentApp withObject:[NSNumber numberWithBool:![[appsToQuit objectAtIndex:currentApp] boolValue]]];
    for (NSInteger switcherId = 0; switcherId < [switchers count]; switcherId++) {
      [[[switchersToViews objectAtIndex:switcherId] objectAtIndex:currentApp] updateQuitting:[[appsToQuit objectAtIndex:currentApp] boolValue]];
    }
    return;
  } else if (key.id == 1002) {
    if (isRepeat) return;
    SlateLogger(@"  Force Quit: %ld",currentApp);
    if ([[appsToQuit objectAtIndex:currentApp] boolValue]) {
      [appsToQuit replaceObjectAtIndex:currentApp withObject:[NSNumber numberWithBool:NO]];
      for (NSInteger switcherId = 0; switcherId < [switchers count]; switcherId++) {
        [[[switchersToViews objectAtIndex:switcherId] objectAtIndex:currentApp] updateQuitting:NO];
      }
    }
    [appsToForceQuit replaceObjectAtIndex:currentApp withObject:[NSNumber numberWithBool:![[appsToForceQuit objectAtIndex:currentApp] boolValue]]];
    for (NSInteger switcherId = 0; switcherId < [switchers count]; switcherId++) {
      [[[switchersToViews objectAtIndex:switcherId] objectAtIndex:currentApp] updateForceQuitting:[[appsToForceQuit objectAtIndex:currentApp] boolValue]];
    }
    return;
  } else if (key.id == 1003) {
    if (isRepeat) return;
    NSRunningApplication *cApp = [apps objectAtIndex:currentApp];
    if ([cApp isHidden]) {
       SlateLogger(@"  UnHide: %ld",currentApp);
      if ([[SlateConfig getInstance] getBoolConfig:SWITCH_ONLY_FOCUS_MAIN_WINDOW]) {
        [AccessibilityWrapper focusMainWindow:cApp];
      } else {
        [AccessibilityWrapper focusApp:cApp];
      }
      for (NSInteger switcherId = 0; switcherId < [switchers count]; switcherId++) {
        [[[switchersToViews objectAtIndex:switcherId] objectAtIndex:currentApp] updateHidden:NO];
      }
    } else {
       SlateLogger(@"  Hide: %ld",currentApp);
      [cApp hide];
      for (NSInteger switcherId = 0; switcherId < [switchers count]; switcherId++) {
        [[[switchersToViews objectAtIndex:switcherId] objectAtIndex:currentApp] updateHidden:YES];
      }
    }
    return;
  } else if (selectedApp >= [apps count]) {
    selectedApp = isRepeat && [[SlateConfig getInstance] getBoolConfig:SWITCH_STOP_REPEAT_AT_EDGE] ? [apps count] - 1 : 0;
  }
  for (NSInteger switcherId = 0; switcherId < [switchers count]; switcherId++) {
    SlateLogger(@"SELECTING %ld,%ld,%ld",switcherId,currentApp,selectedApp);
    [[[switchersToViews objectAtIndex:switcherId] objectAtIndex:currentApp] updateSelected:NO];
    [[[switchersToViews objectAtIndex:switcherId] objectAtIndex:selectedApp] updateSelected:YES];
  }
  currentApp = selectedApp;
}

- (BOOL)modifiersChanged:(UInt32)was new:(UInt32)new {
  if (was != new) {
    [self killSwitchers];
    if ([[apps objectAtIndex:currentApp] isHidden]) { [[apps objectAtIndex:currentApp] unhide]; }
    if ([[SlateConfig getInstance] getBoolConfig:SWITCH_ONLY_FOCUS_MAIN_WINDOW]) {
      [AccessibilityWrapper focusMainWindow:[apps objectAtIndex:currentApp]];
    } else {
      [AccessibilityWrapper focusApp:[apps objectAtIndex:currentApp]];
    }
    return YES;
  }
  return NO;
}

- (void)killSwitchers {
  for (NSWindowController *controller in switchers) {
    [controller close];
  }
  for (NSMutableArray *views in switchersToViews) {
    for (NSView *view in views) {
      [view removeFromSuperview];
    }
    [views removeAllObjects];
  }
  UnregisterEventHotKey(backHotKeyRef);
  UnregisterEventHotKey(quitHotKeyRef);
  UnregisterEventHotKey(fquitHotKeyRef);
  UnregisterEventHotKey(hideHotKeyRef);
  NSInteger i = 0;
  for (NSNumber *appToQuit in appsToQuit) {
    if ([appToQuit boolValue]) {
      SlateLogger(@"Quitting: '%@'",[[apps objectAtIndex:i] localizedName]);
      [(NSRunningApplication *)[apps objectAtIndex:i] terminate];
    }
    i++;
  }
  [appsToQuit removeAllObjects];
  i = 0;
  for (NSNumber *appToForceQuit in appsToForceQuit) {
    if ([appToForceQuit boolValue]) {
      SlateLogger(@"Force Quitting: '%@'",[[apps objectAtIndex:i] localizedName]);
      [(NSRunningApplication *)[apps objectAtIndex:i] forceTerminate];
    }
    i++;
  }
  [appsToForceQuit removeAllObjects];
  [switchers removeAllObjects];
  [switchersToViews removeAllObjects];
}

- (void)parseOption:(NSString *)name value:(id)value {
  if (value == nil) { return; }
  if (![value isKindOfClass:[NSString class]]) {
    @throw([NSException exceptionWithName:[NSString stringWithFormat:@"Invalid %@", name] reason:[NSString stringWithFormat:@"Invalid %@ '%@'", name, value] userInfo:nil]);
  }
  if ([name isEqualToString:OPT_BACK]) {
    backKeyCode = [[[Binding asciiToCodeDict] objectForKey:value] unsignedIntValue];
  } else if ([name isEqualToString:OPT_QUIT]) {
    quitKeyCode = [[[Binding asciiToCodeDict] objectForKey:value] unsignedIntValue];
  } else if ([name isEqualToString:OPT_FORCE_QUIT]) {
    fquitKeyCode = [[[Binding asciiToCodeDict] objectForKey:value] unsignedIntValue];
  } else if ([name isEqualToString:OPT_HIDE]) {
    hideKeyCode = [[[Binding asciiToCodeDict] objectForKey:value] unsignedIntValue];
  }
}

+ (id)switchOperation {
  return [[SwitchOperation alloc] init];
}

+ (id)switchOperationFromString:(NSString *)switchOperation {
  // switch option+
  // options:
  //   back:[key code]
  //   quit:[key code]
  //   force-quit:[key code]
  //   hide:[key code]
  NSMutableArray *tokens = [[NSMutableArray alloc] initWithCapacity:10];
  [StringTokenizer tokenize:switchOperation into:tokens maxTokens:2];
  Operation *op = nil;
  if ([tokens count] > 1) {
    op = [[SwitchOperation alloc] initWithOptions:[tokens objectAtIndex:1]];
  } else {
    op = [[SwitchOperation alloc] init];
  }
  return op;
}

@end
