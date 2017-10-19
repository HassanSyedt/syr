//
//  MouseRaster.m
//  MouseNative
//
//  Created by Anderson,Derek on 7/8/17.
//  Copyright © 2017 Anderson,Derek. All rights reserved.
//

#import "SyrRaster.h"

#import <UIKit/UIKit.h>

@interface SyrRaster()

@property UIView* rootView;
@property NSMutableDictionary* components;
@property NSMutableDictionary* animations;
@end

@implementation SyrRaster

+ (id) sharedInstance {
  static SyrRaster *instance = nil;
  @synchronized(self) {
    if (instance == nil) {
      instance = [[self alloc] init];
    }
  }
  return instance;
}


- (id) init
{
  self = [super init];
  if (self!=nil) {
    _components = [[NSMutableDictionary alloc] init];
    _animations = [[NSMutableDictionary alloc] init];
  }
  return self;
}

-(void) setupAnimation: (NSDictionary*) astDict {
  NSLog(@"%@", [astDict valueForKey:@"ast"]);
  NSError *jsonError;
  NSData *objectData = [[astDict valueForKey:@"ast"] dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *componentDict = [NSJSONSerialization JSONObjectWithData:objectData
                                                          options:NSJSONReadingMutableContainers
                                                            error:&jsonError];
  
  NSString* elementName = [componentDict objectForKey:@"elementName"];
  NSString* animatedTargetGuid = [componentDict objectForKey:@"guid"];
  
  if(elementName == nil) {
    NSArray* children = [componentDict objectForKey:@"children"];
    NSDictionary* child = [children objectAtIndex:0];
    elementName = [child valueForKey:@"type"];
    animatedTargetGuid = [child valueForKey:@"guid"];
  }
  
  if([elementName containsString:@"View"]) {
    UIView* view = [_components objectForKey:animatedTargetGuid];
    NSLog(@"animate");
    NSDictionary* animation = [componentDict objectForKey:@"animation"];
    if(animation != nil) {
      NSNumber* x = [animation objectForKey:@"x"];
      NSNumber* y = [animation objectForKey:@"y"];
      NSNumber* x2 = [animation objectForKey:@"x2"];
      NSNumber* y2 = [animation objectForKey:@"y2"];
      double duration = [[animation objectForKey:@"duration"] integerValue];
      duration = duration / 1000; // we get it as ms from the js
      
      view.frame  = CGRectMake([x floatValue], [y floatValue], view.frame.size.width, view.frame.size.height);
      [UIView animateWithDuration:[[NSNumber numberWithDouble:duration] floatValue] delay:1.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        view.frame  = CGRectMake([x2 floatValue], [y2 floatValue], view.frame.size.width, view.frame.size.height);
      } completion:^(BOOL finished) {
        NSDictionary* event = @{@"guid":animatedTargetGuid, @"type":@"animationComplete", @"animation": animation};
        [_bridge sendEvent:event];
      }];
    }
  }
}

-(void) parseAST: (NSDictionary*) astString withRootView: (SyrRootView*) rootView {

  NSError *jsonError;
  NSData *objectData = [[astString valueForKey:@"ast"] dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *astDict = [NSJSONSerialization JSONObjectWithData:objectData
                                                       options:NSJSONReadingMutableContainers
                                                         error:&jsonError];
  if([astDict objectForKey:@"update"]) {
    [self update: astDict];
  } else {
    _rootView = rootView;
    [self build: astDict];
  }
}

-(void) update: (NSDictionary*) astDict {
  NSString* elementName = [astDict objectForKey:@"elementName"];
  if([elementName containsString:@"View"]) {
    UIView* view = [_components objectForKey:[[astDict valueForKey:@"instance"] valueForKey:@"guid"]];
    if(view == nil) {
      view = [[UIView alloc] init];
    } else {
      [view.subviews makeObjectsPerformSelector: @selector(removeFromSuperview)];
    }
    NSDictionary* attributes = [astDict objectForKey:@"attributes"];
    NSDictionary* style = [attributes objectForKey:@"style"];
    view = [self styleView:view withStyle:style];
    
    NSDictionary* event = @{@"guid":[[astDict valueForKey:@"instance"] valueForKey:@"guid"], @"type":@"componentWillUpdate"};
    [_bridge sendEvent:event];
    
    NSDictionary* children = [astDict objectForKey:@"children"];
    for(id child in children) {
      if([child isKindOfClass:[NSString class]]) {
        UITextView *textView = [[UITextView alloc] init];
        textView.text = child;
        textView.frame = CGRectMake(0, 0, view.frame.size.width, view.frame.size.height);
        textView.backgroundColor = [UIColor clearColor];
        [view addSubview:textView];
      } else {
        NSString* elementName = [child objectForKey:@"elementName"];
        if([elementName containsString:@"View"]) {
          UIView* subview = [_components objectForKey:[[child valueForKey:@"instance"] valueForKey:@"guid"]];
          NSDictionary* parent = [child objectForKey:@"parent"];
          if(subview == nil) {
            subview = [[UIView alloc] init];
          }
          NSDictionary* attributes = [child objectForKey:@"attributes"];
          NSDictionary* style = [attributes objectForKey:@"style"];
          subview = [self styleView:subview withStyle:style];
          
          for(id subchild in [child objectForKey:@"children"]) {
            if([subchild isKindOfClass:[NSString class]]) {
              UITextView *textView = [[UITextView alloc] init];
              textView.text = subchild;
              textView.frame = CGRectMake(0, 0, subview.frame.size.width, subview.frame.size.height);
              textView.backgroundColor = [UIColor clearColor];
              [subview addSubview:textView];
            }
          }
          
          [view addSubview:subview];
        }
        
        if([elementName containsString:@"Button"]) {
          UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
          [button setTitle:@"Press Me" forState:UIControlStateNormal];
          button.frame = CGRectMake(0, 0, view.frame.size.width, view.frame.size.height);
          [button sizeToFit];
          [view addSubview:button];
        }
        
      }
    }
  }
  NSDictionary* event = @{@"guid":[[astDict valueForKey:@"instance"] valueForKey:@"guid"], @"type":@"componentDidUpdate"};
  [_bridge sendEvent:event];
}

-(void) build: (NSDictionary*) astDict {
  NSString* elementName = [astDict objectForKey:@"elementName"];
  if([elementName containsString:@"View"]) {
    UIView* view = [_components objectForKey:[[astDict valueForKey:@"instance"] valueForKey:@"guid"]];
    NSDictionary* parent = [[astDict objectForKey:@"instance"] objectForKey:@"parent"];
    if(view == nil) {
      view = [[UIView alloc] init];
    }
    NSDictionary* attributes = [astDict objectForKey:@"attributes"];
    NSDictionary* style = [attributes objectForKey:@"style"];
    view = [self styleView:view withStyle:style];
    [_rootView addSubview:view];
    
    NSDictionary* children = [astDict objectForKey:@"children"];
    for(id child in children) {
      if([child isKindOfClass:[NSString class]]) {
        UITextView *textView = [[UITextView alloc] init];
        textView.text = child;
        textView.frame = CGRectMake(0, 0, view.frame.size.width, view.frame.size.height);
        textView.backgroundColor = [UIColor clearColor];
        [view addSubview:textView];
      } else {
        NSString* elementName = [child objectForKey:@"elementName"];
        if([elementName containsString:@"View"]) {
          UIView* subview = [_components objectForKey:[[child valueForKey:@"instance"] valueForKey:@"guid"]];
          NSDictionary* parent = [child objectForKey:@"parent"];
          if(subview == nil) {
            subview = [[UIView alloc] init];
          }
          NSDictionary* attributes = [child objectForKey:@"attributes"];
          NSDictionary* style = [attributes objectForKey:@"style"];
          subview = [self styleView:subview withStyle:style];
          
          for(id subchild in [child objectForKey:@"children"]) {
            if([subchild isKindOfClass:[NSString class]]) {
              UITextView *textView = [[UITextView alloc] init];
              textView.text = subchild;
              textView.frame = CGRectMake(0, 0, subview.frame.size.width, subview.frame.size.height);
              textView.backgroundColor = [UIColor clearColor];
              [subview addSubview:textView];
            }
          }
          
          [view addSubview:subview];
        }
        
        if([elementName containsString:@"Button"]) {
          UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
          [button setTitle:@"Press Me" forState:UIControlStateNormal];
          button.frame = CGRectMake(0, 0, view.frame.size.width, view.frame.size.height);
          [button sizeToFit];
          [view addSubview:button];
        }
    
      }
    }
    
    [_bridge rasterRenderedComponent:[[astDict valueForKey:@"instance"] valueForKey:@"guid"]];
    [_components setObject:view forKey:[[astDict valueForKey:@"instance"] valueForKey:@"guid"]];
  }
}

-(UIView*) styleView: (UIView*) view withStyle: (NSDictionary*) style {
  view.frame = [self styleFrame:style];
  NSString* backgroundColor = [style valueForKey:@"backgroundColor"];
  view.backgroundColor = [self colorFromHash:backgroundColor];
  return view;
}

- (CGRect)styleFrame:(NSDictionary*)styleDictionary {
  NSNumber* frameHeight = [styleDictionary objectForKey:@"height"];
  NSNumber* frameWidth = [styleDictionary objectForKey:@"width"];
  NSNumber* framex = [styleDictionary objectForKey:@"left"];
  NSNumber* framey = [styleDictionary objectForKey:@"top"];
  return CGRectMake([framex doubleValue], [framey doubleValue], [frameWidth doubleValue], [frameHeight doubleValue]);
}

- (UIColor*)colorFromHash:(NSString*) color {
  color = [color stringByReplacingOccurrencesOfString:@"#" withString:@"0x"];
  unsigned colorInt = 0;
  [[NSScanner scannerWithString:color] scanHexInt:&colorInt];
  return UIColorFromRGB(colorInt);
}


@end
