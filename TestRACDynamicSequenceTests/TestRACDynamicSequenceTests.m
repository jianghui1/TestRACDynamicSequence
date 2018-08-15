//
//  TestRACDynamicSequenceTests.m
//  TestRACDynamicSequenceTests
//
//  Created by ys on 2018/8/14.
//  Copyright © 2018年 ys. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <ReactiveCocoa.h>
#import <RACDynamicSequence.h>
#import "RACSequence+MyPrivate.h"

@interface TestRACDynamicSequenceTests : XCTestCase

@end

@implementation TestRACDynamicSequenceTests

- (void)test_sequenceWithHeadBlock
{
    RACDynamicSequence *sequence = [RACDynamicSequence sequenceWithHeadBlock:^id{
        return @(1);
    } tailBlock:^RACSequence *{
        return [RACSequence return:@(2)];
    }];
    NSLog(@"sequenceWithHeadBlock -- %@", sequence);
    
    // 打印日志
    /*
     2018-08-14 17:16:02.801309+0800 TestRACDynamicSequence[50314:13492872] sequenceWithHeadBlock -- <RACDynamicSequence: 0x6000000973e0>{ name = , head = (unresolved), tail = (unresolved) }
     */
}

- (void)test_sequenceWithLazyDependency
{
    RACDynamicSequence *sequence = [RACDynamicSequence sequenceWithLazyDependency:^id{
        return @(1);
    } headBlock:^id(id dependency) {
        return dependency;
    } tailBlock:^RACSequence *(id dependency) {
        return [RACSequence return:dependency];
    } ];
    NSLog(@"sequenceWithLazyDependency -- %@", sequence);
    
    // 打印日志
    /*
     2018-08-14 17:16:24.973383+0800 TestRACDynamicSequence[50346:13494056] sequenceWithLazyDependency -- <RACDynamicSequence: 0x604000091e90>{ name = , head = (unresolved), tail = (unresolved) }
     */
}

- (void)test_head
{
    RACDynamicSequence *sequence1 = [RACDynamicSequence sequenceWithHeadBlock:^id{
        return @(1);
    } tailBlock:^RACSequence *{
        return nil;
    }];
    RACDynamicSequence *sequence2 = [RACDynamicSequence sequenceWithLazyDependency:^id{
        return @(100);
    } headBlock:^id(id dependency) {
        return dependency;
    } tailBlock:^RACSequence *(id dependency) {
        return nil;
    }];
    
    NSLog(@"head -- %@ -- %@", [sequence1 head], [sequence2 head]);
    
    // 打印日志
    /*
     2018-08-14 17:24:13.966048+0800 TestRACDynamicSequence[50694:13517182] head -- 1 -- 100
     */
}

- (void)test_tail
{
    RACDynamicSequence *sequence1 = [RACDynamicSequence sequenceWithHeadBlock:^id{
        return @(1);
    } tailBlock:^RACSequence *{
        return [RACSequence return:@(2)];
    }];
    
    RACDynamicSequence *sequence2 = [RACDynamicSequence sequenceWithLazyDependency:^id{
        return @(100);
    } headBlock:^id(id dependency) {
        return dependency;
    } tailBlock:^RACSequence *(id dependency) {
        return [RACSequence return:dependency];
    }];
    
    NSLog(@"tail -- %@ -- %@", [sequence1 tail], [sequence2 tail]);
    
    // 打印日志
    /*
     2018-08-14 17:27:35.492093+0800 TestRACDynamicSequence[50838:13527548] tail -- <RACUnarySequence: 0x60000022fda0>{ name = , head = 2 } -- <RACUnarySequence: 0x600000230a00>{ name = , head = 100 }
     */
}

- (void)test_bind_pass
{
    RACSequence *sequence = [RACSequence return:@(1)];
    RACStreamBindBlock (^bindBlock)(void) = ^RACStreamBindBlock{
        return ^(id value, BOOL *stop) {
            return [RACSequence return:@(100 + [value intValue])];
        };
    };
    RACSequence *sequence1 = [sequence bind:bindBlock];
    
    RACSequence *passSequence = [RACSequence return:@(2)];
    RACSequence *sequence2 = [sequence bind:bindBlock() passingThroughValuesFromSequence:passSequence];
    
    NSLog(@"bind_pass -- %@ -- %@ -- %@ -- %@", sequence1.head, sequence1.tail, sequence1.tail.head, sequence1.tail.tail);
    NSLog(@"bind_pass -- %@ -- %@ -- %@ -- %@", sequence2.head, sequence2.tail, sequence2.tail.head, sequence2.tail.tail);
    
    // 打印日志
    /*
     2018-08-14 19:04:35.033489+0800 TestRACDynamicSequence[53175:13675544] bind_pass -- 101 -- (null) -- (null) -- (null)
     2018-08-14 19:04:35.033765+0800 TestRACDynamicSequence[53175:13675544] bind_pass -- 2 -- <RACDynamicSequence: 0x600000286900>{ name = , head = 101, tail = (null) } -- 101 -- (null)
     */
}

@end
