//
//  VZFNodeViewManager.m
//  VZFlexLayout
//
//  Created by moxin on 16/1/30.
//  Copyright © 2016年 Vizlab. All rights reserved.
//

#import "VZFNodeViewManager.h"
#import "VZFNode.h"
#import "VZFNodeInternal.h"
#import "VZFCompositeNode.h"
#import "VZFStackNode.h"
#import "VZFImageNode.h"
#import "VZFTextNode.h"
#import "VZFButtonNode.h"
#import "VZFNetworkImageNode.h"
#import "VZFNetworkImageView.h"
#import "VZFlexCell.h"
#import <objc/runtime.h>
#import "VZFNodeControllerInternal.h"
#import "VZFActionWrapper.h"


@implementation UIView(VZFNode)

const void* _id = &_id;
- (void)setNode:(VZFNode *)node{
    objc_setAssociatedObject(self, _id, node, OBJC_ASSOCIATION_ASSIGN);
}

- (VZFNode* )node{
    return objc_getAssociatedObject(self, _id);
}

@end

using namespace VZ;
@implementation VZFNodeViewManager
{

}

+ (UIView* )viewForNode:(VZFNode* )node withLayoutSpec:(const VZFNodeLayout&)layout reuseView:(UIView *)oldView
{
    [node.controller nodeWillMount:node];
    UIView *view;
    
    VZFNode*(^unwrap)(VZFNode* __input) = ^VZFNode*(VZFNode* __input){
        if([__input isKindOfClass:[VZFCompositeNode class]]){
            return  ((VZFCompositeNode* )__input).node;
        }
        else{
            return __input;
        }
    };
    
    VZFNode* unwrappedNode = unwrap(node);
    if (![unwrappedNode isKindOfClass : [VZFStackNode class] ]) {
        view = [self _viewForNode:unwrappedNode withLayoutSpec:layout reuseView:oldView];
    }
    else{
        
        UIView* stackView = [self _viewForNode:unwrappedNode withLayoutSpec:layout reuseView:oldView];
        VZFStackNode* stackNode = (VZFStackNode* )unwrappedNode;
        
        NSMutableArray *subviews = [[NSMutableArray alloc] initWithCapacity:stackNode.children.size()];
        
        if (oldView) {
            
            VZFNode* oldNode = oldView.node;
            
            if(!oldNode.specs.view.block) {
                [subviews addObjectsFromArray:oldView.subviews];
            }
        }
        
        for (int i = 0; i < stackNode.children.size(); i++) {
            
            VZFStackChildNode _childNode = stackNode.children[i];
            VZFNode* _node = _childNode.node;
            VZFNodeLayout _layout = layout.childrenLayout()[i];
            //递归
            UIView* _view = [self viewForNode:_node withLayoutSpec:_layout reuseView:subviews.count > i?subviews[i]:nil];
            [stackView addSubview:_view];
            
        }
        view = stackView;
    }
    [node.controller nodeDidMount:node];
    return view;
}

+ (BOOL)canReuse:(VZFNode *)node reuseView:(UIView *)reuseView {
    if ([node isMemberOfClass:VZFImageNode.class] && [reuseView isMemberOfClass:UIImageView.class]) {
        return YES;
    }
    
    if ([node isMemberOfClass:VZFButtonNode.class] && [reuseView isMemberOfClass:UIButton.class]) {
        return YES;
    }
    
    if ([node isMemberOfClass:VZFTextNode.class] && [reuseView isMemberOfClass:UILabel.class]) {
        return YES;
    }
    
    if ([node isMemberOfClass:VZFNetworkImageNode.class] && [reuseView isMemberOfClass:VZFNetworkImageView.class]) {
        return YES;
    }
    
    if ((![node isMemberOfClass:VZFNetworkImageNode.class]&&![node isMemberOfClass:VZFImageNode.class] && ![node isMemberOfClass:VZFButtonNode.class] && ![node isMemberOfClass:VZFTextNode.class]) &&[reuseView isKindOfClass:UIView.class] && [node isKindOfClass:VZFNode.class]) {
        return YES;
    }
    
    
    return NO;
}

+ (UIView* )_viewForNode:(VZFNode *)node withLayoutSpec:(const VZFNodeLayout &)layout reuseView:(UIView *)reuseView{
    
    const NodeSpecs specs = node.specs;
    
    UIView* view;
    
    if ([self canReuse:node reuseView:reuseView]) {
        view = reuseView;
    } else {
        if (reuseView) {
            [reuseView removeFromSuperview];
        }
        view = [self _createUIView:node.viewClass];
    }

    [self _applyAttributes:specs.view ToUIView:view];
    view.frame = {layout.nodeOrigin(), layout.nodeSize()};
    [self _applyGestures:specs.gesture ToUIView:view AndNode:node];
    
    if ([node isKindOfClass:[VZFImageNode class]]) {
        VZFImageNode* imageNode = (VZFImageNode* )node;
        ((UIImageView*)view).image = nil;

        [self _applyImageAttributes:imageNode.imageSpecs ToImageView:(UIImageView* )view];
    }
    else if ([node isKindOfClass:[VZFButtonNode class]]){

        VZFButtonNode* buttonNdoe = (VZFButtonNode* )node;
        [self _applyButtonAttributes:buttonNdoe.buttonSpecs ToUIButton:(UIButton* )view];
    }
    else if ([node isKindOfClass:[VZFTextNode class]]){
        
        VZFTextNode* textNode = (VZFTextNode* )node;
        [self _applyTextAttributes:textNode.textSpecs ToUILabel:(UILabel* )view];
    }
    else if([node isKindOfClass:[VZFNetworkImageNode class]]){
        VZFNetworkImageNode* networkImageNode = (VZFNetworkImageNode* )node;
        
        [self _appleyNetworkImageAttributes:networkImageNode ToNetworkImageView:(VZFNetworkImageView* )view];
    }

    view.node = node;
    
    return view;
}

//----------------------------------------------------------------------------------------------------------------

+ (void)_applyGestures:(MultiMap<Class, ActionWrapper>)gestures ToUIView:(UIView* )view AndNode:(VZFNode* )node{
    [view.gestureRecognizers enumerateObjectsUsingBlock:^(__kindof UIGestureRecognizer * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [view removeGestureRecognizer:obj];
    }];
    static const void* _id = &_id;
    NSMutableArray * gestureArray = objc_getAssociatedObject(view, _id);
    if (gestureArray == nil) {
        gestureArray = [NSMutableArray array];
        objc_setAssociatedObject(view, _id, gestureArray, OBJC_ASSOCIATION_RETAIN);
    }
    for (auto iter=gestures.begin(); iter!=gestures.end(); iter=gestures.equal_range(iter->first).second){
        auto key = iter->first;
        UIGestureRecognizer *gestureRecognizer = [[key alloc] initWithTarget:nil action:nil];
        auto range = gestures.equal_range(key);
        for (auto it=range.first; it!=range.second; it++){
            id<VZFActionWrapper> wrapper = vz_actionWrapper(it->second);
            [gestureArray addObject:wrapper];
            [gestureRecognizer addTarget:wrapper action:@selector(invoke:)];
        }
        [view addGestureRecognizer:gestureRecognizer];
    }
}

+ (UIView* )_createUIView:(const ViewClass& )clz{

    return clz.createView()?:[UIView new];
}

+ (void)_applyAttributes:(const ViewAttrs&)vs ToUIView:(UIView* )view {

    view.tag                    = vs.tag;
    view.backgroundColor        = vs.backgroundColor?:[UIColor clearColor];
    view.clipsToBounds          = vs.clipToBounds;
    view.layer.cornerRadius     = vs.layer.cornerRadius;
    view.layer.borderColor      = vs.layer.borderColor.CGColor;
    view.layer.contents         = (__bridge id)vs.layer.contents.CGImage;
    
    if (vs.block) {
        vs.block(view);
    }

    
}

+ (void)_applyImageAttributes:(const ImageNodeSpecs& )imageNodeSpecs ToImageView:(UIImageView* )imageView{
    
    imageView.image = imageNodeSpecs.image;
    imageView.contentMode = imageNodeSpecs.contentMode;

}

+ (void)_applyButtonAttributes:(const ButtonNodeSpecs& )buttonNodeSpecs ToUIButton:(UIButton* )btn{
    btn.titleLabel.font = buttonNodeSpecs.font;

    for (auto title : buttonNodeSpecs.title) {
        [btn setTitle:title.second forState:title.first];
    }
    
    for (auto color : buttonNodeSpecs.titleColor) {
        [btn setTitleColor:color.second forState:color.first];
    }
    
    for (auto image : buttonNodeSpecs.backgroundImage) {
        [btn setBackgroundImage:image.second forState:image.first];
    }
    
    for (auto image : buttonNodeSpecs.image){
        [btn setImage:image.second forState:image.first];
    }
    
    [btn removeTarget:nil action:nil forControlEvents:UIControlEventAllEvents];
    static const void* _id = &_id;
    NSMutableArray * actionArray = objc_getAssociatedObject(btn, _id);
    if (actionArray == nil) {
        actionArray = [NSMutableArray array];
        objc_setAssociatedObject(btn, _id, actionArray, OBJC_ASSOCIATION_RETAIN);
    }
    for (auto action : buttonNodeSpecs.action) {
        id<VZFActionWrapper> wrapper = vz_actionWrapper(action.second);
        [actionArray addObject:wrapper];
        [btn addTarget:wrapper action:@selector(invoke:event:) forControlEvents:action.first];
    }
}

+ (void)_applyTextAttributes:(const TextNodeSpecs& )textNodeSpecs ToUILabel:(UILabel* )label{

    if (textNodeSpecs.attributedString) {
        label.attributedText = textNodeSpecs.attributedString;
    }
    else {
        label.text = textNodeSpecs.text;
        label.font = textNodeSpecs.font;
        label.textColor = textNodeSpecs.color;
    }
    label.textAlignment = textNodeSpecs.textAlignment;
    label.lineBreakMode = textNodeSpecs.lineBreakMode;
    label.numberOfLines = textNodeSpecs.maximumNumberOfLines;
}

+ (void)_appleyNetworkImageAttributes:(VZFNetworkImageNode* )node ToNetworkImageView:(VZFNetworkImageView* )networkImageView{


    NSURL* url = node.url;
    ImageNodeSpecs imageSpec = node.imageSpecs;
    id<VZFNetworkImageDownloadProtocol> imageDownloader = node.imageDownloader;
    UIImage*(^block)(UIImage* ) = node.imageProcessingBlock;
    
    VZFNetworkImageSpec* spec = [[VZFNetworkImageSpec alloc]initWithURL:url defaultImage:imageSpec.image imageProcessingFunc:block imageDownloader:imageDownloader];
    [networkImageView setSpec:spec];

}


//--------------------------------------------------------------------------------------------------

@end