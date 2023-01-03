//: [Previous](@previous)

// MARK: Optional monad
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


//: [Next](@next)
