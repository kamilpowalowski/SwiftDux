# SwiftDux

> Predictable state management for SwiftUI applications.

[![Swift Version][swift-image]][swift-url]
![Platform Versions][ios-image]
[![Github workflow][github-workflow-image]](https://github.com/StevenLambion/SwiftDux/actions)
[![codecov][codecov-image]](https://codecov.io/gh/StevenLambion/SwiftDux)

SwiftDux is a redux inspired state management solution built around the Combine and SwiftUI frameworks. If you need to target an older operating system or require a more established library,  check out [ReSwift](https://github.com/ReSwift/ReSwift).

## Features

### Redux-like State Management.
- Familiar API to Redux.
- Incapsulate action-based workflows via `ActionPlans`.
- Manage ordered collections of objects using  `OrderedState<_>`.
- Extend functionality with `Middleware`.

### SwiftUI Integration.

- `@MappedState` and `@MappedDispatch` injects state and dispatch actions from views.
- `Connectable` protocol maps the application state to the props required by a view.
- `Binding<_>` support for views like `TextField`.
- `OrderedState<_>` has a compatible API for List events such as `onDelete` and `onMove`.
- Notable `View` methods:
  - `provideStore(_:)` Injects the SwiftDux store.
  - `onAction(perform:)` track or modify dispatched actions from subviews.
  - `onAppear(dispatch:)` sends an action when a view appears, and cleans up any action plans that might return a publisher. 

### Built-in Middleware (Under the SwiftDuxExtras module)

- `PersistStateMiddleware` automatically persists and restores the application state.
- `PrintActionMiddleware` prints out each dispatched action for debugging purposes.

# Installation

## Prerequisites
- Xcode 11+
- Swift 5.1+
- iOS 13+, macOS 10.15+, tvOS 13+, or watchOS 6+

## Install via Xcode 11:

Search for SwiftDux in Xcode's Swift Package Manager integration.

## Install via the Swift Package Manager:

```swift
import PackageDescription

let package = Package(
  dependencies: [
    .Package(url: "https://github.com/StevenLambion/SwiftDux.git", majorVersion: 0, minor: 12)
  ]
)
```

# Demo Application

Take a look at the [Todo Example App](https://github.com/StevenLambion/SwiftUI-Todo-Example) to see how SwiftDux works.

# Getting Started

SwiftDux helps build SwiftUI-based applications around an [elm-like architecture](https://guide.elm-lang.org/architecture/) using a single, centralized state container. It has 4 basic principles:

- **State** - An immutable, single source of truth within the application.
- **Action** - Describes a single change of the state.
- **Reducer** - Returns a new state by consuming the previous one with an action.
- **View** - The visual representation of the current state.

<div style="text-align:center">
  <img src="Guides/Images/architecture.jpg" width="400"/>
</div>

## State

The state is a single, immutable structure acting as the single source of truth within the application.

Below is an example of a todo app's state. It has a root `AppState` as well as an ordered list of `TodoState` objects. When storing entities in state, the `IdentifiableState` protocol should be used to display them in a list.

```swift
import SwiftDux

struct AppState: StateTyoe {
  todos: OrderedState<TodoItem>
}

struct TodoItem: IdentifiableState {
  var id: String,
  var text: String
}
```

## Actions

An action is a description of how the state will change. They're typically dispatched from events in the application, such as a user clicking a button. Swift's enum type is ideal for actions, but structs and classes could be used if required.

```swift
import SwiftDux

enum TodoAction: Action {
  case addTodo(text: String)
  case removeTodos(at: IndexSet)
  case moveTodos(from: IndexSet, to: Int)
}
```

It can be useful to categorize actions through a shared protocol:

```swift
protocol SettingsAction: Action {}

enum GeneralSettingsAction: SettingsAction {
  ...
}

enum NetworkSettingsAction: SettingsAction {
  ...
}
```

## Reducers

A reducer consumes an action to produce a new state. There's always a root reducer that consumes all actions. From here, it can delegate out to sub-reducers. Each reducer conforms to a single type of action.

The `Reducer` protocol has two primary methods to override:

- `reduce(state:action:)` - For actions supported by the reducer.
- `reduceNext(state:action:)` - Dispatches an action to any sub-reducers. This method is optional.

```swift
final class TodosReducer: Reducer {

  func reduce(state: OrderedState<TodoItem>, action: TodoAction) -> OrderedState<TodoItem> {
    var state = state
    switch action {
    case .addTodo(let text):
      let id = UUID().uuidString
      state.append(TodoItemState(id: id, text: text))
    case .removeTodos(let indexSet):
      state.remove(at: indexSet)
    case .moveTodos(let indexSet, let index):
      state.move(from: indexSet, to: index)
    }
    return state
  }

}
```

```swift
final class AppReducer: Reducer {
  let todosReducer = TodosReducer()

  func reduceNext(state: AppState, action: TodoAction) -> AppState {
    State(
      todos: todosReducer.reduceAny(state.todos, action)
    )
  }

}
```

## Store

The store acts as the container of the state. Initialize the store with a default state and the root reducer. Then use the `provideStore(_:)` view modifier at the root of the application to inject the store into the environment.

```swift
import SwiftDux

let store = Store(AppState(todos: OrderedState()), AppReducer())

window.rootViewController = UIHostingController(
  rootView: RootView().provideStore(store)
)
```

## Connectable View

In a view, use `@MappedState` and `@MappedDispatch` to inject the state and dispatch actions to the store. When the view dispatches an action, it updates itself automatically.

```swift
struct TodosView {

  @MappedState private var todos: OrderedState<Todo>
  @MappedDispatch() private var dispatch

  var body: some View {
    List {
      ForEach(todos) { todo in
        TodoItemRow(item: todo)
      }
      .onDelete { self.dispatch(TodoAction.removeTodos(at: $0)) }
      .onMove { self.dispatch(TodoAction.moveTodos(from: $0, to: $1)) }
    }
  }

}
```

The easiest way to connect the application state to the view is through the `Connectable` protocol. Adhering to this protocol allows the view to map a parent state to the required state.

```swift
extension TodosView: Connectable {

  func map(state: AppState) -> OrderedState<Todo>? {
    state.todos
  }

}
```

When placing the view, the `connect()` method must be called to inject the application state into the view.

```swift
struct RootView: View {

  var body: some View {
    TodosView().connect()
  }

}
```

## Parameterized Connectable View
In some cases, a parameter needs to be passed to a connected view. For example, the id of an object. This can be handled using the `ParameterizedConnectable` protocol. It is nearly identical to `Connectable`, but requires a parameter be passed in.

```swift
extension TodoDetailsView: ParameterizedConnectable {

  func map(state: TodoList, parameter: String) -> Todo? {
    state[parameter]
  }

}

// Use the connect(with:) method to use the view:

TodoDetailsView().connect(with: todoId)
```

## Binding<_> Support

SwiftUI has a focus on two-way bindings over a unidirectional flow. To better support this, SwiftDux provides a convenient API through the `Connectable` protocol using a `StateBinder` object. Use the `map(state:binder:)` method on the protocol as shown below.

```swift
struct LoginForm: View {

  @MappedState private var props: Props

  var body: some View {
    VStack {
      TextField("Email", text: props.email)
      /* ... */
    }
  }

}

extension LoginForm: Connectable {

  struct Props {
    var email: Binding<String>
  }

  func map(state: AppState, binder: StateBinder) -> Props? {
    var loginForm = state.loginForm
    return Props(
      email: binder.bind(loginForm.email) { LoginFormAction.setEmail($0) }
    )
  }


}
```

## Action Plans
An `ActionPlan` is a special kind of action that can be used to group other actions together or perform any kind of async logic.

```swift
/// Dispatch multiple actions together:

let plan = ActionPlan<AppState> { store in
  store.send(actionA)
  store.send(actionB)
  store.send(actionC)
}

/// Perform async operations:

let plan = ActionPlan<AppState> { store in
  DispatchQueue.global().async {
    store.send(actionA)
    store.send(actionB)
    store.send(actionC)
  }
}

/// Publish actions to the store:

let plan = ActionPlan<AppState> { store, completed in
  let actions = [
    actionA,
    actionB,
    actionC
  ]
  
  actions.publisher.send(to: store, receivedCompletion: completed)
}

/// In a View, dispatch the plan like any other action:

dispatch(plan)
```

## Query External Services
Action plans can be used in conjunction with the `onAppear(dispatch:)` view modifier to connect to external data sources when a view appears. If the action plan returns a publisher, it will automatically cancel when the view disappears. Optionally, use `onAppear(dispatch:cancelOnDisappear:)` if the publisher should continue.

Action plans can also subscribe to the store. This is useful when the query needs to be refreshed if the application state changes. Rather than imperatively handling this by re-sending the action plan, it can be done more declaratively within it. The store's `didChange` subject will emit at least once after the action plan returns a publisher.

Here's an example of an action plan that queries for todos. It updates whenever the filter changes. It also debounces to reduce the amount of queries sent to the external services.

```swift
struct ActionPlans {
  var services: Services
}

extension ActionPlans {

  var queryTodos: Action {
    ActionPlan<AppState> { store, completed in
      store.didChange
        .filter { $0 is TodoListAction }
        .map { _ in store.state?.todoList.filterBy ?? "" }
        .removeDuplicates()
        .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
        .flatMap { filter in self.services.queryTodos(filter: filter) }
        .catch { _ in Just<[TodoItem]>([]) }
        .map { todos -> Action in TodoListAction.setTodos(todos) }
        .send(to: store, receivedCompletion: completed)
    }
  }

}

struct TodoListView: View {
  @Environment(\.actionPlans) private var actionPlans
  @MappedState private var todos: [TodoItem]

  var body: some View {
    renderTodos(todos: todos)
      .onAppear(dispatch: actionPlans.queryTodos)
  }

  // ...

}
```

[swift-image]: https://img.shields.io/badge/swift-5.1-orange.svg
[ios-image]: https://img.shields.io/badge/platforms-iOS%2013%20%7C%20macOS%2010.15%20%7C%20tvOS%2013%20%7C%20watchOS%206-222.svg
[swift-url]: https://swift.org/
[license-image]: https://img.shields.io/badge/License-MIT-blue.svg
[license-url]: LICENSE
[travis-image]: https://img.shields.io/travis/dbader/node-datadog-metrics/master.svg
[travis-url]: https://travis-ci.org/dbader/node-datadog-metrics
[codebeat-image]: https://codebeat.co/badges/c19b47ea-2f9d-45df-8458-b2d952fe9dad
[codebeat-url]: https://codebeat.co/projects/github-com-vsouza-awesomeios-com
[github-workflow-image]: https://github.com/StevenLambion/SwiftDux/workflows/build/badge.svg
[codecov-image]: https://codecov.io/gh/StevenLambion/SwiftDux/branch/master/graph/badge.svg
