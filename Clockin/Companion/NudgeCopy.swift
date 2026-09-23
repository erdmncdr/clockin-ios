import Foundation

enum NudgeCopy {
    static func text(kind: NudgeKind, tone: NudgeTone, day: Date, calendar: Calendar,
                     remaining: TimeInterval, brokenStreak: Bool = false) -> (title: String, body: String) {
        let time = DurationText.compact(remaining)
        let variants: [(String, String)]
        switch (kind, tone) {
        case (.pausedTooLong, .grumpy):
            variants = [
                (String(localized: "Break's over"), String(localized: "The coffee is cold. So am I. When are you coming back?")),
                (String(localized: "Hello? Anyone there?"), String(localized: "This is a long break. Is it a break or a resignation?")),
                (String(localized: "Still paused?"), String(localized: "The timer is frozen and so is your progress. Resume.")),
                (String(localized: "Get back here"), String(localized: "I paused the timer, not your goals. Come back."))
            ]
        case (.pausedTooLong, .friendly):
            variants = [
                (String(localized: "Ready to return?"), String(localized: "You've had a breather. Resume whenever you're ready.")),
                (String(localized: "A gentle check-in"), String(localized: "Your session is paused. A small next step can help.")),
                (String(localized: "Your desk is ready"), String(localized: "Take a sip, stretch, and ease back in.")),
                (String(localized: "Pick up where you left off"), String(localized: "Your progress is waiting. Shall we continue?"))
            ]
        case (.leftEarly, .grumpy):
            variants = [
                (String(localized: "You left halfway"), String(localized: "\(time) short and you just walked off? When are you coming back?")),
                (String(localized: "Leaving already?"), String(localized: "Your goal is \(time) away. I'm not impressed.")),
                (String(localized: "Hey, where did you go?"), String(localized: "You stopped with \(time) left. I'm keeping score.")),
                (String(localized: "Unfinished business"), String(localized: "\(time) left on today's goal. The chair is still warm. Get back here."))
            ]
        case (.leftEarly, .friendly):
            variants = [
                (String(localized: "A little more today?"), String(localized: "You're \(time) from your goal. Come back when you can.")),
                (String(localized: "You've made a start"), String(localized: "Another \(time) would reach today's goal.")),
                (String(localized: "Room for one more session?"), String(localized: "You have \(time) left. Every bit of progress counts.")),
                (String(localized: "Keep the momentum"), String(localized: "Your goal is \(time) away. We can take it one step at a time."))
            ]
        case (.goalMissed, .grumpy):
            variants = [
                (String(localized: "Goal missed"), String(localized: "You came up \(time) short today. I'm writing this down.")),
                (String(localized: "That's not the goal"), String(localized: "\(time) short. You set that goal, not me.")),
                (String(localized: "We need to talk"), String(localized: "Today's goal is \(time) away and the day is almost over.")),
                (String(localized: "Evening report: not great"), String(localized: "\(time) left on your goal. Tomorrow you owe me."))
            ]
        case (.goalMissed, .friendly):
            variants = [
                (String(localized: "Today's progress counts"), String(localized: "You're \(time) short of your goal. There's a fresh start tomorrow.")),
                (String(localized: "An evening check-in"), String(localized: "You made progress today, with \(time) left to your goal.")),
                (String(localized: "Keep going gently"), String(localized: "Your goal has \(time) left. A small session can help.")),
                (String(localized: "Look how far you got"), String(localized: "There's \(time) left today. Choose a next step that works for you."))
            ]
        case (.streakAtRisk, .grumpy):
            if brokenStreak {
                variants = [
                    (String(localized: "The streak is gone"), String(localized: "You skipped yesterday. I'm not over it yet.")),
                    (String(localized: "Streak: broken"), String(localized: "Yesterday was empty. Start a new one today.")),
                    (String(localized: "Back to day one"), String(localized: "You broke the streak. Let's see if you can build it again.")),
                    (String(localized: "I saw that"), String(localized: "No work yesterday, so the streak is gone. Clock in and fix it."))
                ]
            } else {
                variants = [
                    (String(localized: "Your streak is about to end"), String(localized: "Nothing today yet. Are you really letting it go?")),
                    (String(localized: "Save your streak"), String(localized: "One session. That's all. Don't make me watch it break.")),
                    (String(localized: "Tick tock"), String(localized: "Your streak ends at midnight unless you clock in.")),
                    (String(localized: "Seriously?"), String(localized: "All those days of work, and you're dropping the streak tonight?"))
                ]
            }
        case (.streakAtRisk, .friendly):
            if brokenStreak {
                variants = [
                    (String(localized: "A fresh beginning"), String(localized: "Yesterday was a gap. Today can be the start of a new streak.")),
                    (String(localized: "Start again together"), String(localized: "Your streak ended yesterday. Your progress is still yours.")),
                    (String(localized: "Welcome to a new day"), String(localized: "A missed day is okay. Let's build a new streak when you're ready.")),
                    (String(localized: "Another chance"), String(localized: "Yesterday is behind you. One session can begin a new streak."))
                ]
            } else {
                variants = [
                    (String(localized: "Keep your streak going"), String(localized: "A little focused time today will keep your streak alive.")),
                    (String(localized: "One small session?"), String(localized: "There's still time to add today to your streak.")),
                    (String(localized: "You've built a rhythm"), String(localized: "A session this evening can keep it going.")),
                    (String(localized: "Cheering for your streak"), String(localized: "Ready to give today a little focused time?"))
                ]
            }
        case (.noWorkToday, .grumpy):
            variants = [
                (String(localized: "No work today?"), String(localized: "I'm not mad. I'm just disappointed.")),
                (String(localized: "Why aren't you working?"), String(localized: "The timer has been at zero all day. Clock in.")),
                (String(localized: "Taking the day off?"), String(localized: "Nobody told me. The timer is still waiting.")),
                (String(localized: "Roll call"), String(localized: "Timer: here. Robot: here. You: missing."))
            ]
        case (.noWorkToday, .friendly):
            variants = [
                (String(localized: "Ready when you are"), String(localized: "A small focused session is a good way to begin today.")),
                (String(localized: "Let's make a start"), String(localized: "Your companion is here whenever you're ready to clock in.")),
                (String(localized: "A little focus today?"), String(localized: "Pick one manageable task and we'll take it from there.")),
                (String(localized: "Your next step"), String(localized: "A fresh session is waiting. Start with something small."))
            ]
        case (.goneQuiet, .grumpy):
            variants = [
                (String(localized: "Did you quit on me?"), String(localized: "Days without a single session. Where are you?")),
                (String(localized: "Not working anymore?"), String(localized: "It's been days. I'm starting to take this personally.")),
                (String(localized: "Hello, stranger"), String(localized: "I still remember what a clock-in looks like. Do you?")),
                (String(localized: "Missing: one coworker"), String(localized: "Last seen days ago. Come back and clock in."))
            ]
        case (.goneQuiet, .friendly):
            variants = [
                (String(localized: "Welcome back anytime"), String(localized: "It's been a few days. A small session can ease you back in.")),
                (String(localized: "A fresh start awaits"), String(localized: "Your progress is here whenever you're ready to return.")),
                (String(localized: "Checking in"), String(localized: "We haven't worked together lately. Start gently when you can.")),
                (String(localized: "Room for a restart"), String(localized: "One manageable task is enough to begin again."))
            ]
        }
        let reference = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let days = calendar.dateComponents([.day], from: reference, to: day).day ?? 0
        let index = ((days + kind.priority) % variants.count + variants.count) % variants.count
        return variants[index]
    }
}
