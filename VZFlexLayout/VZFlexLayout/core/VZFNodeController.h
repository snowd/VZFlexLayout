//
//  VZFNodeController.h
//  VZFlexLayout
//
//  Created by Sleen on 16/2/25.
//  Copyright © 2016年 Vizlab. All rights reserved.
//

#import <Foundation/Foundation.h>

@class VZFNode;
@class UIView;

/**
 *  Controller对应Node生命周期的callback
 *
 *  controller会被默认创建，并被node的scopeHandler引用
 *
 *  @subclass: 所有controller的基类，
 *
 */
@interface VZFNodeController : NSObject

@property (nonatomic,weak,readonly) VZFNode *node;
@property (nonatomic,weak,readonly) UIView *view;

- (void)willUpdateNode          NS_REQUIRES_SUPER;
- (void)willMountNode           NS_REQUIRES_SUPER;
- (void)willRemountNode         NS_REQUIRES_SUPER;

- (void)didUpdateNode           NS_REQUIRES_SUPER;
- (void)didMountNode            NS_REQUIRES_SUPER;
- (void)didRemountNode          NS_REQUIRES_SUPER;

- (void)willUnmountNode         NS_REQUIRES_SUPER;
- (void)didUnmountNode          NS_REQUIRES_SUPER;

- (void)willReleaseBackingView  NS_REQUIRES_SUPER;
- (void)didAquireView           NS_REQUIRES_SUPER;

@end