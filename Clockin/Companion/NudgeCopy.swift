import Foundation

enum NudgeCopy {
    static func text(kind: NudgeKind, tone: NudgeTone, day: Date, calendar: Calendar,
                     remaining: TimeInterval, brokenStreak: Bool = false) -> (title: String, body: String) {
        let time = DurationText.compact(remaining)
        let variants: [(String, String)]
        switch (kind, tone) {
        case (.pausedTooLong, .grumpy):
            variants = [
                (String(localized: "Break's over", bundle: .app), String(localized: "The coffee is cold. So am I. When are you coming back?", bundle: .app)),
                (String(localized: "Hello? Anyone there?", bundle: .app), String(localized: "This is a long break. Is it a break or a resignation?", bundle: .app)),
                (String(localized: "Still paused?", bundle: .app), String(localized: "The timer is frozen and so is your progress. Resume.", bundle: .app)),
                (String(localized: "Get back here", bundle: .app), String(localized: "I paused the timer, not your goals. Come back.", bundle: .app))
            ]
        case (.pausedTooLong, .friendly):
            variants = [
                (String(localized: "Ready to return?", bundle: .app), String(localized: "You've had a breather. Resume whenever you're ready.", bundle: .app)),
                (String(localized: "A gentle check-in", bundle: .app), String(localized: "Your session is paused. A small next step can help.", bundle: .app)),
                (String(localized: "Your desk is ready", bundle: .app), String(localized: "Take a sip, stretch, and ease back in.", bundle: .app)),
                (String(localized: "Pick up where you left off", bundle: .app), String(localized: "Your progress is waiting. Shall we continue?", bundle: .app))
            ]
        case (.leftEarly, .grumpy):
            variants = [
                (String(localized: "You left halfway", bundle: .app), String(localized: "\(time) short and you just walked off? When are you coming back?", bundle: .app)),
                (String(localized: "Leaving already?", bundle: .app), String(localized: "Your goal is \(time) away. I'm not impressed.", bundle: .app)),
                (String(localized: "Hey, where did you go?", bundle: .app), String(localized: "You stopped with \(time) left. I'm keeping score.", bundle: .app)),
                (String(localized: "Unfinished business", bundle: .app), String(localized: "\(time) left on today's goal. The chair is still warm. Get back here.", bundle: .app))
            ]
        case (.leftEarly, .friendly):
            variants = [
                (String(localized: "A little more today?", bundle: .app), String(localized: "You're \(time) from your goal. Come back when you can.", bundle: .app)),
                (String(localized: "You've made a start", bundle: .app), String(localized: "Another \(time) would reach today's goal.", bundle: .app)),
                (String(localized: "Room for one more session?", bundle: .app), String(localized: "You have \(time) left. Every bit of progress counts.", bundle: .app)),
                (String(localized: "Keep the momentum", bundle: .app), String(localized: "Your goal is \(time) away. We can take it one step at a time.", bundle: .app))
            ]
        case (.goalMissed, .grumpy):
            variants = [
                (String(localized: "Goal missed", bundle: .app), String(localized: "You came up \(time) short today. I'm writing this down.", bundle: .app)),
                (String(localized: "That's not the goal", bundle: .app), String(localized: "\(time) short. You set that goal, not me.", bundle: .app)),
                (String(localized: "We need to talk", bundle: .app), String(localized: "Today's goal is \(time) away and the day is almost over.", bundle: .app)),
                (String(localized: "Evening report: not great", bundle: .app), String(localized: "\(time) left on your goal. Tomorrow you owe me.", bundle: .app))
            ]
        case (.goalMissed, .friendly):
            variants = [
                (String(localized: "Today's progress counts", bundle: .app), String(localized: "You're \(time) short of your goal. There's a fresh start tomorrow.", bundle: .app)),
                (String(localized: "An evening check-in", bundle: .app), String(localized: "You made progress today, with \(time) left to your goal.", bundle: .app)),
                (String(localized: "Keep going gently", bundle: .app), String(localized: "Your goal has \(time) left. A small session can help.", bundle: .app)),
                (String(localized: "Look how far you got", bundle: .app), String(localized: "There's \(time) left today. Choose a next step that works for you.", bundle: .app))
            ]
        case (.streakAtRisk, .grumpy):
            if brokenStreak {
                variants = [
                    (String(localized: "The streak is gone", bundle: .app), String(localized: "You skipped yesterday. I'm not over it yet.", bundle: .app)),
                    (String(localized: "Streak: broken", bundle: .app), String(localized: "Yesterday was empty. Start a new one today.", bundle: .app)),
                    (String(localized: "Back to day one", bundle: .app), String(localized: "You broke the streak. Let's see if you can build it again.", bundle: .app)),
                    (String(localized: "I saw that", bundle: .app), String(localized: "No work yesterday, so the streak is gone. Clock in and fix it.", bundle: .app))
                ]
            } else {
                variants = [
                    (String(localized: "Your streak is about to end", bundle: .app), String(localized: "Nothing today yet. Are you really letting it go?", bundle: .app)),
                    (String(localized: "Save your streak", bundle: .app), String(localized: "One session. That's all. Don't make me watch it break.", bundle: .app)),
                    (String(localized: "Tick tock", bundle: .app), String(localized: "Your streak ends at midnight unless you clock in.", bundle: .app)),
                    (String(localized: "Seriously?", bundle: .app), String(localized: "All those days of work, and you're dropping the streak tonight?", bundle: .app))
                ]
            }
        case (.streakAtRisk, .friendly):
            if brokenStreak {
                variants = [
                    (String(localized: "A fresh beginning", bundle: .app), String(localized: "Yesterday was a gap. Today can be the start of a new streak.", bundle: .app)),
                    (String(localized: "Start again together", bundle: .app), String(localized: "Your streak ended yesterday. Your progress is still yours.", bundle: .app)),
                    (String(localized: "Welcome to a new day", bundle: .app), String(localized: "A missed day is okay. Let's build a new streak when you're ready.", bundle: .app)),
                    (String(localized: "Another chance", bundle: .app), String(localized: "Yesterday is behind you. One session can begin a new streak.", bundle: .app))
                ]
            } else {
                variants = [
                    (String(localized: "Keep your streak going", bundle: .app), String(localized: "A little focused time today will keep your streak alive.", bundle: .app)),
                    (String(localized: "One small session?", bundle: .app), String(localized: "There's still time to add today to your streak.", bundle: .app)),
                    (String(localized: "You've built a rhythm", bundle: .app), String(localized: "A session this evening can keep it going.", bundle: .app)),
                    (String(localized: "Cheering for your streak", bundle: .app), String(localized: "Ready to give today a little focused time?", bundle: .app))
                ]
            }
        case (.noWorkToday, .grumpy):
            variants = [
                (String(localized: "No work today?", bundle: .app), String(localized: "I'm not mad. I'm just disappointed.", bundle: .app)),
                (String(localized: "Why aren't you working?", bundle: .app), String(localized: "The timer has been at zero all day. Clock in.", bundle: .app)),
                (String(localized: "Taking the day off?", bundle: .app), String(localized: "Nobody told me. The timer is still waiting.", bundle: .app)),
                (String(localized: "Roll call", bundle: .app), String(localized: "Timer: here. Robot: here. You: missing.", bundle: .app))
            ]
        case (.noWorkToday, .friendly):
            variants = [
                (String(localized: "Ready when you are", bundle: .app), String(localized: "A small focused session is a good way to begin today.", bundle: .app)),
                (String(localized: "Let's make a start", bundle: .app), String(localized: "Your companion is here whenever you're ready to clock in.", bundle: .app)),
                (String(localized: "A little focus today?", bundle: .app), String(localized: "Pick one manageable task and we'll take it from there.", bundle: .app)),
                (String(localized: "Your next step", bundle: .app), String(localized: "A fresh session is waiting. Start with something small.", bundle: .app))
            ]
        case (.goneQuiet, .grumpy):
            variants = [
                (String(localized: "Did you quit on me?", bundle: .app), String(localized: "Days without a single session. Where are you?", bundle: .app)),
                (String(localized: "Not working anymore?", bundle: .app), String(localized: "It's been days. I'm starting to take this personally.", bundle: .app)),
                (String(localized: "Hello, stranger", bundle: .app), String(localized: "I still remember what a clock-in looks like. Do you?", bundle: .app)),
                (String(localized: "Missing: one coworker", bundle: .app), String(localized: "Last seen days ago. Come back and clock in.", bundle: .app))
            ]
        case (.goneQuiet, .friendly):
            variants = [
                (String(localized: "Welcome back anytime", bundle: .app), String(localized: "It's been a few days. A small session can ease you back in.", bundle: .app)),
                (String(localized: "A fresh start awaits", bundle: .app), String(localized: "Your progress is here whenever you're ready to return.", bundle: .app)),
                (String(localized: "Checking in", bundle: .app), String(localized: "We haven't worked together lately. Start gently when you can.", bundle: .app)),
                (String(localized: "Room for a restart", bundle: .app), String(localized: "One manageable task is enough to begin again.", bundle: .app))
            ]
        }
        let reference = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let days = calendar.dateComponents([.day], from: reference, to: day).day ?? 0
        let index = ((days + kind.priority) % variants.count + variants.count) % variants.count
        return variants[index]
    }
}
