import OrderedCollections

extension Reducer {
  /// Embeds a child reducer in a parent domain that works on elements of a collection in parent
  /// state.
  ///
  /// For example, if a parent feature holds onto an array of child states, then it can perform
  /// its core logic _and_ the child's logic by using the `forEach` operator:
  ///
  /// ```swift
  /// struct Parent: Reducer {
  ///   struct State {
  ///     var rows: IdentifiedArrayOf<Row.State>
  ///     // ...
  ///   }
  ///   enum Action {
  ///     case row(id: Row.State.ID, action: Row.Action)
  ///     // ...
  ///   }
  ///
  ///   var body: some Reducer<State, Action> {
  ///     Reduce { state, action in
  ///       // Core logic for parent feature
  ///     }
  ///     .forEach(\.rows, action: /Action.row) {
  ///       Row()
  ///     }
  ///   }
  /// }
  /// ```
  ///
  /// > Tip: We are using `IdentifiedArray` from our
  /// [Identified Collections][swift-identified-collections] library because it provides a safe
  /// and ergonomic API for accessing elements from a stable ID rather than positional indices.
  ///
  /// The `forEach` forces a specific order of operations for the child and parent features. It
  /// runs the child first, and then the parent. If the order was reversed, then it would be
  /// possible for the parent feature to remove the child state from the array, in which case the
  /// child feature would not be able to react to that action. That can cause subtle bugs.
  ///
  /// It is still possible for a parent feature higher up in the application to remove the child
  /// state from the array before the child has a chance to react to the action. In such cases a
  /// runtime warning is shown in Xcode to let you know that there's a potential problem.
  ///
  /// [swift-identified-collections]: http://github.com/pointfreeco/swift-identified-collections
  ///
  /// - Parameters:
  ///   - toElementsState: A writable key path from parent state to an `IdentifiedArray` of child
  ///     state.
  ///   - toElementAction: A case path from parent action to child identifier and child actions.
  ///   - element: A reducer that will be invoked with child actions against elements of child
  ///     state.
  /// - Returns: A reducer that combines the child reducer with the parent reducer.
  @inlinable
  @warn_unqualified_access
  public func forEach<ElementState, ElementAction, ID: Hashable, Element: Reducer>(
    _ toElementsState: WritableKeyPath<State, IdentifiedArray<ID, ElementState>>,
    action toElementAction: CasePath<Action, (ID, ElementAction)>,
    @ReducerBuilder<ElementState, ElementAction> element: () -> Element,
    fileID: StaticString = #fileID,
    line: UInt = #line
  ) -> _ForEachReducer<Self, ID, Element>
  where ElementState == Element.State, ElementAction == Element.Action {
    _ForEachReducer(
      parent: self,
      toElementsState: toElementsState,
      toElementAction: toElementAction,
      element: element(),
      fileID: fileID,
      line: line
    )
  }
}

public struct _ForEachReducer<
  Parent: Reducer, ID: Hashable, Element: Reducer
>: Reducer {
  @usableFromInline
  let parent: Parent

  @usableFromInline
  let toElementsState: WritableKeyPath<Parent.State, IdentifiedArray<ID, Element.State>>

  @usableFromInline
  let toElementAction: CasePath<Parent.Action, (ID, Element.Action)>

  @usableFromInline
  let element: Element

  @usableFromInline
  let fileID: StaticString

  @usableFromInline
  let line: UInt

  @Dependency(\.navigationIDPath) var navigationIDPath

  @usableFromInline
  init(
    parent: Parent,
    toElementsState: WritableKeyPath<Parent.State, IdentifiedArray<ID, Element.State>>,
    toElementAction: CasePath<Parent.Action, (ID, Element.Action)>,
    element: Element,
    fileID: StaticString,
    line: UInt
  ) {
    self.parent = parent
    self.toElementsState = toElementsState
    self.toElementAction = toElementAction
    self.element = element
    self.fileID = fileID
    self.line = line
  }

  public func reduce(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action> {
    let elementEffects = self.reduceForEach(into: &state, action: action)

    let idsBefore = state[keyPath: self.toElementsState].ids
    let parentEffects = self.parent.reduce(into: &state, action: action)
    let idsAfter = state[keyPath: self.toElementsState].ids

    let elementCancelEffects: Effect<Parent.Action> =
      areOrderedSetsDuplicates(idsBefore, idsAfter)
      ? .none
      : .merge(
        idsBefore.subtracting(idsAfter).map {
          ._cancel(
            id: NavigationID(id: $0, keyPath: self.toElementsState),
            navigationID: self.navigationIDPath
          )
        }
      )

    return .merge(
      elementEffects,
      parentEffects,
      elementCancelEffects
    )
  }

  func reduceForEach(
    into state: inout Parent.State, action: Parent.Action
  ) -> Effect<Parent.Action> {
    guard let (id, elementAction) = self.toElementAction.extract(from: action) else { return .none }
    if state[keyPath: self.toElementsState][id: id] == nil {
      runtimeWarn(
        """
        "\(self.fileID):\(self.line)"에서의 "forEach" 가 놓친 요소를 위한 액션을 전달 받았습니다.

          액션:
            \(debugCaseOutput(action))

        이는 앱 로직 에러로 간주 되며, 이 경고가 발생하는 이유는 다음과 같습니다.

        • 이 리듀서가 실행되기 전, 이미 부모 리듀서가 이 ID에 해당하는 요소를 제거한 경우. 이 리듀서는 반드시 다른 리듀서가 요소를 제거하기 전에 실행되어야 합니다. 이는 요소 리듀서가 자신의 상태가 유효한 동안 자신의 액션을 다루도록 보장해줍니다.

        • Store의 상태가 현재 ID에 아무런 요소를 갖지 않음에도 불구하고 처리 중인 Effect 가 현재 액션을 방출한 경우. 현재 액션을 무시하는 것이 합리적일 수 있지만 요소가 제거되기 전에 연관된 Effect를 취소하는 것을 고려해 보십시오. (특히 오랫동안 살아있는 Effect 인 경우)

        • Store의 상태가 현재 ID에 아무런 요소를 갖지 않음에도 불구하고 현재 액션이 Store로 보내진 경우. 상태가 현재 ID에 요소를 가질 때에만 ViewStore 로 부터 현재 리듀서를 위한 액션을 전달 받을 수 있도록 하여 고칠 수 있습니다. SwiftUI 앱에서 "ForEachStore" 를 사용하십시오.
        """
      )
      return .none
    }
    let navigationID = NavigationID(id: id, keyPath: self.toElementsState)
    let elementNavigationID = self.navigationIDPath.appending(navigationID)
    return self.element
      .dependency(\.navigationIDPath, elementNavigationID)
      .reduce(into: &state[keyPath: self.toElementsState][id: id]!, action: elementAction)
      .map { self.toElementAction.embed((id, $0)) }
      ._cancellable(id: navigationID, navigationIDPath: self.navigationIDPath)
  }
}
