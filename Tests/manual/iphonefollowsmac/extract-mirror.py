"""Uretim yasam dongusunu macOS'te sahte ActivityKit/relay sinirlarinda calistir."""
from pathlib import Path
import sys

out = Path(sys.argv[1])
source = Path("Shared/Sync/SessionMirror.swift").read_text()
body = source[source.index("    private func syncActivity("):source.rindex("    #endif")]
body = body.replace("    private func syncActivity(", "    func syncActivity(")
body = body.replace("try? Activity.request(", "try? Activity<ClockinActivityAttributes>.request(")
(out / "ExtractedMirror.swift").write_text(
    "import Foundation\n@MainActor final class ExtractedMirror {\n"
    "private var lastState: ClockinActivityAttributes.ContentState?\n"
    "private var activityTask: Task<Void, Never>?\n"
    "func finish() async { await activityTask?.value }\n" + body + "}\n"
)
(out / "Attributes.swift").write_text(
    Path("Shared/Sync/ClockinActivityAttributes.swift").read_text().replace("import ActivityKit\n", "")
)
