extension Reducer {
    /// 리듀서가 상태의 값을 변화시킬 때 돌아가는 리듀서를 추가합니다.
    ///
    /// 이 오퍼레이터는 ``BindingReducer``가 ``BindingState``이 붙들고 있는 구조체에 변화를 주는 것과 같이,
    /// 값이 변할 때 추가 로직을 트리거하기 위해 사용합니다.
    ///
    /// ```swift
    /// struct Settings: Reducer {
    ///     struct State {
    ///         @BindingState var userSettings: UserSettings
    ///         // ...
    ///     }
    ///
    ///     enum Action: BindableAction {
    ///         case binding(BindingAction<State>)
    ///         //. ...
    ///     }
    ///
    ///     var body: some Reducer<State, Action> {
    ///         BindingReducer()
    ///             .onChange(
    ///                 of: { ($0.userSettings.isHapticFeedbackEnabled, $0.userSettings.isPushEnabled) },
    ///                 removeDuplicates: ==
    ///             ) { oldValue, newValue in
    ///                 Reduce { state, action in
    ///                     .run { send in
    ///                         // Persist new value...
    ///                     }
    ///                 }
    ///             }
    ///     }
    /// }
    /// ```
    ///
    /// 값이 변할 때, 새 버전의 클로져가 불립니다.
    /// 그래서 **캡쳐된 값**은 관찰하는 값이 새 값을 갖는 시점부터 값을 가지게 됩니다.
    /// 시스템은 관찰하고 있는 값의 이전 값과 새로운 값을 클로져로 전달합니다.
    ///
    /// - Note: 리듀서에 `onChange(of:)`를 적용할 때 주의 하십시오. 이 오퍼레이터는 들어오는 모든 액션에 대해 `equatable` 검사를 추가합니다.
    /// ``BindingReducer``처럼 동일시 하기 쉬운 값들에 비해 리프 노드에 적용하는 것을 선호합니다. // 무슨말인지...
    ///
    /// - Parameters:
    ///   - toValue: 주어진 상태로 부터 값을 리턴하는 클로져.
    ///   - isDuplicate: 필터링을 위해 두 요소가 서로 동일한지 확인하는 클로져. 두번째 요소가 첫번째 요소와 동일하면 `true` 를 리턴하도록 해야합니다.
    ///   - reducer: 값이 변할 때 실행 될 리듀서 빌더 클로져.
    ///   - oldValue: 비교 검사에 실패한 이전 값.
    ///   - newValue: 비교 검사에 실패한 새로운 값.
    /// - Returns: 상태가 변할 때 로직을 수행하는 리듀서.
    @inlinable
    public func onChange<V, R: Reducer>(
        of toValue: @escaping (State) -> V,
        removeDuplicates isDuplicate: @escaping (V, V) -> Bool,
        @ReducerBuilder<State, Action> _ reducer: @escaping (_ oldValue: V, _ newValue: V) -> R
    ) -> _OnChangeReducer<Self, V, R> {
        // OnChangeReducer 객체 생성 및 리턴
        _OnChangeReducer(
            base: self,
            toValue: toValue,
            isDuplicate: isDuplicate, reducer: reducer
        )
    }
    
    /// 리듀서가 상태의 값을 바꿀 때 돌아가는 리듀서를 추가합니다.
    ///
    /// 이 오퍼레이터는 ``BindingReducer``가 ``BindingState``이 붙들고 있는 구조체에 변화를 주는 것과 같이,
    /// 값이 변할 때 추가 로직을 트리거하기 위해 사용합니다.
    ///
    /// ```swift
    /// struct Settings: Reducer {
    ///   struct State {
    ///     @BindingState var userSettings: UserSettings
    ///     // ...
    ///   }
    ///
    ///   enum Action: BindableAction {
    ///     case binding(BindingAction<State>)
    ///     // ...
    ///   }
    ///
    ///   var body: some Reducer<State, Action> {
    ///     BindingReducer()
    ///       .onChange(of: \.userSettings.isHapticFeedbackEnabled) { oldValue, newValue in
    ///         Reduce { state, action in
    ///           .run { send in
    ///             // Persist new value...
    ///           }
    ///         }
    ///       }
    ///   }
    /// }
    /// ```
    ///
    /// 값이 변할 때, 새 버전의 클로져가 불립니다. 
    /// 그래서 **캡쳐된 값**은 관찰하는 값이 새 값을 갖는 시점부터 값을 가지게 됩니다.
    /// 시스템은 관찰하고 있는 값의 이전 값과 새로운 값을 클로져로 전달합니다.
    ///
    /// - Note: 리듀서에 `onChange(of:)`를 적용할 때 주의 하십시오. 이 오퍼레이터는 들어오는 모든 액션에 대해 `equatable` 검사를 추가합니다.
    /// ``BindingReducer``처럼 동일시 하기 쉬운 값들에 비해 리프 노드에 적용하는 것을 선호합니다. // 무슨말인지...
    ///
    /// - Parameters:
    ///   - toValue: 주어진 상태로 부터 값을 리턴하는 클로져.
    ///   - reducer: 값이 변할 때 실행 될 리듀서 빌더 클로져.
    ///   - oldValue: 비교 검사에 실패한 이전 값.
    ///   - newValue: 비교 검사에 실패한 새로운 값.
    /// - Returns: 상태가 변할 때 로직을 수행하는 리듀서.
    @inlinable
    public func onChange<V: Equatable, R: Reducer>(
        of toValue: @escaping (State) -> V,
        @ReducerBuilder<State, Action> _ reducer: @escaping (_ oldValue: V, _ newValue: V) -> R
    ) -> _OnChangeReducer<Self, V, R> {
        // OnChangeReducer 객체 생성 및 리턴
        _OnChangeReducer(
            base: self,
            toValue: toValue,
            isDuplicate: ==, reducer: reducer
        )
    }
}

public struct _OnChangeReducer<Base: Reducer, Value, Body: Reducer>: Reducer
where Base.State == Body.State, Base.Action == Body.Action {
    @usableFromInline
    let base: Base
    
    @usableFromInline
    let toValue: (Base.State) -> Value
    
    @usableFromInline
    let isDuplicate: (Value, Value) -> Bool
    
    @usableFromInline
    let reducer: (Value, Value) -> Body
    
    @usableFromInline
    init(
        base: Base,
        toValue: @escaping (Base.State) -> Value,
        isDuplicate: @escaping (Value, Value) -> Bool,
        reducer: @escaping (Value, Value) -> Body
    ) {
        self.base = base
        self.toValue = toValue
        self.isDuplicate = isDuplicate
        self.reducer = reducer
    }
    
    @inlinable
    public func reduce(into state: inout Base.State, action: Base.Action) -> Effect<Base.Action> {
        let oldValue = toValue(state)
        let baseEffects = self.base.reduce(into: &state, action: action)
        let newValue = toValue(state)
        return isDuplicate(oldValue, newValue)
        ? baseEffects
        : .merge(
            baseEffects,
            self.reducer(oldValue, newValue)
                .reduce(into: &state, action: action)
        )
    }
}
