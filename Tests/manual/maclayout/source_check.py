#!/usr/bin/env python3
"""Guard the layout feedback paths from review 28; runtime checks cover delivery."""
from pathlib import Path
root = Path(__file__).resolve().parents[3]
checks = {
    'chart hover does not change the inline detail height': ('Clockin/Views/Earnings/EarningsChartView.swift', 'hoveredDate ?? selectedDate'),
    'window minimum is not inferred from changing page content': ('ClockinMac/MainWindow.swift', 'host.sizingOptions = [.minSize]'),
    'control hover does not synchronously write SwiftUI state': ('Shared/Theme/ButtonStyles.swift', '.onHover { hovering = $0 }'),
    'readout hover does not synchronously write SwiftUI state': ('ClockinMac/MacChartReadout.swift', 'case .ended: readout = nil'),
}
failed = 0
for name, (file, forbidden) in checks.items():
    passed = forbidden not in (root / file).read_text()
    print(('PASS ' if passed else 'FAIL ') + name)
    failed += not passed
raise SystemExit(bool(failed))
