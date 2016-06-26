//
//  HintView.m
//  Slate
//
//  Created by Jigish Patel on 3/3/12.
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

#import "HintView.h"
#import "Constants.h"
#import "SlateConfig.h"
#import "ExpressionPoint.h"

@implementation HintView

@synthesize title,text,icon,hintSize;

static NSColor *hintBackgroundColor = nil;
static NSColor *hintFontColor = nil;
static float hintFontStrokeSize = 0.0;
static NSColor *hintFontStrokeColor = nil;
static NSFont *hintFont = nil;
static bool	hintTitleShow = false;
static NSFont *hintTitleFont = nil;
static NSColor *hintTitleFontColor = nil;
static NSColor *hintTitleBackgroundColor = nil;
static float hintIconAlpha = -1.0;

- (id)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self setWantsLayer:YES];
    [self setIcon:nil];
    if (hintBackgroundColor == nil) {
      NSArray *bgColorArr = [[SlateConfig getInstance] getArrayConfig:WINDOW_HINTS_BACKGROUND_COLOR];
      if ([bgColorArr count] < 4) bgColorArr = [WINDOW_HINTS_BACKGROUND_COLOR_DEFAULT componentsSeparatedByString:SEMICOLON];
      hintBackgroundColor = [NSColor colorWithDeviceRed:[[bgColorArr objectAtIndex:0] floatValue]/255.0
                                                  green:[[bgColorArr objectAtIndex:1] floatValue]/255.0
                                                   blue:[[bgColorArr objectAtIndex:2] floatValue]/255.0
                                                  alpha:[[bgColorArr objectAtIndex:3] floatValue]];
    }
    if (hintFontColor == nil) {
      NSArray *fColorArr = [[SlateConfig getInstance] getArrayConfig:WINDOW_HINTS_FONT_COLOR];
      if ([fColorArr count] < 4) fColorArr = [WINDOW_HINTS_FONT_COLOR_DEFAULT componentsSeparatedByString:SEMICOLON];
      hintFontColor = [NSColor colorWithDeviceRed:[[fColorArr objectAtIndex:0] floatValue]/255.0
                                            green:[[fColorArr objectAtIndex:1] floatValue]/255.0
                                             blue:[[fColorArr objectAtIndex:2] floatValue]/255.0
                                            alpha:[[fColorArr objectAtIndex:3] floatValue]];
    }
	if (hintFontStrokeSize == 0.0) {
		hintFontStrokeSize = [[SlateConfig getInstance] getFloatConfig:WINDOW_HINTS_FONT_STROKE_SIZE];
	}
	if (hintFontStrokeColor == nil) {
		NSArray *fsColorArr = [[SlateConfig getInstance] getArrayConfig:WINDOW_HINTS_FONT_STROKE_COLOR];
		if ([fsColorArr count] < 4) fsColorArr = [WINDOW_HINTS_FONT_STROKE_COLOR_DEFAULT componentsSeparatedByString:SEMICOLON];
		hintFontStrokeColor = [NSColor colorWithDeviceRed:[[fsColorArr objectAtIndex:0] floatValue]/255.0
											  green:[[fsColorArr objectAtIndex:1] floatValue]/255.0
											   blue:[[fsColorArr objectAtIndex:2] floatValue]/255.0
											  alpha:[[fsColorArr objectAtIndex:3] floatValue]];
	}
    if (hintFont == nil) {
      hintFont = [NSFont fontWithName:[[SlateConfig getInstance] getConfig:WINDOW_HINTS_FONT_NAME]
                                 size:[[SlateConfig getInstance] getFloatConfig:WINDOW_HINTS_FONT_SIZE]];
    }
	hintTitleShow = [[SlateConfig getInstance] getBoolConfig:WINDOW_HINTS_TITLE_SHOW];
    if (hintTitleShow)
    {
		if (hintTitleFont == nil){
			hintTitleFont = [NSFont fontWithName:[[SlateConfig getInstance] getConfig:WINDOW_HINTS_TITLE_FONT_NAME]
									   size:[[SlateConfig getInstance] getFloatConfig:WINDOW_HINTS_TITLE_FONT_SIZE]];
		}
		if (hintTitleFontColor == nil) {
			NSArray *fColorArr = [[SlateConfig getInstance] getArrayConfig:WINDOW_HINTS_TITLE_FONT_COLOR];
			if ([fColorArr count] < 4) fColorArr = [WINDOW_HINTS_TITLE_FONT_COLOR_DEFAULT componentsSeparatedByString:SEMICOLON];
			hintTitleFontColor = [NSColor colorWithDeviceRed:[[fColorArr objectAtIndex:0] floatValue]/255.0
													   green:[[fColorArr objectAtIndex:1] floatValue]/255.0
														blue:[[fColorArr objectAtIndex:2] floatValue]/255.0
													   alpha:[[fColorArr objectAtIndex:3] floatValue]];
		}
		if (hintTitleBackgroundColor == nil) {
			NSArray *bgColorArr = [[SlateConfig getInstance] getArrayConfig:WINDOW_HINTS_TITLE_BACKGROUND_COLOR];
			if ([bgColorArr count] < 4) bgColorArr = [WINDOW_HINTS_TITLE_BACKGROUND_COLOR_DEFAULT componentsSeparatedByString:SEMICOLON];
			hintTitleBackgroundColor = [NSColor colorWithDeviceRed:[[bgColorArr objectAtIndex:0] floatValue]/255.0
														green:[[bgColorArr objectAtIndex:1] floatValue]/255.0
														 blue:[[bgColorArr objectAtIndex:2] floatValue]/255.0
														alpha:[[bgColorArr objectAtIndex:3] floatValue]];
		}
	}
    if (hintIconAlpha < 0.0) {
      hintIconAlpha = [[SlateConfig getInstance] getFloatConfig:WINDOW_HINTS_ICON_ALPHA];
    }
  }
  return self;
}

- (void)setIconFromAppRef:(AXUIElementRef)appRef {
  if ([[SlateConfig getInstance] getBoolConfig:WINDOW_HINTS_SHOW_ICONS]) {
    pid_t pid;
    AXUIElementGetPid(appRef, &pid);
    NSRunningApplication *app = [NSRunningApplication runningApplicationWithProcessIdentifier:pid];
    [self setIcon:[app icon]];
  }
}

- (void)drawCenteredText:(NSString *)string bounds:(NSRect)rect attributes:(NSDictionary *)attributes {
  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithString:string];
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize:NSMakeSize(rect.size.width, FLT_MAX)];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  [layoutManager addTextContainer:textContainer];
  [textStorage addLayoutManager:layoutManager];
  [textStorage addAttribute:NSFontAttributeName value:[attributes objectForKey:NSFontAttributeName]
                      range:NSMakeRange(0, [textStorage length])];
  [textContainer setLineFragmentPadding:0.0];
	
  [layoutManager glyphRangeForTextContainer:textContainer];
	
  NSSize size = [layoutManager usedRectForTextContainer:textContainer].size;
	NSPoint origin = NSMakePoint(rect.origin.x + (rect.size.width - size.width) / 2,
                             rect.origin.y + (rect.size.height - size.height) / 2);
  [string drawAtPoint:origin withAttributes:attributes];
}

- (void)drawRect:(NSRect)dirtyRect {
	
  CGRect hintRect;
  if(hintTitleShow)
  {
	  hintRect = NSMakeRect((self.bounds.size.width - hintSize.width)/2,
							self.bounds.size.height - hintSize.height,
							hintSize.width,
							hintSize.height);
  }
  else
  {
	  hintRect = self.bounds;
  }
  [[NSGraphicsContext currentContext] saveGraphicsState];
  [[NSGraphicsContext currentContext] setShouldAntialias:YES];

  // draw the rounded rect
  [hintBackgroundColor set];
  float cornerSize = [[SlateConfig getInstance] getFloatConfig:WINDOW_HINTS_ROUNDED_CORNER_SIZE];
  NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:hintRect xRadius:cornerSize yRadius:cornerSize];
  [path fill];

  // draw the icon on top of the rounded rect, if specified
  if (icon != nil) {
    [icon drawInRect:hintRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:hintIconAlpha];
  }

  // draw hint letter
  [self drawCenteredText:text
                  bounds:hintRect
              attributes:[NSDictionary dictionaryWithObjectsAndKeys:hintFont,
                                                                    NSFontAttributeName,
                                                                    hintFontColor,
                                                                    NSForegroundColorAttributeName,
																	[NSNumber numberWithFloat:hintFontStrokeSize],
																	NSStrokeWidthAttributeName,
																	hintFontStrokeColor,
																	NSStrokeColorAttributeName,
																	nil]];
	if (hintTitleShow)
	{
		CGRect titleRect = NSMakeRect(0, 0, self.bounds.size.width, self.bounds.size.height - hintSize.height - 2);
		
		// draw title
		[hintTitleBackgroundColor set];
		[[NSBezierPath bezierPathWithRoundedRect:titleRect xRadius:4 yRadius:4] fill];
		
		[self drawCenteredText:title
						bounds:titleRect
					attributes:[NSDictionary dictionaryWithObjectsAndKeys:
								hintTitleFont,
								NSFontAttributeName,
								hintTitleFontColor,
								NSForegroundColorAttributeName,
								nil]];
	}
	
  [[NSGraphicsContext currentContext] restoreGraphicsState];
}

@end
