//: [Previous](@previous)
/// https://www.jianshu.com/p/b35e6e634df4


// MARK: - Optional monad
extension Optional {
    // bind 进行Monad的包装
    func bind<O>(_ f: (Wrapped) -> Optional<O>) -> Optional<O> {
        switch self {
        case .none:
            return .none
        case .some(let v):
            return f(v)
        }
    }
}

precedencegroup Bind {
    associativity: left
    higherThan: DefaultPrecedence
}

infix operator >>- : Bind

func >>-<L, R>(lhs: L?, rhs: (L) -> R?) -> R? {
    return lhs.bind(rhs)
}

// 可以认为是接收两个参数的函数的柯里化形式
// 除法，若除数为0，返回nil
// 方法类型:
//    A           B          C
// (Double) -> (Double) -> Double?
// 用B除以A
func divide(_ num: Double) -> (Double) -> Double? {
    return {
        guard num != 0 else { return nil }
        return $0 / num
    }
}

let ret = divide(2)(16) >>- divide(3) >>- divide(2) // 1.33333333...
// 可以写成
// let ret = Optional.some(16) >>- divide(2) >>- divide(3) >>- divide(2)

let ret2 = Optional.some(16) >>- divide(2) >>- divide(0) >>- divide(2) // nil



// MARK: - Either Monad --- 更精细化的Result Monad
enum Either<L, R> {
    case left(L)
    case right(R)
}

extension Either {
    static func ret(_ data: R) -> Either<L, R> {
        return .right(data)
    }
    
    // R -> O
    func bind<O>(_ f: (R) -> Either<L, O>) -> Either<L, O> {
        switch self {
        case .left(let l):
            return .left(l)
        case .right(let r):
            return f(r)
        }
    }
}

//// 注意这里的L L表示不可变的上下文类型
//func >>- <L, R, O> (lhs: Either<L, R>, f: (R) -> Either<L, O>) -> Either<L, O> {
//    return lhs.bind(f)
//}

/*
 Either为枚举类型，接收两个泛型参数，它表示在某个状态时，数据要么是在left中，要么是在right中。
 由于Monad要求所实现的类型需要具备一个泛型参数，因为在进行bind操作时可能会对数据类型进行转换，但是上下文所包含的数据类型是不会改变的，所以这里我们将泛型参数L用于上下文所包含的数据类型，R则作为值的类型。

 什么是上下文所包含的数据类型，什么是值的类型？
 Result monad中有一个数据泛型，代表里面的数据类型。某次运算成功是，则返回这个类型的数据，若运算失败，则会返回一个Error类型。我们可以把Error类型看成是上下文中包含的数据类型，它在一系列运算中是不可变的，因为Result需要靠它来记录失败的信息，若某次运算这个类型突然变成Int，那么整个上下文将失去原本的意义。所以，若Either monad作为Result monad般地工作，我们必须固定好一个上下文包含的类型，这个类型在一系列的运算中都不会改变，而值的类型是可以改变的。
 运算符>>-的签名可以很清晰地看到这种类型约束：接收的Either参数跟后面返回的Either它们的左边泛型参数都为L，而右边泛型参数可以随着接收的函数而相应进行改变(R -> O)。

 用Either monad来作为Result monad般工作，可以细化错误信息的类型。在Result monad中，错误信息都是用Error类型的实例来携带，而我们使用Either monad，可以根据我们的需要拟定不同的错误类型。如我们有两个模块，模块一表示错误的类型为ErrorOne，模块二则为ErrorTwo，我们就可以定义两个Either monad来分别作用于两个模块：
 
 typealias EitherOne<T> = Either<ErrorOne, T>
 typealias EitherTwo<T> = Either<ErrorTwo, T>
 */


// MARK: - Writer Monad --- 记录档案

// 单位半群协议
protocol Monoid {
    typealias T = Self
    static var mEmpty: T { get } // 单位元
    func mAppend(_ next: T) -> T // 相应的二元运算
}


// eg1: 整数加法半群
struct Sum {
    let num: Int
}

extension Sum: Monoid {
    static var mEmpty: Sum {
        return Sum(num: 0)
    }
    
    func mAppend(_ next: Sum) -> Sum {
        return Sum(num: num + next.num)
    }
}

/// 我们使用Sum来表示上面例子中的单位半群。为什么不直接使用Int来实现Monoid，非要对其再包装多一层呢？
/// 因为Int还可以实现其他的单位半群
/// eg2: 整数乘法半群
struct Product {
    let num: Int
}

extension Product: Monoid {
    static var mEmpty: Product {
        return Product(num: 1)
    }

    func mAppend(_ next: Product) -> Product {
        return Product(num: num * next.num)
    }
}

// eg3 & eg4 ALL Any半群
struct All {
    let bool: Bool
}

extension All: Monoid {
    static var mEmpty: All {
        return All(bool: true)
    }

    func mAppend(_ next: All) -> All {
        return All(bool: bool && next.bool)
    }
}

struct `Any` {
    let bool: Bool
}

extension `Any`: Monoid {
    static var mEmpty: `Any` {
        return `Any`(bool: true)
    }

    func mAppend(_ next: `Any`) -> `Any` {
        return `Any`(bool: bool || next.bool)
    }
}

// 当我们要判断一组布尔值是否都为真或者是否存在真时，我们就可以利用All或Any monoid的特性:
let values = [true, false, true, false]

let result1 = values.map(`Any`.init)
    .reduce(`Any`.mEmpty) { $0.mAppend($1) }.bool // true

let result2 = values.map(All.init)
    .reduce(All.mEmpty) { $0.mAppend($1) }.bool // false


// Writer monad 的实现
struct Writer<W, T> where W: Monoid {
    let data: T
    let record: W
}

extension Writer{
    // 最小上下文
    static func ret(_ data: T) -> Writer<W, T> {
        return Writer(data: data, record: W.mEmpty)
    }

    // data处理 并通过mAppend记录过程
    func bind<O>(_ f: (T) -> Writer<W, O>) -> Writer<W, O> {
        let newM = f(data)
        let newData = newM.data
        let newW = newM.record
        return Writer<W, O>(data: newData, record: record.mAppend(newW))
    }
}

infix operator <*> : Bind

func <*> <L, R, W>(lhs: Writer<W, L>, rhs: (L) -> Writer<W, R>) -> Writer<W, R> where W: Monoid {
    return lhs.bind(rhs)
}

// Writer Monad Demo:
extension String: Monoid {
    static var mEmpty: String {
        return ""
    }

    func mAppend(_ next: String) -> String {
        return self + next
    }
}

typealias MWriter = Writer<String, Double>

// 加减乘除 都是接收两个参数的函数的柯里化形式

func add(_ num: Double) -> (Double) -> MWriter {
    return { MWriter(data: $0 + num, record: "加上\(num) ") }
}

func subtract(_ num: Double) -> (Double) -> MWriter {
    return { MWriter(data: $0 - num, record: "减去\(num) ") }
}

func multiply(_ num: Double) -> (Double) -> MWriter {
    return { MWriter(data: $0 * num, record: "乘以\(num) ") }
}

func divide(_ num: Double) -> (Double) -> MWriter {
    return { MWriter(data: $0 / num, record: "除以\(num) ") }
}

// test
let resultW = MWriter.ret(1) <*> add(3) <*> multiply(5) <*> subtract(6) <*> divide(7)

let resultD = resultW.data // 2.0

let resultRecord = resultW.record // "加上3.0 乘以5.0 减去6.0 除以7.0"


// State Monad不做要求

//: [Next](@next)
