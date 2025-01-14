/// 리듀서들을 순차적으로 실행시켜 하나의 리듀서로 결합시키고 이펙트들을 머지하기 위한 `resultBuilder`.
/// 
/// ``Reducer``를 채택하고 ``Reducer/body-swift.property`` 프로퍼티를 구현할 때 리듀서 빌더를 마주하는 것은 가장 흔하다.
///
/// - Note: 리듀서 빌더 컨텍스트로 가는 진입점에 대해서는 ``CombineReducers``을 보시오.
@resultBuilder
public enum ReducerBuilder<State, Action> {
    @inlinable
    public static func buildArray<R: Reducer>(_ reducers: [R]) -> _SequenceMany<R>
    where R.State == State, R.Action == Action {
        _SequenceMany(reducers: reducers)
    }
    
    @inlinable
    public static func buildBlock() -> EmptyReducer<State, Action> {
        EmptyReducer()
    }
    
    @inlinable
    public static func buildBlock<R: Reducer>(_ reducer: R) -> R
    where R.State == State, R.Action == Action {
        reducer
    }
    
    @inlinable
    public static func buildEither<R0: Reducer, R1: Reducer>(
        first reducer: R0
    ) -> _Conditional<R0, R1>
    where R0.State == State, R0.Action == Action {
        .first(reducer)
    }
    
    @inlinable
    public static func buildEither<R0: Reducer, R1: Reducer>(
        second reducer: R1
    ) -> _Conditional<R0, R1>
    where R0.State == State, R0.Action == Action {
        .second(reducer)
    }
    
    @inlinable
    public static func buildExpression<R: Reducer>(_ expression: R) -> R
    where R.State == State, R.Action == Action {
        expression
    }
    
    @inlinable
    @_disfavoredOverload
    public static func buildExpression(
        _ expression: any Reducer<State, Action>
    ) -> Reduce<State, Action> {
        Reduce(expression)
    }
    
    @inlinable
    public static func buildFinalResult<R: Reducer>(_ reducer: R) -> R
    where R.State == State, R.Action == Action {
        reducer
    }
    
    @inlinable
    public static func buildLimitedAvailability<R: Reducer>(
        _ wrapped: R
    ) -> Reduce<State, Action>
    where R.State == State, R.Action == Action {
        Reduce(wrapped)
    }
    
    @inlinable
    public static func buildOptional<R: Reducer>(_ wrapped: R?) -> R?
    where R.State == State, R.Action == Action {
        wrapped
    }
    
    @inlinable
    public static func buildPartialBlock<R: Reducer>(
        first: R
    ) -> R
    where R.State == State, R.Action == Action {
        first
    }
    
    @inlinable
    public static func buildPartialBlock<R0: Reducer, R1: Reducer>(
        accumulated: R0, next: R1
    ) -> _Sequence<R0, R1>
    where R0.State == State, R0.Action == Action {
        _Sequence(accumulated, next)
    }
    
    public enum _Conditional<First: Reducer, Second: Reducer>: Reducer
    where
    First.State == Second.State,
    First.Action == Second.Action
    {
    case first(First)
    case second(Second)
        
        @inlinable
        public func reduce(into state: inout First.State, action: First.Action) -> Effect<
            First.Action
        > {
            switch self {
            case let .first(first):
                return first.reduce(into: &state, action: action)
                
            case let .second(second):
                return second.reduce(into: &state, action: action)
            }
        }
    }
    
    public struct _Sequence<R0: Reducer, R1: Reducer>: Reducer
    where R0.State == R1.State, R0.Action == R1.Action {
        @usableFromInline
        let r0: R0
        
        @usableFromInline
        let r1: R1
        
        @usableFromInline
        init(_ r0: R0, _ r1: R1) {
            self.r0 = r0
            self.r1 = r1
        }
        
        @inlinable
        public func reduce(into state: inout R0.State, action: R0.Action) -> Effect<R0.Action> {
            self.r0.reduce(into: &state, action: action)
                .merge(with: self.r1.reduce(into: &state, action: action))
        }
    }
    
    public struct _SequenceMany<Element: Reducer>: Reducer {
        @usableFromInline
        let reducers: [Element]
        
        @usableFromInline
        init(reducers: [Element]) {
            self.reducers = reducers
        }
        
        @inlinable
        public func reduce(
            into state: inout Element.State, action: Element.Action
        ) -> Effect<Element.Action> {
            self.reducers.reduce(.none) { $0.merge(with: $1.reduce(into: &state, action: action)) }
        }
    }
}
