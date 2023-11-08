/// 여러개의 리듀서를 하나의 리듀서로 결합합니다.
///
/// `CombineReducers` 는 ``ReducerBuilder``를 사용하여 수많은 리듀서를 결합할 수 있는 코드 블럭을 갖습니다.
///
/// 리듀서들을 그룹화하고 결과에 리듀서 modifier (예: `ifLet(_:action:)`) 를 적용하기에 유용합니다.
///
/// ```swift
/// var body: some Reducer<State, Action> {
///     CombineReducers {
///         ReducerA()
///         ReducerB()
///         ReducerC()
///     }
///     .ifLet(\.child, action: /Action.child)
/// }
/// ```
public struct CombineReducers<State, Action, Reducers: Reducer>: Reducer
where State == Reducers.State, Action == Reducers.Action {
    @usableFromInline
    let reducers: Reducers
    
    /// 빌드 블럭 안의 모든 리듀서를 하나로 결합한 새 리듀서를 생성합니다.
    ///
    /// - Note: 순차적으로 리듀서를 실행하고 Effect가 동시에 실행될 수 있도록 하나로 합칩니다. 자세한 내용은 ``Effect/merge(with:)`` 를 참고하십시오.
    ///
    /// - Parameter build: 리듀서 빌더
    @inlinable
    public init(
        @ReducerBuilder<State, Action> _ build: () -> Reducers
    ) {
        self.init(internal: build())
    }
    
    @usableFromInline
    init(internal reducers: Reducers) {
        self.reducers = reducers
    }
    
    /// ``CombineReducers`` 안에 `ReducerBuilder` 안의 리듀서들의 ``Reducer/reduce(into:action:)-1t2ri``를 순차적으로 호출하여 한번에 실행될 수 있도록 Effect 를 전부 합쳐서 리턴합니다.
    ///
    /// - Note: 순차적으로 리듀서를 실행하고 Effect가 동시에 실행될 수 있도록 하나로 합칩니다. 자세한 내용은 ``Effect/merge(with:)`` 를 참고하십시오.
    @inlinable
    public func reduce(
        into state: inout Reducers.State, action: Reducers.Action
    ) -> Effect<Reducers.Action> {
        self.reducers.reduce(into: &state, action: action)
    }
}
