//
//  VZFluxDispatcher.m
//  O2OReact
//
//  Created by moxin on 16/6/2.
//  Copyright © 2016年 Alipay. All rights reserved.
//

#import "VZFluxDispatcher.h"
#import "VZFunctor.h"
#import "VZFMacros.h"
#import <libkern/OSAtomic.h>
#import <unordered_map>

const NSString* gFluxTokenPrefix = @"ID_";

typedef std::unordered_map<NSString* , bool, NSStringHashFunctor, NSStringEqualFunctor> FluxTokenMap;

@implementation VZFluxDispatcher
{
    //{key:dispatchToken, value:callback}
    NSMutableDictionary<NSString*, DispatchPayload>*  _callbacks;
    
    //handled dispatch token map
    FluxTokenMap _handledMap;
    
    //pending map
    FluxTokenMap _pendingMap;
    
    int32_t _lastId;
    
    OSSpinLock _lock;
    
    dispatch_queue_t _serialDispatchQueue;
    
    std::shared_ptr<FluxAction> _pendingPayload;
}


- (id)init{

    self = [super init];
    if (self) {
        
        _callbacks = [NSMutableDictionary new];
        _isDispatching = NO;
        _handledMap = {};
        _pendingMap = {};
        _lastId = 1;
        _lock = OS_SPINLOCK_INIT;
        _serialDispatchQueue = dispatch_queue_create( "com.o2o.flux", DISPATCH_QUEUE_SERIAL);
        
    }
    return self;
}

- (void)dealloc{
    _pendingPayload = nullptr;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - public APIs

- (NSString* )registerWithCallback:(DispatchPayload)payload{

    if (self.isDispatching) {
        _invariant(!self.isDispatching, @"Dispatcher.register(...): Cannot register in the middle of a dispatch.");
        return nil;
    }
    
    NSString* token = [gFluxTokenPrefix stringByAppendingString:[NSString stringWithFormat:@"%d",OSAtomicIncrement32(&_lastId)]];
    
    OSSpinLockLock(&_lock);
    _callbacks[token] = [payload copy];
    OSSpinLockUnlock(&_lock);
    
    
    return token;
}

- (void)unregister:(NSString *)token{
    if (self.isDispatching) {
        _invariant(!self.isDispatching, @"Dispatcher.unregister(...): Cannot unregister in the middle of a dispatch.");
        return;
    }
    if (!_callbacks[token]) {
        _invariant(_callbacks[token], @"Dispatcher.unregister(...): %@ does not map to a registered callback.",token);
        return;
    }
    
    OSSpinLockLock(&_lock);
    [_callbacks removeObjectForKey:token];
    OSSpinLockUnlock(&_lock);
}

- (void)waitFor:(NSArray<NSString *> *)list mode:(VZFActionUpdateMode)m{
   
    if(self.isDispatching){
        _invariant(!self.isDispatching, @"Dispatcher.waitFor(...): Must be invoked while dispatching.");
        return ;
    }
    
    for(int i=0; i<list.count; i ++){
        
        NSString* token = list[i];
        
        if (_pendingMap[token]) {
            //如果有token在pending
            continue;
        }
        
        //invoke callback
        if(_callbacks[token])
        {
            [self _invokeCallback:token mode:m];
        }
    }
    
}

- (void)dispatch:(const VZ::FluxAction &)action mode:(VZFActionUpdateMode)m{

    if (_isDispatching) {

        _invariant(!_isDispatching, @"Dispatch.dispatch(...): Cannot dispatch in the middle of a dispatch.");
        return;
    }
    
    [self _startDispathcing:action];
    

    for (NSString* token in [_callbacks allKeys]) {
        if(_pendingMap[token]){
            continue;
        }
        [self _invokeCallback:token mode:m];
    }
    
    [self _stopDispatching];

}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - private APIs

- (void)_startDispathcing:(const FluxAction& )payload{
    for (NSString* token in [_callbacks allKeys]) {
        _pendingMap[token] = false;
        _handledMap[token] = false;
    }
    _pendingPayload = std::make_shared<FluxAction>(payload);
    _isDispatching = YES;
}

- (void)_stopDispatching{
    _pendingPayload = nullptr;
    _isDispatching = NO;
    
}

- (void)_invokeCallback:(NSString* )token mode:(VZFActionUpdateMode)m{
    
    _pendingMap[token] = true;
    
    if (m == VZFActionUpdateModeAsynchronous) {
       
        dispatch_async(_serialDispatchQueue, ^{
            
            DispatchPayload payload = _callbacks[token];
            payload(*_pendingPayload);
        });
    }
    else{
    
        DispatchPayload payload = _callbacks[token];
        payload(*_pendingPayload);
    }

    
    _handledMap[token] = true;
    
}

@end
