import SwiftUI

struct FeedbackModelFocusKey: FocusedValueKey {
    typealias Value = AppModel
}

extension FocusedValues {
    var feedbackModel: AppModel? {
        get { self[FeedbackModelFocusKey.self] }
        set { self[FeedbackModelFocusKey.self] = newValue }
    }
}
