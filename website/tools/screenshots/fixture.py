#!/usr/bin/env python3
"""Writes the sample work history the website screenshots are taken from.

With no argument it writes to the Mac Debug build's own folder
("Clockin Debug"), never the data of the app you use. A path argument writes
somewhere else, for example a simulator's container for the iPhone shots.
Run through website/tools/screenshots/run.
"""
import datetime, json, pathlib, random, sys, uuid

REFERENCE = datetime.datetime(2001, 1, 1, tzinfo=datetime.timezone.utc)
SUPPORT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path.home() / "Library/Application Support/Clockin Debug"
RATE = 25.0


def stamp(when):
    return (when - REFERENCE).total_seconds()


def main():
    now = datetime.datetime.now(datetime.timezone.utc)
    local = datetime.datetime.now()
    random.seed(7)
    sessions = []
    # Ten weeks of weekday work, so the chart, heatmap and averages have
    # something to show.
    for day in range(1, 71):
        date = local - datetime.timedelta(days=day)
        if date.weekday() >= 5:
            continue
        hours = round(random.uniform(4.5, 8.5), 2)
        start_local = date.replace(hour=9, minute=random.choice([0, 15, 30]), second=0, microsecond=0)
        start = start_local.astimezone(datetime.timezone.utc)
        end = start + datetime.timedelta(hours=hours)
        sessions.append({
            "id": str(uuid.UUID(int=random.getrandbits(128))).upper(),
            "start": stamp(start),
            "end": stamp(end),
            "duration": hours * 3600,
            "note": random.choice(["", "", "Client work", "Design review", "Bug fixing"]),
            "hourlyRate": RATE,
            "source": "manual",
        })
    # Two finished stretches earlier today, so "today" and the daily goal have
    # something to show next to the running session.
    for begin, hours in [(9, 2.5), (12.5, 1.5)]:
        start_local = local.replace(hour=int(begin), minute=int((begin % 1) * 60), second=0, microsecond=0)
        start = start_local.astimezone(datetime.timezone.utc)
        if start > now - datetime.timedelta(hours=hours):
            continue
        sessions.append({
            "id": str(uuid.UUID(int=random.getrandbits(128))).upper(),
            "start": stamp(start),
            "end": stamp(start + datetime.timedelta(hours=hours)),
            "duration": hours * 3600,
            "note": "",
            "hourlyRate": RATE,
            "source": "manual",
        })
    sessions.sort(key=lambda session: session["start"])
    running_start = now - datetime.timedelta(hours=2, minutes=17)
    data = {
        "hourlyRate": RATE,
        "currencyCode": "USD",
        "sessions": sessions,
        "pinVisible": False,
        "running": {
            "start": stamp(running_start),
            "accumulated": 2 * 3600 + 17 * 60,
            "resumedAt": stamp(now),
            "note": "",
        },
        "rateRules": [{
            "id": str(uuid.UUID(int=random.getrandbits(128))).upper(),
            "effectiveFrom": stamp(now - datetime.timedelta(days=200)),
            "hourlyRate": RATE,
        }],
    }
    SUPPORT.mkdir(parents=True, exist_ok=True)
    target = SUPPORT / "clockin.json"
    target.write_text(json.dumps(data))
    print(f"{len(sessions)} sample sessions -> {target}")


if __name__ == "__main__":
    sys.exit(main())
