import SwiftUI

/// 바인딩 액션을 전달 받을 때, 바인딩할 수 있는 상태(`BindableState`) 를 업데이트 하는 리듀서
///
/// 이 리듀서는 일반적으로 기능 리듀서의 ``Reducer/body-swift.property`` 안에서 구성되어야 합니다.
///
/// ```swift
/// struct Feature: Reducer {
///     struct State {
///         @BindingState var isOn = false
///         // More properties...
///     }
///     enum Action: BindableAction {
///         case binding(BindingAction<State>)
///         // More actions
///     }
///
///     var body: some ReducerOf<Self> {
///         BindingReducer()
///         Reduce { state, action in
///             // Your feature's logic...
///         }
///     }
/// }
/// ```
///
/// 이는 바인딩 로직이 기능의 로직보다 먼저 실행되게 합니다.
/// 예를 들어, 오직 바인딩 값이 세팅되고 나서 상태를 볼 수 있습니다.
/// 만약 바인딩 값이 세팅되기 전에 상태에 접근하고 싶다면, 다음과 같이 구성의 순서를 변경하면 됩니다.
///
/// ```swift
/// var body: some ReducerOf<Self> {
///     Reduce { state, action in
///         // Your feature's logic...
///     }
///     BindingReducer()
/// }
/// ```
///
/// 만약 기능의 리듀서 안에 ``BindingState`` 를 구성하는 것을 잊었다면, 
/// 바인딩 값을 세팅할 때 런타임시 쓰레드 경고를 야기할 수 있습니다.
public struct BindingReducer<State, Action, ViewAction: BindableAction>: Reducer
where State == ViewAction.State {
    @usableFromInline
    let toViewAction: (Action) -> ViewAction?
    
    /// 바인딩 액션을 전달 받을 때,
    /// 바인딩할 수 있는 상태(`BindableState`) 를 업데이트 하는 리듀서를 생성합니다.
    @inlinable
    public init() where Action == ViewAction {
        self.init(internal: { $0 })
    }
    
    @inlinable
    public init(action toViewAction: @escaping (_ action: Action) -> ViewAction?) {
        self.init(internal: toViewAction)
    }
    
    @usableFromInline
    init(internal toViewAction: @escaping (_ action: Action) -> ViewAction?) {
        self.toViewAction = toViewAction
    }
    
    @inlinable
    public func reduce(into state: inout State, action: Action) -> Effect<Action> {
        // ``BindableAction`` 으로 변환했을 때 여기서 `BindingAction<State>`으로 매핑한 값을 `bindingAction` 이라고 하자
        guard let bindingAction = self.toViewAction(action).flatMap(/ViewAction.binding)
        else { return .none }
        
        bindingAction.set(&state)
        return .none
    }
}
