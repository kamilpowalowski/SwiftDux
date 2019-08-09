import Foundation
import Combine

final internal class StateConnection<State> : ObservableObject, Identifiable {
  var objectWillChange = ObservableObjectPublisher()
  
  var getState: () -> State?
  
  private var cancellable: AnyCancellable? = nil
  
  init(getState: @escaping () -> State?, changePublisher: AnyPublisher<Void, Never>?) {
    self.getState = getState
    self.cancellable = changePublisher?.sink { [weak self] _ in
      guard let self = self else { return }
      self.objectWillChange.send()
    }
  }
}
