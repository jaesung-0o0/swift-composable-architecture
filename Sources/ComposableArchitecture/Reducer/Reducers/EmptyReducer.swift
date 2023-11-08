/// 아무것도 하지 않는 리듀서.
///
/// `EmptyReducer` 리듀서 자체는 딱히 유용하지 않지만, 리듀서들을 들고있는 API 의 placeholder로 사용할 수 있습니다.
public struct EmptyReducer<State, Action>: Reducer {
    /// 아무것도 하지 않는 리듀서를 생성합니다.
    @inlinable
    public init() {
        self.init(internal: ())
    }
    
    @usableFromInline
    init(internal: Void) {}
    
    /// 즉각 `.none` 을 리턴합니다.
    ///
    /// - Note: ``Reducer/reduce(into:action:)-1t2ri`` 프로토콜 메소드를 구현한 것입니다.
    @inlinable
    public func reduce(into _: inout State, action _: Action) -> Effect<Action> {
        .none
    }
}
