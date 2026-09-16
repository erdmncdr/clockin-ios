import SwiftUI
import WidgetKit

@main
struct ClockinWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        ClockinLiveActivity()
        if #available(iOS 18.0, *) {
            ClockinTimerControl()
            ClockinPauseControl()
        }
    }
}
