##### `RACDynamicSequence` 作为`RACSequence`的子类，只提供了一个新的方法`sequenceWithLazyDependency:headBlock:tailBlock:`，供父类`bind:passingThroughValuesFromSequence:`方法中调用。

完整测试用例[在这里](https://github.com/jianghui1/TestRACDynamicSequence)。

打开`.m`文件，从上往下看代码：
* `#define DEALLOC_OVERFLOW_GUARD 100` 定义一个数值决定最大同时释放`RACDynamicSequence`对象的个数，来避免栈溢出。
* `_head` 对应于父类属性`head`。
* `_tail` 对应于父类属性`tail`。
* `_dependency` 存储`dependencyBlock`执行的结果值。
* `headBlock` 存储参数`headBlock`。
* `tailBlock` 存储参数`tailBlock`。
* `hasDependency` 用来标识是否是通过`dependencyBlock`初始化的。
* `dependencyBlock` 存储参数`dependencyBlock`。

接下来，看看每个方法的实现：
    
    + (RACSequence *)sequenceWithHeadBlock:(id (^)(void))headBlock tailBlock:(RACSequence *(^)(void))tailBlock {
    	NSCParameterAssert(headBlock != nil);
    
    	RACDynamicSequence *seq = [[RACDynamicSequence alloc] init];
    	seq.headBlock = [headBlock copy];
    	seq.tailBlock = [tailBlock copy];
    	seq.hasDependency = NO;
    	return seq;
    }
对父类方法的重写，父类的实现中，其实就是调用此类进行的初始化。
初始化`RACDynamicSequence`对象，并保存参数`headBlock` `tailBlock` ，并设置`hasDependency`值。

测试用例：

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
***

    + (RACSequence *)sequenceWithLazyDependency:(id (^)(void))dependencyBlock headBlock:(id (^)(id dependency))headBlock tailBlock:(RACSequence *(^)(id dependency))tailBlock {
    	NSCParameterAssert(dependencyBlock != nil);
    	NSCParameterAssert(headBlock != nil);
    
    	RACDynamicSequence *seq = [[RACDynamicSequence alloc] init];
    	seq.headBlock = [headBlock copy];
    	seq.tailBlock = [tailBlock copy];
    	seq.dependencyBlock = [dependencyBlock copy];
    	seq.hasDependency = YES;
    	return seq;
    }
初始化`RACDynamicSequence`对象，并保存参数`headBlock` `tailBlock` `dependencyBlock` ，并设置`hasDependency`值。

测试用例：

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
***

    - (void)dealloc {
    	static volatile int32_t directDeallocCount = 0;
    
    	if (OSAtomicIncrement32(&directDeallocCount) >= DEALLOC_OVERFLOW_GUARD) {
    		OSAtomicAdd32(-DEALLOC_OVERFLOW_GUARD, &directDeallocCount);
    
    		// Put this sequence's tail onto the autorelease pool so we stop
    		// recursing.
    		__autoreleasing RACSequence *tail __attribute__((unused)) = _tail;
    	}
    	
    	_tail = nil;
    }
在销毁方法中，通过`directDeallocCount`与`DEALLOC_OVERFLOW_GUARD`比较来决定是将_tail直接释放，还是放到自动释放池中，保证不会因为同时释放太多对象而导致栈溢出。
***

    - (id)head {
    	@synchronized (self) {
    		id untypedHeadBlock = self.headBlock;
    		if (untypedHeadBlock == nil) return _head;
    
    		if (self.hasDependency) {
    			if (self.dependencyBlock != nil) {
    				_dependency = self.dependencyBlock();
    				self.dependencyBlock = nil;
    			}
    
    			id (^headBlock)(id) = untypedHeadBlock;
    			_head = headBlock(_dependency);
    		} else {
    			id (^headBlock)(void) = untypedHeadBlock;
    			_head = headBlock();
    		}
    
    		self.headBlock = nil;
    		return _head;
    	}
    }
通过`@synchronized`可知，该方法中进行的是同步操作。
* 先获取`headBlock`，如果存在会将`headBlock`执行的结果赋值给`_head`。然后返回。
* 如果不存在，直接返回`_head`。
由于上面两个初始化函数中存在`headBlock`而且父类中对该方法说明此参数必须存在，那么这里也就是返回参数`headBlock`执行的结果。在`headBlock`执行的时候会根据是否有参数`dependencyBlock`来获取一个值当做`headBlock`的参数。

测试用例：

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
***

    - (RACSequence *)tail {
    	@synchronized (self) {
    		id untypedTailBlock = self.tailBlock;
    		if (untypedTailBlock == nil) return _tail;
    
    		if (self.hasDependency) {
    			if (self.dependencyBlock != nil) {
    				_dependency = self.dependencyBlock();
    				self.dependencyBlock = nil;
    			}
    
    			RACSequence * (^tailBlock)(id) = untypedTailBlock;
    			_tail = tailBlock(_dependency);
    		} else {
    			RACSequence * (^tailBlock)(void) = untypedTailBlock;
    			_tail = tailBlock();
    		}
    
    		if (_tail.name == nil) _tail.name = self.name;
    
    		self.tailBlock = nil;
    		return _tail;
    	}
    }
该方法的作用与上面方法类似，获取参数`tailBlock`执行的结果。

测试用例：

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
***

    - (NSString *)description {
    	id head = @"(unresolved)";
    	id tail = @"(unresolved)";
    
    	@synchronized (self) {
    		if (self.headBlock == nil) head = _head;
    		if (self.tailBlock == nil) {
    			tail = _tail;
    			if (tail == self) tail = @"(self)";
    		}
    	}
    
    	return [NSString stringWithFormat:@"<%@: %p>{ name = %@, head = %@, tail = %@ }", self.class, self, self.name, head, tail];
    }
该方法格式化该序列对象的打印日志。
***
其实，上面涉及到主要功能的代码就是`head` `tail`方法，这两个方法第一次调用的时候才进行计算存储，方便下次使用。所以说`RACDynamicSequence`是个冷序列。

[上一篇](https://blog.csdn.net/jianghui12138/article/details/81808843)中`bind:passingThroughValuesFromSequence:`返回了一个`RACDynamicSequence`对象，那么这里就重新对`bind:`方法进行分析：

    - (instancetype)bind:(RACStreamBindBlock)bindBlock passingThroughValuesFromSequence:(RACSequence *)passthroughSequence {
    	// Store values calculated in the dependency here instead, avoiding any kind
    	// of temporary collection and boxing.
    	//
    	// This relies on the implementation of RACDynamicSequence synchronizing
    	// access to its head, tail, and dependency, and we're only doing it because
    	// we really need the performance.
    	__block RACSequence *valuesSeq = self;
    	__block RACSequence *current = passthroughSequence;
    	__block BOOL stop = NO;
    
    	RACSequence *sequence = [RACDynamicSequence sequenceWithLazyDependency:^ id {
    		while (current.head == nil) {
    			if (stop) return nil;
    
    			// We've exhausted the current sequence, create a sequence from the
    			// next value.
    			id value = valuesSeq.head;
    
    			if (value == nil) {
    				// We've exhausted all the sequences.
    				stop = YES;
    				return nil;
    			}
    
    			current = (id)bindBlock(value, &stop);
    			if (current == nil) {
    				stop = YES;
    				return nil;
    			}
    
    			valuesSeq = valuesSeq.tail;
    		}
    
    		NSCAssert([current isKindOfClass:RACSequence.class], @"-bind: block returned an object that is not a sequence: %@", current);
    		return nil;
    	} headBlock:^(id _) {
    		return current.head;
    	} tailBlock:^ id (id _) {
    		if (stop) return nil;
    
    		return [valuesSeq bind:bindBlock passingThroughValuesFromSequence:current.tail];
    	}];
    
    	sequence.name = self.name;
    	return sequence;
    }
因为`RACDynamicSequence`不管是先调用`head`还是`tail`,都会先调用`dependencyBlock`,所以看下`dependencyBlock`的定义。

`dependencyBlock`中首先判断了`current.head`,也就是`passthroughSequence.head`,而`passthroughSequence`是方法的参数之一。由于`bind:`方法内部实现可以知道`passthroughSequence`可以为`nil`,所以下面就分情况分析：
* `passthroughSequence`为`nil`。`current.head`为`nil`,进行`while`循环，然后`id value = valuesSeq.head;`获取源序列`self`的`head`，通过`current = (id)bindBlock(value, &stop);`获取一个新的序列，此时出现分支：
    * 如果此时`current`不存在就会终止`while`循环，最终返回`nil`,这时`headBlock`获取的值也为`nil`，`tailBlock`也会获取到`nil`，所以这种情况就返回一个空序列。
    * 如果此时`current`存在，`valuesSeq`就会取源序列的`tail`，然后进行`while`循环的检测，还是分支：
        * `current.head`存在，`headBlock`返回`current.head`，`tailBlock`对源序列的`tail`调用`bind:passingThroughValuesFromSequence:`函数进行同样的处理。
        * `current.head`不存在，继续进行`while`循环。
    
    所以这种情况下就是对源序列的`value`通过`bindBlock`做处理，得到新的值，如果新的值也是序列，就获取新的序列的值。
* `passthroughSequence`不为`nil`。同样先进行`while`循环，此时`current.head`出现分支：
    * 如果为`nil`，跟上面步骤一样。
    * 如果不为`nil`，直接返回`nil`。然后`headBlock`获取到`passthroughSequence`的`head`,`tailBlock`通过源序列递归调用`bind:passingThroughValuesFromSequence:`继续进行。
    
    所以这种情况先是获取`passthroughSequence`的值，然后对源序列处理，通过`bindBlock`对源序列的值做处理得到新的值。

测试用例：

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

##### 上面就是对`RACDynamicSequence`的分析以及对`bind:`方法的重分析，后面会继续分析`RACSequence`的子类。
