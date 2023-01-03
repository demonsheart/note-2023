/// https://www.jianshu.com/p/001ff0dd3c30

// MARK: Context
enum MyResult<T> {
    case success(T)
    case failure(Error)
}

// MARK: Functor
extension MyResult {
    // Functor: Context(结果值) = map(Context(初始值), 运算函数)
    func map<O>(_ mapper: (T) -> O) -> MyResult<O> {
        switch self {
        case .failure(let err):
            return .failure(err)
        case .success(let val):
            return .success(mapper(val))
        }
    }
}


// 运算符定义
precedencegroup ChainingPrecedence {
    associativity: left
    higherThan: TernaryPrecedence
}

infix operator <^>: ChainingPrecedence

func <^><T, O>(lhs: (T) -> O, rhs: MyResult<T>) -> MyResult<O> {
    return rhs.map(lhs)
}

// test
func double(_ val: Int) -> Int {
    return 2 * val
}

//let a: MyResult<Int> = .success(2)
//let b = double <^> a


// MARK: Applicative
extension MyResult {
    // Applicative: Context(结果值) = apply(Context(初始值), Context(运算函数))
    func apply<O>(_ mapper: MyResult<(T) -> O>) -> MyResult<O> {
        switch mapper {
        case .failure(let err):
            return .failure(err)
        case .success(let fn):
            return self.map(fn)
        }
    }
}

infix operator <*>: ChainingPrecedence

func <*><T, O>(lhs: MyResult<(T) -> O>, rhs: MyResult<T>) -> MyResult<O> {
    return rhs.apply(lhs)
}

let fn: MyResult<(Int) -> Int> = .success(double)
let a: MyResult<Int> = .success(2)
let b = fn <*> a


// MARK: Monad
extension MyResult {
    // flatMap function :: 值A -> Context(值B)
    func flatMap<O>(_ mapper: (T) -> MyResult<O>) -> MyResult<O> {
        switch self {
        case .failure(let err):
            return .failure(err)
        case .success(let val):
            return mapper(val)
        }
    }
}

infix operator >>- : ChainingPrecedence

func >>-<T, O>(lhs: MyResult<T>, rhs: (T) -> MyResult<O>) -> MyResult<O> {
    return lhs.flatMap(rhs)
}

/*
// A代表从数据库查找数据的条件的类型
// B代表期望数据库返回结果的类型
func fetchFromDatabase(conditions: A) -> Result<B> { ... }

// B类型作为网络请求的参数类型发起网络请求
// 获取到的数据为C类型，可能是原始字符串或者是二进制
func requestNetwork(parameters: B) -> Result<C> { ... }

// 将获取到的原始数据类型转换成JSON数据
func dataToJSON(data: C) -> Result<JSON> { ... }

// 将JSON进行解析输出实体
func parse(json: JSON) -> Result<Entity> { ... }

// Monad优雅实现了链式调用
let entityResult = fetchFromDatabase(conditions: XXX) >>- requestNetwork >>- dataToJSON >>- parse
*/


