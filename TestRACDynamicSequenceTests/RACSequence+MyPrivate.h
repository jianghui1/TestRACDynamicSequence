//
//  RACSequence+MyPrivate.h
//  TestRACDynamicSequenceTests
//
//  Created by ys on 2018/8/14.
//  Copyright © 2018年 ys. All rights reserved.
//

#import "RACSequence.h"

@interface RACSequence ()

- (instancetype)bind:(RACStreamBindBlock)bindBlock passingThroughValuesFromSequence:(RACSequence *)passthroughSequence;

@end
