/// 현재 앱의 상태를 주어진 액션을 가지고 어떻게 다음 상태로 변경할 지를 묘사하는 프로토콜. 또한 나중에 Store에 의해 실행되어야 할 ``Effect``가 무엇인지 묘사하고 있습니다.
///
/// 이 프로토콜을 준수하여 도메인, 로직 그리고 기능에 대한 행동을 나타낼 수 있습니다. 도메인은 "상태" 와 "액션"으로 명시되며 각각 아래의 예시 코드처럼 중첩 타입(Nested type) 으로 표현됩니다.
///
/// ```swift
/// struct Feature: Reducer {
///   struct State {
///     var count = 0
///   }
///   enum Action {
///     case decrementButtonTapped
///     case incrementButtonTapped
///   }
///
///   // ...
/// }
/// ```
///
/// 시스템에 액션이 들어올 때 기능의 현재 상태를 변경하는 것을 통해 기능의 로직을 구현할 수 있습니다.
/// ``Reducer/reduce(into:action:)-1t2ri`` 프로토콜 메서드를 구현하여 이를 쉽게 구현할 수 있습니다.
///
/// ```swift
/// struct Feature: Reducer {
///   // ...
///
///   func reduce(into state: inout State, action: Action) -> Effect<Action> {
///     switch action {
///     case .decrementButtonTapped:
///       state.count -= 1
///       return .none
///
///     case .incrementButtonTapped:
///       state.count += 1
///       return .none
///     }
///   }
/// }
/// ```
///
/// `reduce` 메서드의 첫번째 의무는 주어진 액션에 따른 기능의 현재 상태를 변경하는 것입니다.
/// 두번째 의무는 비동기로 실행되어 데이터를 시스템으로 다시 전달하는 `Effect` 를 리턴하는 것입니다.
/// 현재 `Feature`는 어떠한 `Effect` 들도 필요하지 않아서 ``Effect/none`` 을 리턴하고 있습니다.
///
/// 만약 기능이 이펙트 있는 작업을 할 필요가 있다면, 더 많은 작업이 필요합니다.
/// 예를 들어, 타이머를 시작하고 멈출 수 있는 능력을 가진 기능이 있다고 가정해보겠습니다. 그리고 타이머의 초심이 움직일 때마다 `count` 가 증가한다고 했을 때, 다음과 같이 작성할 수 있습니다.
///
/// ```swift
/// struct Feature: Reducer {
///   struct State {
///     var count = 0
///   }
///   enum Action {
///     case decrementButtonTapped
///     case incrementButtonTapped
///     case startTimerButtonTapped
///     case stopTimerButtonTapped
///     case timerTick
///   }
///   enum CancelID { case timer }
///
///   func reduce(into state: inout State, action: Action) -> Effect<Action> {
///     switch action {
///     case .decrementButtonTapped:
///       state.count -= 1
///       return .none
///
///     case .incrementButtonTapped:
///       state.count += 1
///       return .none
///
///     case .startTimerButtonTapped:
///       return .run { send in
///         while true {
///           try await Task.sleep(for: .seconds(1))
///           await send(.timerTick)
///         }
///       }
///       .cancellable(CancelID.timer)
///
///     case .stopTimerButtonTapped:
///       return .cancel(CancelID.timer)
///
///     case .timerTick:
///       state.count += 1
///       return .none
///     }
///   }
/// }
/// ```
///
/// - Note:이 예제는 `Task.sleep`을 사용하여 무한 루프를 실행하여 타이머를 모방하고 있습니다. 이 방법은 간단하지만, 작은 불완전함들이 누적될 수 있어 정확성이 떨어집니다. 대신 기능에 시계를 주입하여 `timer` 메서드를 사용할 수 있도록 하는 것이 더 좋습니다. 더 자세한 정보는 <doc:DependencyManagement>와 <doc:Testing> 글을 참고하십시오.
///
/// ``Reducer``를 채택하여 기능을 구현하는 것의 기본 단계입니다. 리듀서를 정의하는 것에는 두가지 방법이 있습니다.
///
///   1. 위에서 처럼 ``Action`` 이 시스템에 전달될 때마다 변경할 수 있는 앱의 ``State``에 직접 접근하고 바깥 세계와 통신하고 추가적인 ``Action``을 다시 시스템으로 전달하는 ``Effect`` 를 반환할 수 있는 ``reduce(into:action:)-1t2ri`` 메서드를 구현하거나
///
///   2. 하나 이상의 리듀서를 서로 결합하는 ``body-swift.property`` 프로퍼티를 구현할 수 있습니다.
///
/// 이 중 하나는 반드시 구현되어야 합니다. 만약 둘 다 구현한다면, ``Store``는 ``reduce(into:action:)-1t2ri``만 호출할 것입니다.
/// 다른 리듀서들을 하나의 body에 조합하고, 기능에 레이어로 추가되어야 할 추가적인 비즈니스 로직이 있다면,
/// ``Reduce``와 함께 `body`에 이 로직을 도입하는 것으로 대신하십시오.
///
/// ```swift
/// var body: some Reducer<State, Action> {
///   Reduce { state, action in
///     // extra logic
///   }
///   Activity()
///   Profile()
///   Settings()
/// }
/// ```
///
/// …또는 추가적인 로직을 ``Reduce`` 로 감싼 메서드로 옮길 수 있습니다.
///
/// ```swift
/// var body: some Reducer<State, Action> {
///   Reduce(self.core)
///   Activity()
///   Profile()
///   Settings()
/// }
///
/// func core(state: inout State, action: Action) -> Effect<Action> {
///   // extra logic
/// }
/// ```
///
/// 만약 기존의 리듀서를 변형하는 커스텀 리듀서 수행자를 구현하고 있다면, 반드시 ``body-swift.property``가 아니라 항상 ``reduce(into:action:)-1t2ri``를 호출하십시오.
/// 예를 들어, `logActions()` 는 리듀서로 전달되는 모든 액션을 로깅하는 수행자 입니다.
///
/// ```swift
/// extension Reducer {
///   func logActions() -> some Reducer<State, Action> {
///     Reduce { state, action in
///       print("Received action: \(action)")
///       return self.reduce(into: &state, action: action)
///     }
///   }
/// }
/// ```
///
public protocol Reducer<State, Action> {
    /// 리듀서의 현재 상태를 갖고 있는 타입.
    associatedtype State
    
    /// 리듀서의 ``State`` 를 변화시키고(또는 변화시키거나) 바깥 세계와 통신하는 사이드 이펙트(``Efect``)를 시작하는 액션들을 전부 갖고 있는 타입.
    associatedtype Action
    
    // NB: Xcode 가 `var body: Never` 보다 `var body: Body` 로 자동완성하도록 하려면, typealias 를 사용해야합니다.
    // 이 해결책은 라이브러리 에볼루션과 호환되지 않기 때문에 릴리스 외에서 컴파일하도록 했습니다.
#if DEBUG
    associatedtype _Body
    
    /// 현재 리듀서의 body 를 나타내는 타입. // 6f25w
    ///
    /// ``body-swift.property``를 구현하여 커스텀 리듀서를 생성할 때, 스위프트는 리턴 값으로 부터 현재의 타입을 추론합니다.
    ///
    /// 만약 ``reduce(into:action:)-1t2ri`` 를 구현하여 커스텀 리듀서를 생성했다면, 스위프트는 현재 타입을 `Never` 로 추론합니다.
    typealias Body = _Body
#else
    /// 현재 리듀서의 body 를 나타내는 타입.
    ///
    /// ``body-swift.property``를 구현하여 커스텀 리듀서를 생성할 때, 스위프트는 리턴 값으로 부터 현재의 타입을 추론합니다.
    ///
    /// 만약 ``reduce(into:action:)-1t2ri`` 를 구현하여 커스텀 리듀서를 생성했다면, 스위프트는 현재 타입을 `Never` 로 추론합니다.
    associatedtype Body
#endif
    
    /// 리듀서의 현재 상태를 다음 상태로 변경합니다.
    ///
    /// "원시적인" 리듀서 또는 자식이 없는 리프 노드 기능에서 돌아가는 리듀서를 구현합니다.
    /// 다른 리듀서의 로직을 결합하여 리듀서를 정의하려는 경우, ``body-swift.property`` 를 대신 구현하십시오.
    ///
    /// - Parameters:
    ///   - state: 리듀서의 현재 상태
    ///   - action: 리듀서의 상태를 변화시키고(또는 변화시키거나) 바깥 세계와 통신하는 사이드 이펙트를 시작하는 액션.
    /// - Returns: 바깥 세계와 통신할 수 있고 액션을 다시 시스템으로 전달할 수 있는 `Effect`
    func reduce(into state: inout State, action: Action) -> Effect<Action>
    
    /// 다른 리듀서들과 결합한 리듀서의 컨텐츠와 행동.
    ///
    /// 이 요구사항은 다른 리듀서들을 서로 통합시키고 싶을 때 준수하십시오.
    ///
    /// - Warning: 절대로 이 프로퍼티를 직접 호출하지 마십시오.
    ///
    /// - Important: 만약 리듀서가 ``reduce(into:action:)-1t2ri`` 메서드를 구현하고 있다면, 이 프로퍼티 보다 우선권을 갖게 되어 ``Store``는 ``reduce(into:action:)-1t2ri``만 호출합니다. 만약 리듀서가 다른 리듀서들을 하나의 body에 모으고 시스템에 레이어로 추가할 추가적인 비즈니스 로직을 갖는다면, body 에 ``Reduce``또는 별도로 할당된 채택(conformance)과 함께 이 로직을 대신 도입하십시오.
    @ReducerBuilder<State, Action>
    var body: Body { get }
}

extension Reducer where Body == Never {
    /// 존재하지 않는 body
    ///
    /// - Warning: 이 프로퍼티를 직접 호출하지 마십시오. 직접 호출 시 런타임에 Fatal error를 발생시킵니다.
    @_transparent
    public var body: Body {
        fatalError(
      """
      '\(Self.self)' 가 body를 갖고 잇지 않습니다. …
      
      'body'가 존재하지 않을 수도 있기 때문에 어떠한 경우에도 직접 접근하지 마십시오. Reducer를 실행하고 싶다면 'Reducer.reduce(into:action:)'를 대신 호출하십시오.
      """
        )
    }
}

extension Reducer where Body: Reducer, Body.State == State, Body.Action == Action {
    /// ``Body-40qdd``내 ``reduce(into:action:)-1t2ri``의 구현부를 호출합니다.
    @inlinable
    public func reduce(
        into state: inout Body.State, action: Body.Action
    ) -> Effect<Body.Action> {
        self.body.reduce(into: &state, action: action)
    }
}

// NB: 다음의 버그로 인해 Swift 5.7.1 이상에서만 가능합니다.
//     https://github.com/apple/swift/issues/60550
#if swift(>=5.7.1)
/// ``Reducer`` 준수 편의를 위한 `typealias`.
///
/// 이는 ``Reducer`` 의 `body`를 다음과 같이 명시할 수 있도록 해줍니다.
///
/// ```swift
/// var body: some ReducerOf<Self> { // Reducer<State, Action>
///   // ...
/// }
/// ```
public typealias ReducerOf<R: Reducer> = Reducer<R.State, R.Action>
#endif
