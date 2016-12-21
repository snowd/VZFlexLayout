//
//  VZFTextNode.m
//  VZFlexLayout
//
//  Created by moxin on 16/2/16.
//  Copyright © 2016年 Vizlab. All rights reserved.
//

#import "VZFTextNode.h"
#import "VZFNodeInternal.h"
#import "VZFlexNode.h"
#import "VZFMacros.h"
#import "VZFNodeViewClass.h"
#import "VZFNodeLayout.h"
#import "VZFTextNodeSpecs.h"
#import "VZFTextNodeRenderer.h"
#import "VZFTextNodeBackingView.h"


@implementation VZFTextNode
@synthesize textSpecs = _textSpecs;

+ (instancetype)newWithView:(const ViewClass &)viewClass NodeSpecs:(const NodeSpecs &)specs{
    VZ_NOT_DESIGNATED_INITIALIZER();
}

+ (instancetype)newWithTextAttributes:(const TextNodeSpecs&) textSpecs NodeSpecs:(const NodeSpecs&) specs{
    
    VZFTextNode* textNode = [super newWithView:[VZFTextNodeBackingView class] NodeSpecs:specs];
    
    if (textNode) {
        textNode -> _textSpecs = textSpecs.copy();
        __block VZFTextNodeRenderer *renderer = [VZFTextNodeRenderer new];
        if (textSpecs.attributedString) {
            renderer.text = textSpecs.attributedString;
        }
        else {
            renderer.text = textSpecs.getAttributedString();
        }
        
        switch (textSpecs.lineBreakMode) {
            case NSLineBreakByTruncatingHead:
                renderer.truncatingMode = VZFTextTruncatingHead;
                break;
            case NSLineBreakByTruncatingMiddle:
                renderer.truncatingMode = VZFTextTruncatingMiddle;
                break;
            case NSLineBreakByTruncatingTail:
                renderer.truncatingMode = VZFTextTruncatingTail;
                break;
            case NSLineBreakByClipping:
                renderer.truncatingMode = VZFTextTruncatingClip;
                break;
            case NSLineBreakByCharWrapping:
                renderer.lineBreakMode = VZFTextLineBreakByChar;
                break;
            case NSLineBreakByWordWrapping:
                renderer.lineBreakMode = VZFTextLineBreakByWord;
                break;
        }
        renderer.alignment = textSpecs.alignment;
        renderer.maxNumberOfLines = textSpecs.lines;
        
        textNode -> _renderer = renderer;
        
        __weak typeof(textNode) weakNode = textNode;
        textNode.flexNode.measure = ^(CGSize constrainedSize) {
            
            __strong typeof(weakNode) strongNode = weakNode;
            
            if (!strongNode) {
                return CGSizeZero;
            }

            // 当文字宽度超过 constrainedSize.width 时，会打省略号，此时 measure 的结果宽度可能会略小于 constrainedSize.width。这样可能会导致跟在它右边的文本有一个很小的宽度，而显示出小半个文字。为了处理这个问题，这里给 constrainedSize.width 变宽一点（这里是大约一个字的大小），再用 measure 结果跟 constrainedSize.width 取最小值。
            VZ::TextNodeSpecs& textSpecs = strongNode->_textSpecs;
            renderer.maxWidth = textSpecs.lines == 1 ? constrainedSize.width + textSpecs.getFont().pointSize : constrainedSize.width;
            CGSize size = [renderer textSize];
            size.width = MIN(size.width, constrainedSize.width);
            return size;
        };
    }
    return textNode;
}

@end
