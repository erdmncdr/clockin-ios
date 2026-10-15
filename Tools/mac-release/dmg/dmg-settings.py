# dmgbuild settings for the Clockin installer window. package.sh runs:
#   dmgbuild -s dmg-settings.py -D staging=<folder> -D background=<tiff> Clockin <out.dmg>
#
# The window shows Clockin on the left, an arrow, and the Applications folder
# on the right. The license and attribution files ship in the image but stay
# hidden, so the window has nothing else to read. Positions match
# make-background.swift (640 x 400 pt, icon centres at (160, 180), (480, 180)).
import os.path

staging = defines['staging']  # noqa: F821 (dmgbuild provides `defines`)

format = 'UDZO'
filesystem = 'HFS+'
files = [os.path.join(staging, name) for name in ('Clockin.app', 'LICENSE.txt', 'NOTICE.md')]
symlinks = {'Applications': '/Applications'}
hide = ['LICENSE.txt', 'NOTICE.md']

background = defines['background']  # noqa: F821
window_rect = ((200, 140), (640, 400))
default_view = 'icon-view'
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
icon_size = 128
text_size = 13
arrange_by = None
grid_offset = (0, 0)
label_pos = 'bottom'
icon_locations = {
    'Clockin.app': (160, 180),
    'Applications': (480, 180),
    # Hidden, but parked outside the window in case Finder is set to show
    # hidden files.
    'LICENSE.txt': (160, 600),
    'NOTICE.md': (480, 600),
}
