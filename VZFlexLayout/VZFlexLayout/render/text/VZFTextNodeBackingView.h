//
//  VZFTextNodeBackingView.h
//  VZFlexLayout
//
//  Created by moxin on 16/9/18.
//  Copyright © 2016年 Vizlab. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "VZFNodeBackingViewInterface.h"
#import "VZFTextNodeBackingLayer.h"

@class VZFTextNodeRenderer;
@interface VZFTextNodeBackingView : UIView<VZFNodeBackingViewInterface>

@property(nonatomic,strong) VZFTextNodeRenderer* textRenderer;

@end