/// 주어진 `reduce` 함수를 호출하는 타입이 지워진 리듀서
///
/// ``Reduce``는 ``Reducer``를 채택한 새로운 타입을 도입하는 것에 대한 부담 없이 로직을 리듀서 트리에 주입하기에 유용합니다.
public struct Reduce<State, Action>: Reducer {
    /// ``reduce(into:action:)``이 호출되면 불리는 클로져.
    @usableFromInline
    let reduce: (inout State, Action) -> Effect<Action>
    
    @usableFromInline
    init(
        internal reduce: @escaping (inout State, Action) -> Effect<Action>
    ) {
        self.reduce = reduce
    }
    
    /// `reduce` 함수와 함께 리듀서를 초기화 합니다.
    ///
    /// - Parameter reduce: ``reduce(into:action:)``이 호출되면 불리는 함수
    @inlinable
    public init(
        _ reduce: @escaping (_ state: inout State, _ action: Action) -> Effect<Action>
    ) {
        self.init(internal: reduce)
    }
    
    /// 타입이 지워진 리듀서
    ///
    /// - Parameter reducer: ``reduce(into:action:)``이 호출될 때 불리는 리듀서
    @inlinable
    public init<R: Reducer>(_ reducer: R) where R.State == State, R.Action == Action {
        self.init(internal: reducer.reduce)
    }
    
    @inlinable
    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        self.reduce(&state, action)
    }
}
