//: [Previous](@previous)
/// https://www.jianshu.com/p/917474eda91c

//enum Event<E, R> where R: Error {
//    case next(E)
//    case error(R)
//}

// 简化版 event
enum Event<E> {
    case next(E)
    case error(Error)
}

// MARK: - Protocol - Observer
protocol ObserverType {
    associatedtype E
    
    var action: (Event<E>) -> () { get }
    
    init(_ action: @escaping (Event<E>) -> ())
    
    func send(_ event: Event<E>)
}

extension ObserverType {
    /*通过send方法，Observer可以发送出事件，而通过实现一个闭包并将其传入到Observer的构造器中，我们就可以监听到Observer发出的事件。*/
    func send(_ event: Event<E>) {
        action(event)
    }
    
    func sendNext(_ value: E) {
        send(.next(value))
    }
    
    func sendError(_ error: Error) {
        send(.error(error))
    }
}

// MARK: - Class - Observer
final class Observer<Element>: ObserverType {
    typealias E = Element
    
    let action: (Event<E>) -> ()
    
    init(_ action: @escaping (Event<E>) -> ()) {
        self.action = action
    }
}


// MARK: - Protocol - Signal
protocol SignalType {
    associatedtype E
    
    func subscribe(_ observer: Observer<E>)
}

extension SignalType {
    func subscribe(next: ((E) -> ())? = nil, error: ((Error) -> ())? = nil) {
        let observer = Observer<E> { event in
            switch event {
            case .error(let e):
                error?(e)
            case .next(let element):
                next?(element)
            }
        }
        subscribe(observer)
    }
}


// MARK: - Class - Signal
final class Signal<Element>: SignalType {
    typealias E = Element

    /// 它的作用是为了让Signal实现Monad return函数  Monad return函数就是将一个基本的数据包裹在一个Monad上下文中
    private var value: E?
    /// 当我们调用subscribe(_:)方法时就将传入的参数赋予给这个成员
    private var observer: Observer<E>?

    init(value: E) {
        self.value = value
    }
    
    /// 内部调用了针对于value初始化的Signal构造器init(value: E)，将一个基本的数据赋予给了value成员属性
    static func `return`(_ value: E) -> Signal<E> {
        return Signal(value: value)
    }
    
    /// 这个方法接受一个闭包，闭包里面做的，就是进行某些运算处理逻辑或事件监听，如网络请求、事件监听等。
    /// 闭包带有一个Observer类型的参数，当闭包中的运算处理逻辑完成或者接收到事件回调时，就利用这个Observer发送事件
    init(_ creater: (Observer<E>) -> ()) {
        let observer = Observer(action) // 注意这里是新建的Observer 绑定了内部self.observer.action事件 从而实现event的触发传递
        creater(observer) // 外部处理数据 同时传递的observer还可以发送新事件
        /*
         首先将Signal自己的action(_:)方法作为参数传入Observer的构造器从而创建了一个Observer实例
         这里的设计比较巧妙，我们在构造器闭包类型参数creater中进行处理逻辑或事件监听，若得到结果，
         将使用闭包中的Observer参数发送事件，事件将会传递到订阅了这个Signal的订阅者中(即self.observer)，从而触发相关回调
         */
        
        // 这里设计成两个Observer的原因是 新的Observer通过pipe方法提供给外界发送事件
    }

    /// 指使成员属性observer将自己接收到的事件参数转发出去。
    func action(_ event: Event<E>) {
        observer?.action(event)
    }

    /// 首先对value做非空判断，若此时value存在，传入的observer参数将发送关联了value的next事件，
    /// 这样做是为了保证整个Signal符合Monad特性。
    func subscribe(_ observer: Observer<E>) {
        if let value = value { observer.sendNext(value) }
        self.observer = observer
    }

    /// 第一项为Observer，我们可以利用它来发送事件，第二项为Signal，我们可以通过它来订阅事件
    static func pipe() -> (Observer<E>, Signal<E>) {
        var observer: Observer<E>!
        let signal = Signal<E> {
            observer = $0 // 拿到init(_ creater: (Observer<E>) -> ())中新建的Observer 可以用它发送事件
        }
        return (observer, signal)
    }
    
    /*
     对于我们使用pipe函数获取到的Observer，其内部的action成员属性来自于Signal的action(_:)方法，这个方法引用到了Signal中的成员属性。由此，我们可以推出此时Observer对Signal具有引用的关系，Observer不释放，Signal也会一直保留。
     */
}


// MARK: - Monad - Signal
extension Signal {
    func bind<O>(_ f: @escaping (E) -> Signal<O>) -> Signal<O> {
        // self 是旧的Signal<E>； 现在需要返回一个新的Signal<O>
        return Signal<O> { [weak self] observer in
            // 重新订阅产生新的Observer
            self?.subscribe(next: { element in
                /// 产生新事件则需要调用f处理，产生一个中间Signal，
                /// 再通过对这个中间层Signal进行订阅，将事件传递到新的Signal中
                f(element).subscribe(observer)
            }, error: { error in
                // 出错则直接提取传递到新的observer
                observer.sendError(error)
            })
        }
    }

    func flatMap<O>(_ f: @escaping (E) -> Signal<O>) -> Signal<O> {
        return bind(f)
    }
    
    /// map方法的实现十分简单，通过在内部调用bind方法，并将最终数据通过return包裹进Signal上下文中
    func map<O>(_ f: @escaping (E) -> O) -> Signal<O> {
        return bind { element in
            return Signal<O>.return(f(element))
        }
    }
}


// 通过creater闭包构建Signal
import Dispatch
let mSignal: Signal<Int> = Signal { observer in
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        observer.sendNext(1)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        observer.sendNext(2)
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        observer.sendNext(3)

    }
}

mSignal.map { $0 + 1 }.map { $0 * 3 }.map { "The number is \($0)" }.subscribe(next: { numString in
    print(numString)
})

/*
 The number is 6
 The number is 9
 The number is 12
 */



// 通过pipe构建Signal
let (mObserver, mSignal2) = Signal<Int>.pipe()

mSignal2.map { $0 * 3 }.map { $0 + 1 }.map { "The value is \($0)" }.subscribe(next: { value in
    print(value)
})

DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
    mObserver.sendNext(3)
}

DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    mObserver.sendNext(2)
}

DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
    mObserver.sendNext(1)
}

/*
 The value is 10
 The value is 7
 The value is 4
 */

//: [Next](@next)
