//
//  VZFNode.m
//  VZFlexLayout
//
//  Created by moxin on 16/1/26.
//  Copyright © 2016年 Vizlab. All rights reserved.
//

#import "VZFNode.h"
#import "VZFUtils.h"
#import "VZFMacros.h"
#import "VZFlexNode.h"
#import "VZFNodeLayout.h"
#import "VZFNodeInternal.h"
#import "VZFNodeLifeCycle.h"
#import "VZFlexNode+VZFNode.h"
#import "VZFNodeMountContext.h"
#import "VZFNodeViewManager.h"
#import "VZFNodeMountContext.h"
#import "VZFNodeSpecs.h"
#import "VZFNodeViewClass.h"
#import "UIView+VZAttributes.h"
#import "VZFNodeBackingViewInterface.h"

struct VZFNodeMountedInfo{
  
    __weak VZFNode* parentNode;
    __weak UIView* mountedView;
    
    struct {
        __weak UIView* v;
        CGRect frame;
    } mountedContext;
};


using namespace VZ;
using namespace VZ::UIKit;

@implementation VZFNode
{
    
    VZFNodeLifeCycleState _lifeCycleState;
    std::unique_ptr<VZFNodeMountedInfo> _mountedInfo;
}


+ (instancetype)newWithView:(const ViewClass &)viewclass NodeSpecs:(const NodeSpecs &)specs{

    return [[self alloc] initWithView: viewclass Specs:specs];
}

+ (instancetype)new
{
    return [self newWithView:[UIView class] NodeSpecs:{}];
}

- (instancetype)initWithView:(const ViewClass& )viewclass Specs:(const NodeSpecs& )specs{
    self = [super init];
    if (self) {
        
        _specs          = specs;
        _viewClass      = viewclass;
        _flexNode       = [VZFlexNode flexNodeWithFlexAttributes:specs.flex];
        _flexNode.name  = [NSString stringWithUTF8String:specs.identifier.c_str()];
        _flexNode.fNode = self;

    }
    return self;
}

- (instancetype)init
{
    VZ_NOT_DESIGNATED_INITIALIZER();
}

- (void)dealloc{
    
    _flexNode.fNode = nil;
    _mountedInfo.reset();
    _mountedInfo = nullptr;
}

- (UIView* )mountedView{

    if (_mountedInfo) {
        return _mountedInfo -> mountedView;
    }
    else{
        return nil;
    }
}

- (NodeLayout)computeLayoutThatFits:(CGSize)sz{
    
    [_flexNode layout:sz];
    NodeLayout layout = { self,
                             _flexNode.resultFrame.size,
                             _flexNode.resultFrame.origin,
                             _flexNode.resultMargin};
    return [self nodeDidLayout];
}

- (BOOL)shouldMemoizeLayout{
    
    return NO;
}

- (NodeLayout)nodeDidLayout{
    NodeLayout layout{
        self,
        self.flexNode.resultFrame.size,
        self.flexNode.resultFrame.origin,
        self.flexNode.resultMargin,
        {}
    };
    
//    NSLog(@"[%@]-->nodeDidLayout:%@",self.class, NSStringFromCGSize(layout.size));
    return layout;
}


- (NSString *)description {
    
    NSString* className = NSStringFromClass([self class]);
    return [[NSString alloc] initWithFormat:@"Class:{%@} \nLayout:{%@\n}",className,self.flexNode.description];
}

- (VZFNode* )superNode{
    return _mountedInfo -> parentNode;
}

- (id)nextResponder {
    return ([self superNode]?:nil)?:self.rootNodeView;
}

- (id)targetForAction:(SEL)action withSender:(id)sender{
    return [self respondsToSelector:action] ? self : [[self nextResponder] targetForAction:action withSender:sender];
}


-(VZ::UIKit::MountResult)mountInContext:(const VZ::UIKit::MountContext &)context Size:(CGSize) size ParentNode:(VZFNode* )parentNode
{    
    if (_mountedInfo == nullptr) {
        _mountedInfo.reset( new VZFNodeMountedInfo() );
    }
    
    _mountedInfo -> parentNode =  parentNode;
    
    //获取一个reuse view
    UIView* view = [context.viewManager viewForNode:self];
    
    //说明reusepool中有view
    if (view) {
        //不是当前的backingview
        if (view != _mountedInfo -> mountedView) {
            [view.node unmount];
        }
        
        view.node = self;
        _mountedInfo -> mountedView = view;
        [self didAquireBackingView];

        //计算公式:
        //position.x = frame.origin.x + anchorPoint.x * bounds.size.width；
        //position.y = frame.origin.y + anchorPoint.y * bounds.size.height；
 /*       const CGPoint anchorPoint = view.layer.anchorPoint;
        view.center = context.position + CGPoint({anchorPoint.x * size.width, anchorPoint.y * size.height});
        view.bounds = {view.bounds.origin,size};
  */
        //apply frame
        view.frame  = {context.position, size};
        
        //apply attributes
        [view applyAttributes];

        //update mountedInfo
        _mountedInfo -> mountedContext = {view,{context.position,size}};
        
        return {.hasChildren = YES, .childContext = context.childContextForSubview(view)};
        

    }
    else{
        //这种情况对应于没有viewclass的node，例如compositeNode，他没有backingview，mount过程中使用的是view的是上一个view
        _mountedInfo -> mountedView = nil;
        _mountedInfo -> mountedContext = {context.viewManager.managedView,{context.position,size}};
        
        return {.hasChildren = YES, .childContext = context};
        
    }
    

}


-(void)unmount{
    
    if (_mountedInfo != nullptr) {
        [self  willUnmount];
        
        UIView* currentMountedView = _mountedInfo -> mountedView;
        if (currentMountedView) {
            [self willReleaseBackingView];
            
            //        //@discussion:reset state
            //        //VZ::Mounting::reset(view);
            
            
            currentMountedView.node = nil;
            currentMountedView = nil;
        }
        _mountedInfo.reset();
        [self didUnmount];
    }

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - life cycle

-(void)willMount{

    switch (_state) {
        case VZFNodeStateUnmounted:
        {
            _state = VZFNodeStateMounting;
            break;
        }
        case VZFNodeStateMounted:
        {
            _state = VZFNodeStateRemounting;
            [self willRemount];
            break;
        }
        default:
        {
            VZFAssert(NO, @"State:[%@] Error: willmount -> '%@' ",[self class],VZFNodeStateName(_state));
            break;
        }
    }
    
    NSLog(@"[%@] --> willMount --> state:%@",[self class],VZFNodeStateName(_state));
}

- (void)willRemount{
    
    NSLog(@"[%@] --> willRemount --> state:%@",[self class],VZFNodeStateName(_state));

}

-(void)didMount{


    switch (_state) {
        case VZFNodeStateMounting:
        {
            _state = VZFNodeStateMounted;
            break;
        }
        case VZFNodeStateRemounting:{
            _state = VZFNodeStateMounted;
            [self didRemount];
            break;
        }
        default:
        {
            VZFAssert(NO, @"State:[%@] Error: didmount -> '%@' ",[self class],VZFNodeStateName(_state));
            break;
        }
    }
    
    NSLog(@"[%@] --> didMount --> state:%@",[self class],VZFNodeStateName(_state));
}

- (void)didRemount{

    NSLog(@"[%@] --> didRemount --> state:%@",[self class],VZFNodeStateName(_state));
}

- (void)willUnmount{


    
    switch (_state) {
        case VZFNodeStateMounted:
        {
            _state = VZFNodeStateUnmounting;
            break;
        }
        default:
        {
            VZFAssert(NO, @"State:[%@] Error: will unmount -> '%@' ",[self class],VZFNodeStateName(_state));
            break;
        }
    }
    
    NSLog(@"[%@] --> willUnmount --> state:%@",[self class],VZFNodeStateName(_state));
    
}

- (void)didUnmount{

    switch (_state) {
        case VZFNodeStateUnmounting:
            _state = VZFNodeStateUnmounted;
            break;
            
        default:{
            VZFAssert(NO, @"State:[%@] Error: did unmount -> '%@' ",[self class],VZFNodeStateName(_state));
            break;
        }
    }
    
    NSLog(@"[%@] --> didUnmount --> state:%@",[self class],VZFNodeStateName(_state));
}

- (void)willReleaseBackingView{
    
    NSLog(@"[%@] --> willReleaseBackingView --> state:%@",[self class],VZFNodeStateName(_state));
    
}

- (void)didAquireBackingView{

    NSLog(@"[%@] --> didAquireBackingView --> state:%@",[self class],VZFNodeStateName(_state));
}






@end
