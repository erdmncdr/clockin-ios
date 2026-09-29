import SwiftUI
import WidgetKit

@main
struct ClockinWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        #if os(iOS)
        ClockinLiveActivity()
        #endif
        if #available(iOS 18.0, macOS 26.0, *) {
            ClockinTimerControl()
            ClockinPauseControl()
        }
    }
}
