import Foundation

enum NudgeCopy {
    static func text(kind: NudgeKind, tone: NudgeTone, day: Date, calendar: Calendar,
                     remaining: TimeInterval, brokenStreak: Bool = false) -> (title: String, body: String) {
        let time = DurationText.compact(remaining)
        let variants: [(String, String)]
        switch (kind, tone) {
        case (.pausedTooLong, .grumpy):
            variants = [
                ("Break's over", "The coffee is cold. So am I. When are you coming back?"),
                ("Hello? Anyone there?", "This is a long break. Is it a break or a resignation?"),
                ("Still paused?", "The timer is frozen and so is your progress. Resume."),
                ("Get back here", "I paused the timer, not your goals. Come back.")
            ]
        case (.pausedTooLong, .friendly):
            variants = [
                ("Ready to return?", "You've had a breather. Resume whenever you're ready."),
                ("A gentle check-in", "Your session is paused. A small next step can help."),
                ("Your desk is ready", "Take a sip, stretch, and ease back in."),
                ("Pick up where you left off", "Your progress is waiting. Shall we continue?")
            ]
        case (.leftEarly, .grumpy):
            variants = [
                ("You left halfway", "\(time) short and you just walked off? When are you coming back?"),
                ("Leaving already?", "Your goal is \(time) away. I'm not impressed."),
                ("Hey, where did you go?", "You stopped with \(time) left. I'm keeping score."),
                ("Unfinished business", "\(time) left on today's goal. The chair is still warm. Get back here.")
            ]
        case (.leftEarly, .friendly):
            variants = [
                ("A little more today?", "You're \(time) from your goal. Come back when you can."),
                ("You've made a start", "Another \(time) would reach today's goal."),
                ("Room for one more session?", "You have \(time) left. Every bit of progress counts."),
                ("Keep the momentum", "Your goal is \(time) away. We can take it one step at a time.")
            ]
        case (.goalMissed, .grumpy):
            variants = [
                ("Goal missed", "You came up \(time) short today. I'm writing this down."),
                ("That's not the goal", "\(time) short. You set that goal, not me."),
                ("We need to talk", "Today's goal is \(time) away and the day is almost over."),
                ("Evening report: not great", "\(time) left on your goal. Tomorrow you owe me.")
            ]
        case (.goalMissed, .friendly):
            variants = [
                ("Today's progress counts", "You're \(time) short of your goal. There's a fresh start tomorrow."),
                ("An evening check-in", "You made progress today, with \(time) left to your goal."),
                ("Keep going gently", "Your goal has \(time) left. A small session can help."),
                ("Look how far you got", "There's \(time) left today. Choose a next step that works for you.")
            ]
        case (.streakAtRisk, .grumpy):
            if brokenStreak {
                variants = [
                    ("The streak is gone", "You skipped yesterday. I'm not over it yet."),
                    ("Streak: broken", "Yesterday was empty. Start a new one today."),
                    ("Back to day one", "You broke the streak. Let's see if you can build it again."),
                    ("I saw that", "No work yesterday, so the streak is gone. Clock in and fix it.")
                ]
            } else {
                variants = [
                    ("Your streak is about to end", "Nothing today yet. Are you really letting it go?"),
                    ("Save your streak", "One session. That's all. Don't make me watch it break."),
                    ("Tick tock", "Your streak ends at midnight unless you clock in."),
                    ("Seriously?", "All those days of work, and you're dropping the streak tonight?")
                ]
            }
        case (.streakAtRisk, .friendly):
            if brokenStreak {
                variants = [
                    ("A fresh beginning", "Yesterday was a gap. Today can be the start of a new streak."),
                    ("Start again together", "Your streak ended yesterday. Your progress is still yours."),
                    ("Welcome to a new day", "A missed day is okay. Let's build a new streak when you're ready."),
                    ("Another chance", "Yesterday is behind you. One session can begin a new streak.")
                ]
            } else {
                variants = [
                    ("Keep your streak going", "A little focused time today will keep your streak alive."),
                    ("One small session?", "There's still time to add today to your streak."),
                    ("You've built a rhythm", "A session this evening can keep it going."),
                    ("Cheering for your streak", "Ready to give today a little focused time?")
                ]
            }
        case (.noWorkToday, .grumpy):
            variants = [
                ("No work today?", "I'm not mad. I'm just disappointed."),
                ("Why aren't you working?", "The timer has been at zero all day. Clock in."),
                ("Taking the day off?", "Nobody told me. The timer is still waiting."),
                ("Roll call", "Timer: here. Robot: here. You: missing.")
            ]
        case (.noWorkToday, .friendly):
            variants = [
                ("Ready when you are", "A small focused session is a good way to begin today."),
                ("Let's make a start", "Your companion is here whenever you're ready to clock in."),
                ("A little focus today?", "Pick one manageable task and we'll take it from there."),
                ("Your next step", "A fresh session is waiting. Start with something small.")
            ]
        case (.goneQuiet, .grumpy):
            variants = [
                ("Did you quit on me?", "Days without a single session. Where are you?"),
                ("Not working anymore?", "It's been days. I'm starting to take this personally."),
                ("Hello, stranger", "I still remember what a clock-in looks like. Do you?"),
                ("Missing: one coworker", "Last seen days ago. Come back and clock in.")
            ]
        case (.goneQuiet, .friendly):
            variants = [
                ("Welcome back anytime", "It's been a few days. A small session can ease you back in."),
                ("A fresh start awaits", "Your progress is here whenever you're ready to return."),
                ("Checking in", "We haven't worked together lately. Start gently when you can."),
                ("Room for a restart", "One manageable task is enough to begin again.")
            ]
        }
        let reference = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 0))
        let days = calendar.dateComponents([.day], from: reference, to: day).day ?? 0
        let index = ((days + kind.priority) % variants.count + variants.count) % variants.count
        return variants[index]
    }
}
