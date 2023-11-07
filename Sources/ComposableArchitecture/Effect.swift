import Combine
import Foundation
import SwiftUI
import XCTestDynamicOverlay

public struct Effect<Action> {
    @usableFromInline
    enum Operation {
        case none
        case publisher(AnyPublisher<Action, Never>)
        case run(TaskPriority? = nil, @Sendable (_ send: Send<Action>) async -> Void)
    }
    
    @usableFromInline
    let operation: Operation
    
    @usableFromInline
    init(operation: Operation) {
        self.operation = operation
    }
}

/// `Reducer` 만 가지고 더 간단하게 `Effect` 객체를 생성하기 위한 `typealias`.
///
/// ```swift
/// let effect: EffectOf<Feature>
/// ```
public typealias EffectOf<R: Reducer> = Effect<R.Action>


// MARK: - Effect 만들기

extension Effect {
    /// 아무것도 하지않고 즉각 종료하는 `Effect` 
    /// 
    /// 딱히 더 할건 없지만 `Effect` 를 리턴해야하는 상황에서 쓰면 됩니다.
    @inlinable
    public static var none: Self {
        Self(operation: .none)
    }
    
    /// 비동기의 단위 작업을 감싼 `Effect` 를 제공합니다. 비동기 작업은 횟수 제한없이 액션을 방출합니다.
    ///
    /// ```swift
    /// case .startButtonTapped:
    ///   return .run { send in
    ///     for await event in self.events() {
    ///       send(.event(event))
    ///     }
    ///   }
    /// ```
    ///
    /// - Note: `run` 클로져에서 전달하는 `send` 인자에 대한 사용법은 ``Send`` 를 참고하세요
    ///
    /// 클로져는 `throw` 를 허용하지만 취소되지 않는 에러가 던져지면 런타임 경고가 생길 것 입니다. 또한 테스트 실패를 야기할 수도 있습니다. 취소되지 않는 에러를 잡기 위해서는 `catch` trailing 클로져를 사용하세요.
    ///
    /// - Parameters:
    ///   - priority: 작업의 우선순위. `nil` 이면 우선순위는 `Task.currentPriority` 입니다.
    ///   - operation: 실행하고자 하는 오퍼레이션. `send` 인자가 전달됩니다.
    ///   - catch: 오퍼레이션이 `CancellationError` 말고 다른 에러를 던지면 호출되는 에러핸들러.
    /// - Returns: 주어진 비동기 작업을 갖고 있는 `Effect` 객체.
    public static func run(
        priority: TaskPriority? = nil,
        operation: @escaping @Sendable (_ send: Send<Action>) async throws -> Void,
        catch handler: (@Sendable (_ error: Error, _ send: Send<Action>) async -> Void)? = nil,
        fileID: StaticString = #fileID,
        line: UInt = #line
    ) -> Self {
        /// 현재 디펜던시들을 escaping 컨텍스트로 전파합니다.
        withEscapedDependencies { escaped in
            Self(
                operation: .run(priority) { send in
                    await escaped.yield {
                        do {
                            try await operation(send)
                        } catch is CancellationError {
                            return
                        } catch {
                            guard let handler = handler else {
#if DEBUG
                                var errorDump = ""
                                customDump(error, to: &errorDump, indent: 4)
                                runtimeWarn(
                    """
                    "\(fileID):\(line)"에서 반한된 "Effect.run"가 다음과 같이 다를 수 없는 에러를 던졌습니다. …
                    
                    \(errorDump)
                    
                    취소되지 않는 에러는 명시적으로 "Effect.run" 의 "catch" 파라미터에서 다뤄지거나 "do" 블럭을 사용해야 합니다.
                    """
                                )
#endif
                                return
                            }
                            await handler(error, send)
                        }
                    }
                }
            )
        }
    }
    
    /// 들어온 액션을 즉각 방출하는 `Effect` 를 제공합니다.
    ///
    /// - Note: `Effect.send` 를 사용하여 로직 공유하는 것을 권장하지 않습니다. 다만, 자식이 "delegate" 액션을 방출하고 이를 부모가 받는 자식-부모 간의 통신 방식에 한해 사용하시길 바랍니다. 더 자세한 내용은 <doc:Performance#Sharing-logic-with-actions>를 참고하세요.
    ///
    /// - Parameter action: `Effect` 에 의해 즉각 방출될 액션.
    public static func send(_ action: Action) -> Self {
        Self(operation: .publisher(Just(action).eraseToAnyPublisher()))
    }
    
    /// 들어온 액션을 즉각 방출하는 `Effect` 를 제공합니다.
    ///
    /// - Note: `Effect.send` 를 사용하여 로직 공유하는 것을 권장하지 않습니다. 다만, 자식이 "delegate" 액션을 방출하고 이를 부모가 받는 자식-부모 간의 통신 방식에 한해 사용하시길 바랍니다. 더 자세한 내용은 <doc:Performance#Sharing-logic-with-actions>를 참고하세요.
    ///
    /// - Parameters:
    ///   - action: `Effect` 에 의해 즉각 방출될 액션.
    ///   - animation: 애니메이션.
    public static func send(_ action: Action, animation: Animation? = nil) -> Self {
        .send(action).animation(animation)
    }
}

/// ``Effect/run(priority:operation:catch:fileID:line:)``에서 사용될 때 시스템으로 다시 액션을 보내는 타입.
///
/// 이 타입은 [`callAsFunction`][callAsFunction]을 구현하여 객체의 메서드를 호출하는 것이 아닌 객체 자체를 함수처럼 호출할 수 있습니다.
///
/// ```swift
/// return .run { send in
///   send(.started) // send는 함수가 아닌 `Send` 타입 객체 이지만 `callAsFunction`을 구현했기 때문에 함수처럼 쓸 수 있음.
///   defer { send(.finished) }
///   for await event in self.events {
///     send(.event(event))
///   }
/// }
/// ```
///
/// 또한 액션 전달시 애니메이션도 같이 전달할 수 있습니다.
///
/// ```swift
/// send(.started, animation: .spring())
/// defer { send(.finished, animation: .default) }
/// ```
///
/// - Note: ``Effect/run(priority:operation:catch:fileID:line:)`` 에서 횟수 제한 없이 비동기 컨텍스트를 방출할 수 있는 `Effect` 를 구성하기 위해 `Send` 값을 어떻게 사용하는 지에 대한 더 자세한 내용을 확인할 수 있습니다.
///
/// [callAsFunction]: https://docs.swift.org/swift-book/ReferenceManual/Declarations.html#ID622
@MainActor
public struct Send<Action>: Sendable {
    let send: @MainActor @Sendable (Action) -> Void
    
    public init(send: @escaping @MainActor @Sendable (Action) -> Void) {
        self.send = send
    }
    
    /// 액션을 `Effect` 에서 시스템으로 다시 전달합니다.
    ///
    /// - Parameter action: 액션.
    public func callAsFunction(_ action: Action) {
        guard !Task.isCancelled else { return }
        self.send(action)
    }
    
    /// 액션을 애니메이션과 함께 `Effect` 에서 시스템으로 다시 전달합니다.
    ///
    /// - Parameters:
    ///   - action: 액션.
    ///   - animation: 애니메이션.
    public func callAsFunction(_ action: Action, animation: Animation?) {
        callAsFunction(action, transaction: Transaction(animation: animation))
    }
    
    /// 액션을 `Transaction` 객체와 함께 `Effect` 에서 시스템으로 다시 전달합니다.
    ///
    /// - Parameters:
    ///   - action: 액션.
    ///   - transaction: 트랜잭션.
    public func callAsFunction(_ action: Action, transaction: Transaction) {
        guard !Task.isCancelled else { return }
        withTransaction(transaction) {
            self(action)
        }
    }
}

// MARK: - Effects 조합하기

extension Effect {
    /// 여러개의 변할 수 있는(variadic) `Effect`를 동시에 실행할 수 있도록 하나의 `Effect`로 합칩니다.
    ///
    /// - Parameter effects: 변할 수 있는 `Effect` 리스트.
    /// - Returns: 새 `Effect` 객체.
    @inlinable
    public static func merge(_ effects: Self...) -> Self {
        Self.merge(effects)
    }
    
    /// 여러개의 `Effect`를 동시에 실행할 수 있도록 하나의 `Effect`로 합칩니다.
    ///
    /// - Parameter effects: `Effect` 시퀀스.
    /// - Returns: 새 `Effect`.
    @inlinable
    public static func merge<S: Sequence>(_ effects: S) -> Self where S.Element == Self {
        effects.reduce(.none) { $0.merge(with: $1) }
    }
    
    /// 현재 `Effect` 를 다른 `Effect` 와 합쳐 동시에 실행될 수 있도록 하나의 `Effect`로 만듭니다.
    ///
    /// - Parameter other: 다른 `Effect` 객체.
    /// - Returns: 현재 `Effect` 와 다른 `Effect`를 동시에 실행시킬 수 있는 새 `Effect` 객체.
    @inlinable
    public func merge(with other: Self) -> Self {
        switch (self.operation, other.operation) {
        case (_, .none):
            return self
        case (.none, _):
            return other
        case (.publisher, .publisher), (.run, .publisher), (.publisher, .run):
            return Self(
                operation: .publisher(
                    Publishers.Merge(
                        _EffectPublisher(self),
                        _EffectPublisher(other)
                    )
                    .eraseToAnyPublisher()
                )
            )
        case let (.run(lhsPriority, lhsOperation), .run(rhsPriority, rhsOperation)):
            return Self(
                operation: .run { send in
                    await withTaskGroup(of: Void.self) { group in
                        group.addTask(priority: lhsPriority) {
                            await lhsOperation(send)
                        }
                        group.addTask(priority: rhsPriority) {
                            await rhsOperation(send)
                        }
                    }
                }
            )
        }
    }
    
    /// 여러개의 변할 수 있는(variadic) 리스트 내의 `Effect`들이 순차적으로 실행될 수 있도록 하나의 `Effect`로  서로 연결 시킵니다.
    ///
    /// - Parameter effects: 변할 수 있는(variadic) `Effect` 리스트.
    /// - Returns: 새 `Effect`.
    @inlinable
    public static func concatenate(_ effects: Self...) -> Self {
        Self.concatenate(effects)
    }
    
    /// 컬렉션 내의 `Effect`들이 순차적으로 실행될 수 있도록 하나의 `Effect`로 서로 연결 시킵니다.
    ///
    /// - Parameter effects: `Effect` 객체 컬렉션
    /// - Returns: 새 `Effect`.
    @inlinable
    public static func concatenate<C: Collection>(_ effects: C) -> Self where C.Element == Self {
        effects.reduce(.none) { $0.concatenate(with: $1) }
    }
    
    /// 현재 `Effect` 가 먼저 실행되고 실행이 완료되거나 취소되고 나면 다른 `Effect`를 실행할 수 있도록 하나의 `Effect`로 서로 연결시킵니다.
    ///
    /// - Parameter other: 다른 `Effect` 객체.
    /// - Returns: 현재 `Effect` 가 먼저 실행되고 실행이 완료되거나 취소되고 나면 다른 `Effect`를 실행할 수 있도록 하는 `Effect` 객체
    @inlinable
    @_disfavoredOverload
    public func concatenate(with other: Self) -> Self {
        switch (self.operation, other.operation) {
        case (_, .none):
            return self
        case (.none, _):
            return other
        case (.publisher, .publisher), (.run, .publisher), (.publisher, .run):
            return Self(
                operation: .publisher(
                    Publishers.Concatenate(
                        prefix: _EffectPublisher(self),
                        suffix: _EffectPublisher(other)
                    )
                    .eraseToAnyPublisher()
                )
            )
        case let (.run(lhsPriority, lhsOperation), .run(rhsPriority, rhsOperation)):
            return Self(
                operation: .run { send in
                    if let lhsPriority = lhsPriority {
                        await Task(priority: lhsPriority) { await lhsOperation(send) }.cancellableValue
                    } else {
                        await lhsOperation(send)
                    }
                    if let rhsPriority = rhsPriority {
                        await Task(priority: rhsPriority) { await rhsOperation(send) }.cancellableValue
                    } else {
                        await rhsOperation(send)
                    }
                }
            )
        }
    }
    
    /// 업스트림 `Effect` 로부터 온 모든 요소를 제공된 클로져를 가지고 변형시킵니다.
    ///
    /// - Parameter transform: 업스트림 `Effect`의 액션을 새로운 액션으로 변형시키는 클로져.
    /// - Returns: 업스트림 `Effect`으로 부터 온 요소들을 퍼블리시할 새로운 요소로 매핑하기 위해 제공된 클로져를 사용하는 퍼블리셔
    @inlinable
    public func map<T>(_ transform: @escaping (Action) -> T) -> Effect<T> {
        switch self.operation {
        case .none:
            return .none
        case let .publisher(publisher):
            return .init(
                operation: .publisher(
                    publisher
                        .map(
                            withEscapedDependencies { escaped in
                                { action in
                                    escaped.yield {
                                        transform(action)
                                    }
                                }
                            }
                        )
                        .eraseToAnyPublisher()
                )
            )
        case let .run(priority, operation):
            return withEscapedDependencies { escaped in
                    .init(
                        operation: .run(priority) { send in
                            await escaped.yield {
                                await operation(
                                    Send { action in
                                        send(transform(action))
                                    }
                                )
                            }
                        }
                    )
            }
        }
    }
}
