# Notepad toolbar icons

WoW cannot load SVG. The editable sources are the SVG files in `src/` (original drawings, no third-party art); the game loads the 64x64 PNG files next to them
(PNG needs power-of-two sizes and the explicit `.png` extension in the path). To rebuild after editing a source:

    rsvg-convert -w 64 -h 64 src/plus.svg -o plus.png

The icons are white on transparent; Notepad.lua tints them.
