//
//  VZFluxEventEmitter.m
//  VZFlexLayout
//
//  Created by moxin on 16/6/28.
//  Copyright © 2016年 Vizlab. All rights reserved.
//

#import "VZFluxEventEmitter.h"


@implementation VZFluxEventEmitter
{
    VZFluxEmitterSubscription* _currentSubscription;
    VZFluxEventSubscriber* _subscriber;
}

- (id)init{
    self = [super init];
    if (self) {
        
        _currentSubscription = nil;
        _subscriber = [VZFluxEventSubscriber new];
        
    }
    return self;

}


- (VZFluxEmitterSubscription* )addListener:(VZFluxEventListener)listener withEvent:(NSString* )eventType Context:(id)context{

    VZFluxEmitterSubscription* subscription = [[VZFluxEmitterSubscription alloc]initWithSubscriber:_subscriber Listener:listener Context:context];
    return (VZFluxEmitterSubscription* )[_subscriber addSubscription:subscription EventType:eventType];

}

- (VZFluxEmitterSubscription* )once:(NSString* )eventType do:(VZFluxEventListener)listener Context:(id)context{

    __weak typeof(self) weakSelf = self;
    return [self addListener:^(NSString *eventType, id data) {
        
        [weakSelf removeCurrentListener];
        if (listener) {
            listener(eventType,data);
        }
        
    } withEvent:eventType Context:context];
}



- (void)removeAllListenersForEvent:(NSString* )eventType{
    
    [_subscriber removeAllSubscriptions:eventType];

}

- (void)removeCurrentListener{

    if (_currentSubscription) {
        [_subscriber removeSubscription:_currentSubscription];
    }

}

- (NSArray* )listenersForEvent:(NSString* )eventType{

    NSArray* subcriptions = [_subscriber subscriptionsForEventType:eventType];
    
    NSMutableArray* list = [NSMutableArray new];
    
    for(VZFluxEmitterSubscription* subscripiton in subcriptions){
        if (subscripiton.listener) {
            [list addObject:subscripiton.listener];
        }
    }
    return [list copy];

}

- (void)emit:(NSString* )event withData:(id)data{
    
    NSArray* listeners = [self listenersForEvent:event];
    for (VZFluxEventListener listener in listeners) {
        if (listener) {
            listener(event,data);
        }
    }
    

}
@end
