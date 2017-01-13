//
//  FBHostItem.h
//  FBComponentListDemo
//
//  Created by moxin on 16/1/20.
//  Copyright © 2016年 VizLab. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(int,FBScrollItemState){
    
    kDefault = 0,
    kLoading = 1,
    kLoaded = 2

};



@interface FBScrollItem : NSObject

@property(nonatomic,assign)FBScrollItemState state;
@property(nonatomic,strong)NSString* name;
@property(nonatomic,strong)NSString* imagePath;


@end


@interface FBHostItem : NSObject


@property(nonatomic,strong,readonly)NSString* type;
@property(nonatomic,strong,readonly)NSString* headIconURL;
@property(nonatomic,strong,readonly)NSString* nick;
@property(nonatomic,strong,readonly)NSString* time;
@property(nonatomic,strong,readonly)NSString* score;
@property(nonatomic,strong,readonly)NSString* content;
@property(nonatomic,strong,readonly)NSString* location;
@property(nonatomic,strong,readonly)NSArray<NSString* >* dishes;
@property(nonatomic,strong,readonly)NSArray<NSString* >* images;
@property(nonatomic,strong,readonly)NSArray<FBScrollItem* >* cards;

@property(nonatomic,strong,readonly)NSString* commentCount;
@property(nonatomic,strong,readonly)NSString* rewardCount;
@property(nonatomic,strong,readonly)NSString* likeCount;

@property(nonatomic,strong,readonly)NSArray<NSString* >* rewardedPersons;
@property(nonatomic,strong,readonly)NSArray<NSString* >* likePersons;
@property(nonatomic,strong,readonly)NSArray<NSString* >* comments;

@property(nonatomic,strong,readonly)NSString* isLike;
@property(nonatomic,strong,readonly)NSString* isReward;
@property(nonatomic,strong,readonly)NSString* isComment;

@property (nonatomic, strong, readonly) NSDictionary *iconTextBlockDict;

+ (instancetype)newWithJSON:(NSDictionary* )json;


@end