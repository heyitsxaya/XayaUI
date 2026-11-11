#!/usr/bin/env python3
"""Platform split P4 (XayaUI 0.6.76, XayaUI Rules 0.6.76; docs/plans/PLATFORM-SPLIT-2026-11-07.md section 6.2 and risk R6: "Old share
strings stop importing" -> "a test imports a pre-split string of each kind"). The rules kind moved from the Platform's Share.lua to
XayaUI_Rules/RuleShare.lua; no string format changed. Loads the real addons in the stand-in game and checks what the player gets:
  A every kind shared before the split imports: GOLDEN below holds strings made by the code before the split (main 8ced2e3; made by
    `python3 tests/share_strings_presplit_run.py --golden` in a checkout of it): one rule with its cue, a group with a nested group and
    its rules, all rules (Share_SnapshotAll, also what a backup holds), a theme and a profile with every part. Each is read by its own
    kind, and imported: the rules land as the old code put them (rule names, the cue under its rule, the groups), the theme's colour
    is back, the profile's parts apply.
  B the same setup shared now gives byte-for-byte the same strings (the format did not change).
    (Debug chat defaults, Chat 0.6.46) the profile's one allowed difference: the Sidebar's and the privacy cover's defaults (37 keys,
    each with its default value) now in the Blizzard Reskin part; taken out, the string is the pre-split one byte for byte.
  C XayaUI Rules switched off: the rules strings say "needs XayaUI Rules" and change nothing; the theme still imports; the profile
    lists its rules part as "needs XayaUI Rules", skips it and imports the rest.
Negative control: C fails on 8ced2e3 (there is no XayaUI Rules to switch off: the rules kind is always there). A and B pass there by
design: they are the reference the new code must match.
Run: python3 tests/share_strings_presplit_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)
sys.path.insert(0, HERE)
import settings_stores as SST  # noqa: E402  (where each module keeps its settings)

# made by the code before the split (main 8ced2e3) with --golden; see the docstring
GOLDEN = {
    "rule": (
        "XUI1:5a53d36d:eyJhZGRvblZlcnNpb24iOiIwLjYuNzUiLCJmb2xkZXJzIjp7fSwibmFtZSI6IiIsInJ1bGVzIjpbeyJidWZmSUQiOjEyMzQs"
        "ImJ1ZmZTdGF0ZSI6InByZXNlbnQiLCJlbmFibGVkIjp0cnVlLCJleHRyYSI6eyJsaXN0Ijp7fX0sImxvYWQiOnsiaW5zdGFuY2VUeXBlcyI6e3"
        "19LCJtYXhDaGFyZ2VzIjowLCJuYW1lIjoiU2hhcmVkIHJ1bGUiLCJyZXBlYXRTZWMiOjAsInNvdW5kIjp7ImVuYWJsZWQiOmZhbHNlLCJzb3Vy"
        "Y2UiOiJraXQiLCJ2YWx1ZSI6IiJ9LCJzcGVsbElEIjowLCJ0YWxlbnRzIjp7fSwidWlkIjoidVNoYXJlZDEiLCJ1c2VCdWZmIjp0cnVlLCJ1c2"
        "VDb29sZG93biI6ZmFsc2UsInZpc3VhbCI6eyJhYnNvcmIiOnsiYWJicmV2aWF0ZSI6dHJ1ZSwiY29sb3IiOlswLjksMC45LDEsMV0sImVuYWJs"
        "ZWQiOmZhbHNlLCJoaWRlWmVybyI6dHJ1ZSwic2l6ZSI6MTgsIngiOjAsInkiOjB9LCJhZGRpdGl2ZSI6ZmFsc2UsImFscGhhIjoxLCJiZyI6ey"
        "Jjb2xvciI6WzAsMCwwLDAuNV0sImVuYWJsZWQiOmZhbHNlfSwiYm9yZGVyIjp7ImNvbG9yIjpbMCwwLDAsMV0sImVuYWJsZWQiOmZhbHNlLCJz"
        "aXplIjoxfSwiY291bnQiOnsiY29sb3IiOlsxLDEsMSwxXSwiZW5hYmxlZCI6ZmFsc2UsInNpemUiOjE0LCJ4IjowLCJ5IjowfSwiZGVzYXRPbk"
        "NEIjpmYWxzZSwiZGVzYXR1cmF0ZSI6ZmFsc2UsImVuYWJsZWQiOmZhbHNlLCJmYWRlQWxwaGEiOmZhbHNlLCJmYWRlQWxwaGFNYXgiOjEsImZh"
        "ZGVBbHBoYU1pbiI6MC4xNSwiZmFkZUNvbG9yIjpbMSwwLjEsMC4xLDFdLCJmYWRlR3JleSI6ZmFsc2UsImZpbGwiOnsiZW5hYmxlZCI6ZmFsc2"
        "UsIm1heCI6MSwibWluIjowLCJyZXZlcnNlIjpmYWxzZX0sImZsYXNoIjp7ImVuYWJsZWQiOmZhbHNlLCJzcGVlZCI6MywidGhyZXNob2xkIjoz"
        "fSwiZmxpcEgiOmZhbHNlLCJmbGlwViI6ZmFsc2UsImdsb3ciOmZhbHNlLCJoIjoxMjgsImljb25IIjowLCJpY29uVyI6MCwia2VlcEFzcGVjdC"
        "I6dHJ1ZSwib29jQWxwaGEiOjEsIm91dGxpbmUiOnsiYm9yZGVyT24iOnRydWUsImNvbG9yIjpbMSwwLjgyLDAsMV0sImVuYWJsZWQiOmZhbHNl"
        "LCJnYXAiOjAsImdsb3dBbHBoYSI6MC42LCJnbG93Q29sb3IiOlsxLDAuODIsMCwxXSwiZ2xvd09uIjp0cnVlLCJnbG93U2FtZSI6dHJ1ZSwiZ2"
        "xvd1NpemUiOjgsInB1bHNlIjpmYWxzZSwic3R5bGUiOiJhdXRvIiwid2lkdGgiOjJ9LCJvdmVybGF5Ijp7ImFkZGl0aXZlIjpmYWxzZSwiYWR2"
        "YW5jZWQiOmZhbHNlLCJhbHBoYSI6MSwiZGVzYXR1cmF0ZSI6ZmFsc2UsImVuYWJsZWQiOmZhbHNlLCJ0ZXgiOiIiLCJ0aW50IjpbMSwxLDEsMV"
        "19LCJyZWNvbG9yIjpmYWxzZSwicmVxdWlyZU9uQmFyIjpmYWxzZSwicm90YXRpb24iOjAsInRleCI6IiIsInRleEFscGhhIjoxLCJ0ZXh0Ijp7"
        "ImNvbG9yIjpbMSwxLDEsMV0sImRlY2ltYWxCZWxvdyI6NSwiZGVjaW1hbHMiOnRydWUsImVuYWJsZWQiOmZhbHNlLCJzaXplIjoyMCwieCI6MC"
        "wieSI6MH0sInRpbnQiOlsxLDEsMSwxXSwidyI6MTI4LCJ4IjowLCJ5IjowLCJ6b29tIjowfSwid2hlbiI6eyJsaXN0Ijp7fX19LHsiYnVmZklE"
        "IjowLCJjdWVLZXkiOiJxYSIsImN1ZUtpbmQiOiJzb3VuZCIsImVuYWJsZWQiOnRydWUsImV4dHJhIjp7Imxpc3QiOnt9fSwiaXNDdWUiOnRydW"
        "UsImxvYWQiOnsiaW5zdGFuY2VUeXBlcyI6e319LCJtYXhDaGFyZ2VzIjowLCJuYW1lIjoiSXRzIGN1ZSIsInBhcmVudFVpZCI6InVTaGFyZWQx"
        "IiwicmVwZWF0U2VjIjowLCJzb3VuZCI6eyJlbmFibGVkIjpmYWxzZSwic291cmNlIjoia2l0IiwidmFsdWUiOiIifSwic3BlbGxJRCI6MCwidG"
        "FsZW50cyI6e30sInVzZUJ1ZmYiOmZhbHNlLCJ1c2VDb29sZG93biI6ZmFsc2UsInZpc3VhbCI6eyJhYnNvcmIiOnsiYWJicmV2aWF0ZSI6dHJ1"
        "ZSwiY29sb3IiOlswLjksMC45LDEsMV0sImVuYWJsZWQiOmZhbHNlLCJoaWRlWmVybyI6dHJ1ZSwic2l6ZSI6MTgsIngiOjAsInkiOjB9LCJhZG"
        "RpdGl2ZSI6ZmFsc2UsImFscGhhIjoxLCJiZyI6eyJjb2xvciI6WzAsMCwwLDAuNV0sImVuYWJsZWQiOmZhbHNlfSwiYm9yZGVyIjp7ImNvbG9y"
        "IjpbMCwwLDAsMV0sImVuYWJsZWQiOmZhbHNlLCJzaXplIjoxfSwiY291bnQiOnsiY29sb3IiOlsxLDEsMSwxXSwiZW5hYmxlZCI6ZmFsc2UsIn"
        "NpemUiOjE0LCJ4IjowLCJ5IjowfSwiZGVzYXRPbkNEIjpmYWxzZSwiZGVzYXR1cmF0ZSI6ZmFsc2UsImVuYWJsZWQiOmZhbHNlLCJmYWRlQWxw"
        "aGEiOmZhbHNlLCJmYWRlQWxwaGFNYXgiOjEsImZhZGVBbHBoYU1pbiI6MC4xNSwiZmFkZUNvbG9yIjpbMSwwLjEsMC4xLDFdLCJmYWRlR3JleS"
        "I6ZmFsc2UsImZpbGwiOnsiZW5hYmxlZCI6ZmFsc2UsIm1heCI6MSwibWluIjowLCJyZXZlcnNlIjpmYWxzZX0sImZsYXNoIjp7ImVuYWJsZWQi"
        "OmZhbHNlLCJzcGVlZCI6MywidGhyZXNob2xkIjozfSwiZmxpcEgiOmZhbHNlLCJmbGlwViI6ZmFsc2UsImdsb3ciOmZhbHNlLCJoIjoxMjgsIm"
        "ljb25IIjowLCJpY29uVyI6MCwia2VlcEFzcGVjdCI6dHJ1ZSwib29jQWxwaGEiOjEsIm91dGxpbmUiOnsiYm9yZGVyT24iOnRydWUsImNvbG9y"
        "IjpbMSwwLjgyLDAsMV0sImVuYWJsZWQiOmZhbHNlLCJnYXAiOjAsImdsb3dBbHBoYSI6MC42LCJnbG93Q29sb3IiOlsxLDAuODIsMCwxXSwiZ2"
        "xvd09uIjp0cnVlLCJnbG93U2FtZSI6dHJ1ZSwiZ2xvd1NpemUiOjgsInB1bHNlIjpmYWxzZSwic3R5bGUiOiJhdXRvIiwid2lkdGgiOjJ9LCJv"
        "dmVybGF5Ijp7ImFkZGl0aXZlIjpmYWxzZSwiYWR2YW5jZWQiOmZhbHNlLCJhbHBoYSI6MSwiZGVzYXR1cmF0ZSI6ZmFsc2UsImVuYWJsZWQiOm"
        "ZhbHNlLCJ0ZXgiOiIiLCJ0aW50IjpbMSwxLDEsMV19LCJyZWNvbG9yIjpmYWxzZSwicmVxdWlyZU9uQmFyIjpmYWxzZSwicm90YXRpb24iOjAs"
        "InRleCI6IiIsInRleEFscGhhIjoxLCJ0ZXh0Ijp7ImNvbG9yIjpbMSwxLDEsMV0sImRlY2ltYWxCZWxvdyI6NSwiZGVjaW1hbHMiOnRydWUsIm"
        "VuYWJsZWQiOmZhbHNlLCJzaXplIjoyMCwieCI6MCwieSI6MH0sInRpbnQiOlsxLDEsMSwxXSwidyI6MTI4LCJ4IjowLCJ5IjowLCJ6b29tIjow"
        "fSwid2hlbiI6eyJsaXN0Ijp7fX19XSwidiI6MX0="),
    "group": (
        "XUI1:be79f407:eyJhZGRvblZlcnNpb24iOiIwLjYuNzUiLCJmb2xkZXJzIjpbeyJpZCI6ImYxNzk0MDAwMDAwNTYzMyIsIm5hbWUiOiJTaGFy"
        "ZWQgZ3JvdXAiLCJvcmlnaW4iOnsiYXQiOjE3OTQwMDAwMDAsImJ5IjoiWGF5YS1BcmVhIDUyIiwiaG93IjoibWFkZSJ9fSx7ImlkIjoiZjE3OT"
        "QwMDAwMDA5OTYzIiwibmFtZSI6IklubmVyIiwib3JpZ2luIjp7ImF0IjoxNzk0MDAwMDAwLCJieSI6IlhheWEtQXJlYSA1MiIsImhvdyI6Im1h"
        "ZGUifSwicGFyZW50IjoiZjE3OTQwMDAwMDA1NjMzIn1dLCJuYW1lIjoiIiwicnVsZXMiOlt7ImJ1ZmZJRCI6MTIzNCwiYnVmZlN0YXRlIjoicH"
        "Jlc2VudCIsImVuYWJsZWQiOnRydWUsImV4dHJhIjp7Imxpc3QiOnt9fSwiZm9sZGVyIjoiZjE3OTQwMDAwMDA1NjMzIiwibG9hZCI6eyJpbnN0"
        "YW5jZVR5cGVzIjp7fX0sIm1heENoYXJnZXMiOjAsIm5hbWUiOiJTaGFyZWQgcnVsZSIsInJlcGVhdFNlYyI6MCwic291bmQiOnsiZW5hYmxlZC"
        "I6ZmFsc2UsInNvdXJjZSI6ImtpdCIsInZhbHVlIjoiIn0sInNwZWxsSUQiOjAsInRhbGVudHMiOnt9LCJ1aWQiOiJ1U2hhcmVkMSIsInVzZUJ1"
        "ZmYiOnRydWUsInVzZUNvb2xkb3duIjpmYWxzZSwidmlzdWFsIjp7ImFic29yYiI6eyJhYmJyZXZpYXRlIjp0cnVlLCJjb2xvciI6WzAuOSwwLj"
        "ksMSwxXSwiZW5hYmxlZCI6ZmFsc2UsImhpZGVaZXJvIjp0cnVlLCJzaXplIjoxOCwieCI6MCwieSI6MH0sImFkZGl0aXZlIjpmYWxzZSwiYWxw"
        "aGEiOjEsImJnIjp7ImNvbG9yIjpbMCwwLDAsMC41XSwiZW5hYmxlZCI6ZmFsc2V9LCJib3JkZXIiOnsiY29sb3IiOlswLDAsMCwxXSwiZW5hYm"
        "xlZCI6ZmFsc2UsInNpemUiOjF9LCJjb3VudCI6eyJjb2xvciI6WzEsMSwxLDFdLCJlbmFibGVkIjpmYWxzZSwic2l6ZSI6MTQsIngiOjAsInki"
        "OjB9LCJkZXNhdE9uQ0QiOmZhbHNlLCJkZXNhdHVyYXRlIjpmYWxzZSwiZW5hYmxlZCI6ZmFsc2UsImZhZGVBbHBoYSI6ZmFsc2UsImZhZGVBbH"
        "BoYU1heCI6MSwiZmFkZUFscGhhTWluIjowLjE1LCJmYWRlQ29sb3IiOlsxLDAuMSwwLjEsMV0sImZhZGVHcmV5IjpmYWxzZSwiZmlsbCI6eyJl"
        "bmFibGVkIjpmYWxzZSwibWF4IjoxLCJtaW4iOjAsInJldmVyc2UiOmZhbHNlfSwiZmxhc2giOnsiZW5hYmxlZCI6ZmFsc2UsInNwZWVkIjozLC"
        "J0aHJlc2hvbGQiOjN9LCJmbGlwSCI6ZmFsc2UsImZsaXBWIjpmYWxzZSwiZ2xvdyI6ZmFsc2UsImgiOjEyOCwiaWNvbkgiOjAsImljb25XIjow"
        "LCJrZWVwQXNwZWN0Ijp0cnVlLCJvb2NBbHBoYSI6MSwib3V0bGluZSI6eyJib3JkZXJPbiI6dHJ1ZSwiY29sb3IiOlsxLDAuODIsMCwxXSwiZW"
        "5hYmxlZCI6ZmFsc2UsImdhcCI6MCwiZ2xvd0FscGhhIjowLjYsImdsb3dDb2xvciI6WzEsMC44MiwwLDFdLCJnbG93T24iOnRydWUsImdsb3dT"
        "YW1lIjp0cnVlLCJnbG93U2l6ZSI6OCwicHVsc2UiOmZhbHNlLCJzdHlsZSI6ImF1dG8iLCJ3aWR0aCI6Mn0sIm92ZXJsYXkiOnsiYWRkaXRpdm"
        "UiOmZhbHNlLCJhZHZhbmNlZCI6ZmFsc2UsImFscGhhIjoxLCJkZXNhdHVyYXRlIjpmYWxzZSwiZW5hYmxlZCI6ZmFsc2UsInRleCI6IiIsInRp"
        "bnQiOlsxLDEsMSwxXX0sInJlY29sb3IiOmZhbHNlLCJyZXF1aXJlT25CYXIiOmZhbHNlLCJyb3RhdGlvbiI6MCwidGV4IjoiIiwidGV4QWxwaG"
        "EiOjEsInRleHQiOnsiY29sb3IiOlsxLDEsMSwxXSwiZGVjaW1hbEJlbG93Ijo1LCJkZWNpbWFscyI6dHJ1ZSwiZW5hYmxlZCI6ZmFsc2UsInNp"
        "emUiOjIwLCJ4IjowLCJ5IjowfSwidGludCI6WzEsMSwxLDFdLCJ3IjoxMjgsIngiOjAsInkiOjAsInpvb20iOjB9LCJ3aGVuIjp7Imxpc3QiOn"
        "t9fX0seyJidWZmSUQiOjAsImVuYWJsZWQiOnRydWUsImV4dHJhIjp7Imxpc3QiOnt9fSwiZm9sZGVyIjoiZjE3OTQwMDAwMDA5OTYzIiwibG9h"
        "ZCI6eyJpbnN0YW5jZVR5cGVzIjp7fX0sIm1heENoYXJnZXMiOjAsIm5hbWUiOiJJbm5lciBydWxlIiwicmVwZWF0U2VjIjowLCJzb3VuZCI6ey"
        "JlbmFibGVkIjpmYWxzZSwic291cmNlIjoia2l0IiwidmFsdWUiOiIifSwic3BlbGxJRCI6MCwidGFsZW50cyI6e30sInVpZCI6InVTaGFyZWQy"
        "IiwidXNlQnVmZiI6ZmFsc2UsInVzZUNvb2xkb3duIjpmYWxzZSwidmlzdWFsIjp7ImFic29yYiI6eyJhYmJyZXZpYXRlIjp0cnVlLCJjb2xvci"
        "I6WzAuOSwwLjksMSwxXSwiZW5hYmxlZCI6ZmFsc2UsImhpZGVaZXJvIjp0cnVlLCJzaXplIjoxOCwieCI6MCwieSI6MH0sImFkZGl0aXZlIjpm"
        "YWxzZSwiYWxwaGEiOjEsImJnIjp7ImNvbG9yIjpbMCwwLDAsMC41XSwiZW5hYmxlZCI6ZmFsc2V9LCJib3JkZXIiOnsiY29sb3IiOlswLDAsMC"
        "wxXSwiZW5hYmxlZCI6ZmFsc2UsInNpemUiOjF9LCJjb3VudCI6eyJjb2xvciI6WzEsMSwxLDFdLCJlbmFibGVkIjpmYWxzZSwic2l6ZSI6MTQs"
        "IngiOjAsInkiOjB9LCJkZXNhdE9uQ0QiOmZhbHNlLCJkZXNhdHVyYXRlIjpmYWxzZSwiZW5hYmxlZCI6ZmFsc2UsImZhZGVBbHBoYSI6ZmFsc2"
        "UsImZhZGVBbHBoYU1heCI6MSwiZmFkZUFscGhhTWluIjowLjE1LCJmYWRlQ29sb3IiOlsxLDAuMSwwLjEsMV0sImZhZGVHcmV5IjpmYWxzZSwi"
        "ZmlsbCI6eyJlbmFibGVkIjpmYWxzZSwibWF4IjoxLCJtaW4iOjAsInJldmVyc2UiOmZhbHNlfSwiZmxhc2giOnsiZW5hYmxlZCI6ZmFsc2UsIn"
        "NwZWVkIjozLCJ0aHJlc2hvbGQiOjN9LCJmbGlwSCI6ZmFsc2UsImZsaXBWIjpmYWxzZSwiZ2xvdyI6ZmFsc2UsImgiOjEyOCwiaWNvbkgiOjAs"
        "Imljb25XIjowLCJrZWVwQXNwZWN0Ijp0cnVlLCJvb2NBbHBoYSI6MSwib3V0bGluZSI6eyJib3JkZXJPbiI6dHJ1ZSwiY29sb3IiOlsxLDAuOD"
        "IsMCwxXSwiZW5hYmxlZCI6ZmFsc2UsImdhcCI6MCwiZ2xvd0FscGhhIjowLjYsImdsb3dDb2xvciI6WzEsMC44MiwwLDFdLCJnbG93T24iOnRy"
        "dWUsImdsb3dTYW1lIjp0cnVlLCJnbG93U2l6ZSI6OCwicHVsc2UiOmZhbHNlLCJzdHlsZSI6ImF1dG8iLCJ3aWR0aCI6Mn0sIm92ZXJsYXkiOn"
        "siYWRkaXRpdmUiOmZhbHNlLCJhZHZhbmNlZCI6ZmFsc2UsImFscGhhIjoxLCJkZXNhdHVyYXRlIjpmYWxzZSwiZW5hYmxlZCI6ZmFsc2UsInRl"
        "eCI6IiIsInRpbnQiOlsxLDEsMSwxXX0sInJlY29sb3IiOmZhbHNlLCJyZXF1aXJlT25CYXIiOmZhbHNlLCJyb3RhdGlvbiI6MCwidGV4IjoiIi"
        "widGV4QWxwaGEiOjEsInRleHQiOnsiY29sb3IiOlsxLDEsMSwxXSwiZGVjaW1hbEJlbG93Ijo1LCJkZWNpbWFscyI6dHJ1ZSwiZW5hYmxlZCI6"
        "ZmFsc2UsInNpemUiOjIwLCJ4IjowLCJ5IjowfSwidGludCI6WzEsMSwxLDFdLCJ3IjoxMjgsIngiOjAsInkiOjAsInpvb20iOjB9LCJ3aGVuIj"
        "p7Imxpc3QiOnt9fX0seyJidWZmSUQiOjAsImN1ZUtleSI6InFhIiwiY3VlS2luZCI6InNvdW5kIiwiZW5hYmxlZCI6dHJ1ZSwiZXh0cmEiOnsi"
        "bGlzdCI6e319LCJpc0N1ZSI6dHJ1ZSwibG9hZCI6eyJpbnN0YW5jZVR5cGVzIjp7fX0sIm1heENoYXJnZXMiOjAsIm5hbWUiOiJJdHMgY3VlIi"
        "wicGFyZW50VWlkIjoidVNoYXJlZDEiLCJyZXBlYXRTZWMiOjAsInNvdW5kIjp7ImVuYWJsZWQiOmZhbHNlLCJzb3VyY2UiOiJraXQiLCJ2YWx1"
        "ZSI6IiJ9LCJzcGVsbElEIjowLCJ0YWxlbnRzIjp7fSwidXNlQnVmZiI6ZmFsc2UsInVzZUNvb2xkb3duIjpmYWxzZSwidmlzdWFsIjp7ImFic2"
        "9yYiI6eyJhYmJyZXZpYXRlIjp0cnVlLCJjb2xvciI6WzAuOSwwLjksMSwxXSwiZW5hYmxlZCI6ZmFsc2UsImhpZGVaZXJvIjp0cnVlLCJzaXpl"
        "IjoxOCwieCI6MCwieSI6MH0sImFkZGl0aXZlIjpmYWxzZSwiYWxwaGEiOjEsImJnIjp7ImNvbG9yIjpbMCwwLDAsMC41XSwiZW5hYmxlZCI6Zm"
        "Fsc2V9LCJib3JkZXIiOnsiY29sb3IiOlswLDAsMCwxXSwiZW5hYmxlZCI6ZmFsc2UsInNpemUiOjF9LCJjb3VudCI6eyJjb2xvciI6WzEsMSwx"
        "LDFdLCJlbmFibGVkIjpmYWxzZSwic2l6ZSI6MTQsIngiOjAsInkiOjB9LCJkZXNhdE9uQ0QiOmZhbHNlLCJkZXNhdHVyYXRlIjpmYWxzZSwiZW"
        "5hYmxlZCI6ZmFsc2UsImZhZGVBbHBoYSI6ZmFsc2UsImZhZGVBbHBoYU1heCI6MSwiZmFkZUFscGhhTWluIjowLjE1LCJmYWRlQ29sb3IiOlsx"
        "LDAuMSwwLjEsMV0sImZhZGVHcmV5IjpmYWxzZSwiZmlsbCI6eyJlbmFibGVkIjpmYWxzZSwibWF4IjoxLCJtaW4iOjAsInJldmVyc2UiOmZhbH"
        "NlfSwiZmxhc2giOnsiZW5hYmxlZCI6ZmFsc2UsInNwZWVkIjozLCJ0aHJlc2hvbGQiOjN9LCJmbGlwSCI6ZmFsc2UsImZsaXBWIjpmYWxzZSwi"
        "Z2xvdyI6ZmFsc2UsImgiOjEyOCwiaWNvbkgiOjAsImljb25XIjowLCJrZWVwQXNwZWN0Ijp0cnVlLCJvb2NBbHBoYSI6MSwib3V0bGluZSI6ey"
        "Jib3JkZXJPbiI6dHJ1ZSwiY29sb3IiOlsxLDAuODIsMCwxXSwiZW5hYmxlZCI6ZmFsc2UsImdhcCI6MCwiZ2xvd0FscGhhIjowLjYsImdsb3dD"
        "b2xvciI6WzEsMC44MiwwLDFdLCJnbG93T24iOnRydWUsImdsb3dTYW1lIjp0cnVlLCJnbG93U2l6ZSI6OCwicHVsc2UiOmZhbHNlLCJzdHlsZS"
        "I6ImF1dG8iLCJ3aWR0aCI6Mn0sIm92ZXJsYXkiOnsiYWRkaXRpdmUiOmZhbHNlLCJhZHZhbmNlZCI6ZmFsc2UsImFscGhhIjoxLCJkZXNhdHVy"
        "YXRlIjpmYWxzZSwiZW5hYmxlZCI6ZmFsc2UsInRleCI6IiIsInRpbnQiOlsxLDEsMSwxXX0sInJlY29sb3IiOmZhbHNlLCJyZXF1aXJlT25CYX"
        "IiOmZhbHNlLCJyb3RhdGlvbiI6MCwidGV4IjoiIiwidGV4QWxwaGEiOjEsInRleHQiOnsiY29sb3IiOlsxLDEsMSwxXSwiZGVjaW1hbEJlbG93"
        "Ijo1LCJkZWNpbWFscyI6dHJ1ZSwiZW5hYmxlZCI6ZmFsc2UsInNpemUiOjIwLCJ4IjowLCJ5IjowfSwidGludCI6WzEsMSwxLDFdLCJ3IjoxMj"
        "gsIngiOjAsInkiOjAsInpvb20iOjB9LCJ3aGVuIjp7Imxpc3QiOnt9fX1dLCJ2IjoxfQ=="),
    "all": (
        "XUI1:cc6bb3a4:eyJhZGRvblZlcnNpb24iOiIwLjYuNzUiLCJmb2xkZXJzIjpbeyJkZWZhdWx0IjoiZGlzcGxheSIsImlkIjoiZjE3OTQwMDAw"
        "MDA1MzgyIiwibmFtZSI6IkRpc3BsYXkgQ3VlcyIsIm9yaWdpbiI6eyJhdCI6MTc5NDAwMDAwMCwiYnkiOiJYYXlhLUFyZWEgNTIiLCJob3ciOi"
        "JkZWZhdWx0In19LHsiZGVmYXVsdCI6InNvdW5kIiwiaWQiOiJmMTc5NDAwMDAwMDg4MTEiLCJuYW1lIjoiU291bmQgQ3VlcyIsIm9yaWdpbiI6"
        "eyJhdCI6MTc5NDAwMDAwMCwiYnkiOiJYYXlhLUFyZWEgNTIiLCJob3ciOiJkZWZhdWx0In19LHsiZGVmYXVsdCI6Imh5YnJpZCIsImlkIjoiZj"
        "E3OTQwMDAwMDA2MzMzIiwibmFtZSI6Ikh5YnJpZCBDdWVzIiwib3JpZ2luIjp7ImF0IjoxNzk0MDAwMDAwLCJieSI6IlhheWEtQXJlYSA1MiIs"
        "ImhvdyI6ImRlZmF1bHQifX0seyJkZWZhdWx0IjoiYWR2YW5jZWQiLCJpZCI6ImYxNzk0MDAwMDAwMjkzMiIsIm5hbWUiOiJBZHZhbmNlZCBDdW"
        "UgVHJhY2tpbmciLCJvcmlnaW4iOnsiYXQiOjE3OTQwMDAwMDAsImJ5IjoiWGF5YS1BcmVhIDUyIiwiaG93IjoiZGVmYXVsdCJ9fSx7ImRlZmF1"
        "bHQiOiJjdXJzb3IiLCJpZCI6ImYxNzk0MDAwMDAwMTA5MiIsIm5hbWUiOiJNb3VzZSBDdXJzb3IgQ3VlcyIsIm9yaWdpbiI6eyJhdCI6MTc5ND"
        "AwMDAwMCwiYnkiOiJYYXlhLUFyZWEgNTIiLCJob3ciOiJkZWZhdWx0In19LHsiaWQiOiJmMTc5NDAwMDAwMDU2MzMiLCJuYW1lIjoiU2hhcmVk"
        "IGdyb3VwIiwib3JpZ2luIjp7ImF0IjoxNzk0MDAwMDAwLCJieSI6IlhheWEtQXJlYSA1MiIsImhvdyI6Im1hZGUifX0seyJpZCI6ImYxNzk0MD"
        "AwMDAwOTk2MyIsIm5hbWUiOiJJbm5lciIsIm9yaWdpbiI6eyJhdCI6MTc5NDAwMDAwMCwiYnkiOiJYYXlhLUFyZWEgNTIiLCJob3ciOiJtYWRl"
        "In0sInBhcmVudCI6ImYxNzk0MDAwMDAwNTYzMyJ9XSwibmFtZSI6IiIsInJ1bGVzIjpbeyJidWZmSUQiOjEyMzQsImJ1ZmZTdGF0ZSI6InByZX"
        "NlbnQiLCJlbmFibGVkIjp0cnVlLCJleHRyYSI6eyJsaXN0Ijp7fX0sImZvbGRlciI6ImYxNzk0MDAwMDAwNTYzMyIsImxvYWQiOnsiaW5zdGFu"
        "Y2VUeXBlcyI6e319LCJtYXhDaGFyZ2VzIjowLCJuYW1lIjoiU2hhcmVkIHJ1bGUiLCJyZXBlYXRTZWMiOjAsInNvdW5kIjp7ImVuYWJsZWQiOm"
        "ZhbHNlLCJzb3VyY2UiOiJraXQiLCJ2YWx1ZSI6IiJ9LCJzcGVsbElEIjowLCJ0YWxlbnRzIjp7fSwidWlkIjoidVNoYXJlZDEiLCJ1c2VCdWZm"
        "Ijp0cnVlLCJ1c2VDb29sZG93biI6ZmFsc2UsInZpc3VhbCI6eyJhYnNvcmIiOnsiYWJicmV2aWF0ZSI6dHJ1ZSwiY29sb3IiOlswLjksMC45LD"
        "EsMV0sImVuYWJsZWQiOmZhbHNlLCJoaWRlWmVybyI6dHJ1ZSwic2l6ZSI6MTgsIngiOjAsInkiOjB9LCJhZGRpdGl2ZSI6ZmFsc2UsImFscGhh"
        "IjoxLCJiZyI6eyJjb2xvciI6WzAsMCwwLDAuNV0sImVuYWJsZWQiOmZhbHNlfSwiYm9yZGVyIjp7ImNvbG9yIjpbMCwwLDAsMV0sImVuYWJsZW"
        "QiOmZhbHNlLCJzaXplIjoxfSwiY291bnQiOnsiY29sb3IiOlsxLDEsMSwxXSwiZW5hYmxlZCI6ZmFsc2UsInNpemUiOjE0LCJ4IjowLCJ5Ijow"
        "fSwiZGVzYXRPbkNEIjpmYWxzZSwiZGVzYXR1cmF0ZSI6ZmFsc2UsImVuYWJsZWQiOmZhbHNlLCJmYWRlQWxwaGEiOmZhbHNlLCJmYWRlQWxwaG"
        "FNYXgiOjEsImZhZGVBbHBoYU1pbiI6MC4xNSwiZmFkZUNvbG9yIjpbMSwwLjEsMC4xLDFdLCJmYWRlR3JleSI6ZmFsc2UsImZpbGwiOnsiZW5h"
        "YmxlZCI6ZmFsc2UsIm1heCI6MSwibWluIjowLCJyZXZlcnNlIjpmYWxzZX0sImZsYXNoIjp7ImVuYWJsZWQiOmZhbHNlLCJzcGVlZCI6MywidG"
        "hyZXNob2xkIjozfSwiZmxpcEgiOmZhbHNlLCJmbGlwViI6ZmFsc2UsImdsb3ciOmZhbHNlLCJoIjoxMjgsImljb25IIjowLCJpY29uVyI6MCwi"
        "a2VlcEFzcGVjdCI6dHJ1ZSwib29jQWxwaGEiOjEsIm91dGxpbmUiOnsiYm9yZGVyT24iOnRydWUsImNvbG9yIjpbMSwwLjgyLDAsMV0sImVuYW"
        "JsZWQiOmZhbHNlLCJnYXAiOjAsImdsb3dBbHBoYSI6MC42LCJnbG93Q29sb3IiOlsxLDAuODIsMCwxXSwiZ2xvd09uIjp0cnVlLCJnbG93U2Ft"
        "ZSI6dHJ1ZSwiZ2xvd1NpemUiOjgsInB1bHNlIjpmYWxzZSwic3R5bGUiOiJhdXRvIiwid2lkdGgiOjJ9LCJvdmVybGF5Ijp7ImFkZGl0aXZlIj"
        "pmYWxzZSwiYWR2YW5jZWQiOmZhbHNlLCJhbHBoYSI6MSwiZGVzYXR1cmF0ZSI6ZmFsc2UsImVuYWJsZWQiOmZhbHNlLCJ0ZXgiOiIiLCJ0aW50"
        "IjpbMSwxLDEsMV19LCJyZWNvbG9yIjpmYWxzZSwicmVxdWlyZU9uQmFyIjpmYWxzZSwicm90YXRpb24iOjAsInRleCI6IiIsInRleEFscGhhIj"
        "oxLCJ0ZXh0Ijp7ImNvbG9yIjpbMSwxLDEsMV0sImRlY2ltYWxCZWxvdyI6NSwiZGVjaW1hbHMiOnRydWUsImVuYWJsZWQiOmZhbHNlLCJzaXpl"
        "IjoyMCwieCI6MCwieSI6MH0sInRpbnQiOlsxLDEsMSwxXSwidyI6MTI4LCJ4IjowLCJ5IjowLCJ6b29tIjowfSwid2hlbiI6eyJsaXN0Ijp7fX"
        "19LHsiYnVmZklEIjowLCJjdWVLZXkiOiJxYSIsImN1ZUtpbmQiOiJzb3VuZCIsImVuYWJsZWQiOnRydWUsImV4dHJhIjp7Imxpc3QiOnt9fSwi"
        "aXNDdWUiOnRydWUsImxvYWQiOnsiaW5zdGFuY2VUeXBlcyI6e319LCJtYXhDaGFyZ2VzIjowLCJuYW1lIjoiSXRzIGN1ZSIsInBhcmVudFVpZC"
        "I6InVTaGFyZWQxIiwicmVwZWF0U2VjIjowLCJzb3VuZCI6eyJlbmFibGVkIjpmYWxzZSwic291cmNlIjoia2l0IiwidmFsdWUiOiIifSwic3Bl"
        "bGxJRCI6MCwidGFsZW50cyI6e30sInVzZUJ1ZmYiOmZhbHNlLCJ1c2VDb29sZG93biI6ZmFsc2UsInZpc3VhbCI6eyJhYnNvcmIiOnsiYWJicm"
        "V2aWF0ZSI6dHJ1ZSwiY29sb3IiOlswLjksMC45LDEsMV0sImVuYWJsZWQiOmZhbHNlLCJoaWRlWmVybyI6dHJ1ZSwic2l6ZSI6MTgsIngiOjAs"
        "InkiOjB9LCJhZGRpdGl2ZSI6ZmFsc2UsImFscGhhIjoxLCJiZyI6eyJjb2xvciI6WzAsMCwwLDAuNV0sImVuYWJsZWQiOmZhbHNlfSwiYm9yZG"
        "VyIjp7ImNvbG9yIjpbMCwwLDAsMV0sImVuYWJsZWQiOmZhbHNlLCJzaXplIjoxfSwiY291bnQiOnsiY29sb3IiOlsxLDEsMSwxXSwiZW5hYmxl"
        "ZCI6ZmFsc2UsInNpemUiOjE0LCJ4IjowLCJ5IjowfSwiZGVzYXRPbkNEIjpmYWxzZSwiZGVzYXR1cmF0ZSI6ZmFsc2UsImVuYWJsZWQiOmZhbH"
        "NlLCJmYWRlQWxwaGEiOmZhbHNlLCJmYWRlQWxwaGFNYXgiOjEsImZhZGVBbHBoYU1pbiI6MC4xNSwiZmFkZUNvbG9yIjpbMSwwLjEsMC4xLDFd"
        "LCJmYWRlR3JleSI6ZmFsc2UsImZpbGwiOnsiZW5hYmxlZCI6ZmFsc2UsIm1heCI6MSwibWluIjowLCJyZXZlcnNlIjpmYWxzZX0sImZsYXNoIj"
        "p7ImVuYWJsZWQiOmZhbHNlLCJzcGVlZCI6MywidGhyZXNob2xkIjozfSwiZmxpcEgiOmZhbHNlLCJmbGlwViI6ZmFsc2UsImdsb3ciOmZhbHNl"
        "LCJoIjoxMjgsImljb25IIjowLCJpY29uVyI6MCwia2VlcEFzcGVjdCI6dHJ1ZSwib29jQWxwaGEiOjEsIm91dGxpbmUiOnsiYm9yZGVyT24iOn"
        "RydWUsImNvbG9yIjpbMSwwLjgyLDAsMV0sImVuYWJsZWQiOmZhbHNlLCJnYXAiOjAsImdsb3dBbHBoYSI6MC42LCJnbG93Q29sb3IiOlsxLDAu"
        "ODIsMCwxXSwiZ2xvd09uIjp0cnVlLCJnbG93U2FtZSI6dHJ1ZSwiZ2xvd1NpemUiOjgsInB1bHNlIjpmYWxzZSwic3R5bGUiOiJhdXRvIiwid2"
        "lkdGgiOjJ9LCJvdmVybGF5Ijp7ImFkZGl0aXZlIjpmYWxzZSwiYWR2YW5jZWQiOmZhbHNlLCJhbHBoYSI6MSwiZGVzYXR1cmF0ZSI6ZmFsc2Us"
        "ImVuYWJsZWQiOmZhbHNlLCJ0ZXgiOiIiLCJ0aW50IjpbMSwxLDEsMV19LCJyZWNvbG9yIjpmYWxzZSwicmVxdWlyZU9uQmFyIjpmYWxzZSwicm"
        "90YXRpb24iOjAsInRleCI6IiIsInRleEFscGhhIjoxLCJ0ZXh0Ijp7ImNvbG9yIjpbMSwxLDEsMV0sImRlY2ltYWxCZWxvdyI6NSwiZGVjaW1h"
        "bHMiOnRydWUsImVuYWJsZWQiOmZhbHNlLCJzaXplIjoyMCwieCI6MCwieSI6MH0sInRpbnQiOlsxLDEsMSwxXSwidyI6MTI4LCJ4IjowLCJ5Ij"
        "owLCJ6b29tIjowfSwid2hlbiI6eyJsaXN0Ijp7fX19LHsiYnVmZklEIjowLCJlbmFibGVkIjp0cnVlLCJleHRyYSI6eyJsaXN0Ijp7fX0sImZv"
        "bGRlciI6ImYxNzk0MDAwMDAwOTk2MyIsImxvYWQiOnsiaW5zdGFuY2VUeXBlcyI6e319LCJtYXhDaGFyZ2VzIjowLCJuYW1lIjoiSW5uZXIgcn"
        "VsZSIsInJlcGVhdFNlYyI6MCwic291bmQiOnsiZW5hYmxlZCI6ZmFsc2UsInNvdXJjZSI6ImtpdCIsInZhbHVlIjoiIn0sInNwZWxsSUQiOjAs"
        "InRhbGVudHMiOnt9LCJ1aWQiOiJ1U2hhcmVkMiIsInVzZUJ1ZmYiOmZhbHNlLCJ1c2VDb29sZG93biI6ZmFsc2UsInZpc3VhbCI6eyJhYnNvcm"
        "IiOnsiYWJicmV2aWF0ZSI6dHJ1ZSwiY29sb3IiOlswLjksMC45LDEsMV0sImVuYWJsZWQiOmZhbHNlLCJoaWRlWmVybyI6dHJ1ZSwic2l6ZSI6"
        "MTgsIngiOjAsInkiOjB9LCJhZGRpdGl2ZSI6ZmFsc2UsImFscGhhIjoxLCJiZyI6eyJjb2xvciI6WzAsMCwwLDAuNV0sImVuYWJsZWQiOmZhbH"
        "NlfSwiYm9yZGVyIjp7ImNvbG9yIjpbMCwwLDAsMV0sImVuYWJsZWQiOmZhbHNlLCJzaXplIjoxfSwiY291bnQiOnsiY29sb3IiOlsxLDEsMSwx"
        "XSwiZW5hYmxlZCI6ZmFsc2UsInNpemUiOjE0LCJ4IjowLCJ5IjowfSwiZGVzYXRPbkNEIjpmYWxzZSwiZGVzYXR1cmF0ZSI6ZmFsc2UsImVuYW"
        "JsZWQiOmZhbHNlLCJmYWRlQWxwaGEiOmZhbHNlLCJmYWRlQWxwaGFNYXgiOjEsImZhZGVBbHBoYU1pbiI6MC4xNSwiZmFkZUNvbG9yIjpbMSww"
        "LjEsMC4xLDFdLCJmYWRlR3JleSI6ZmFsc2UsImZpbGwiOnsiZW5hYmxlZCI6ZmFsc2UsIm1heCI6MSwibWluIjowLCJyZXZlcnNlIjpmYWxzZX"
        "0sImZsYXNoIjp7ImVuYWJsZWQiOmZhbHNlLCJzcGVlZCI6MywidGhyZXNob2xkIjozfSwiZmxpcEgiOmZhbHNlLCJmbGlwViI6ZmFsc2UsImds"
        "b3ciOmZhbHNlLCJoIjoxMjgsImljb25IIjowLCJpY29uVyI6MCwia2VlcEFzcGVjdCI6dHJ1ZSwib29jQWxwaGEiOjEsIm91dGxpbmUiOnsiYm"
        "9yZGVyT24iOnRydWUsImNvbG9yIjpbMSwwLjgyLDAsMV0sImVuYWJsZWQiOmZhbHNlLCJnYXAiOjAsImdsb3dBbHBoYSI6MC42LCJnbG93Q29s"
        "b3IiOlsxLDAuODIsMCwxXSwiZ2xvd09uIjp0cnVlLCJnbG93U2FtZSI6dHJ1ZSwiZ2xvd1NpemUiOjgsInB1bHNlIjpmYWxzZSwic3R5bGUiOi"
        "JhdXRvIiwid2lkdGgiOjJ9LCJvdmVybGF5Ijp7ImFkZGl0aXZlIjpmYWxzZSwiYWR2YW5jZWQiOmZhbHNlLCJhbHBoYSI6MSwiZGVzYXR1cmF0"
        "ZSI6ZmFsc2UsImVuYWJsZWQiOmZhbHNlLCJ0ZXgiOiIiLCJ0aW50IjpbMSwxLDEsMV19LCJyZWNvbG9yIjpmYWxzZSwicmVxdWlyZU9uQmFyIj"
        "pmYWxzZSwicm90YXRpb24iOjAsInRleCI6IiIsInRleEFscGhhIjoxLCJ0ZXh0Ijp7ImNvbG9yIjpbMSwxLDEsMV0sImRlY2ltYWxCZWxvdyI6"
        "NSwiZGVjaW1hbHMiOnRydWUsImVuYWJsZWQiOmZhbHNlLCJzaXplIjoyMCwieCI6MCwieSI6MH0sInRpbnQiOlsxLDEsMSwxXSwidyI6MTI4LC"
        "J4IjowLCJ5IjowLCJ6b29tIjowfSwid2hlbiI6eyJsaXN0Ijp7fX19XSwidiI6MX0="),
    "theme": (
        "XUITHEME1:4241234d:eyJiYXNlIjoiY3VzdG9tIiwiY2xhc3NlcyI6e30sImZvbnQiOiJub25lIiwic2l6ZSI6Ik0iLCJ0b2tlbnMiOnsiYWN"
        "jZW50IjpbMC4xLDAuMiwwLjMsMV19LCJ1bmRlciI6ImRlZmF1bHQiLCJ2IjoxfQ=="),
    "profile": (
        "XUIPROFILE1:1bdffdb5:eyJhZGRvblZlcnNpb24iOiIwLjYuNzUiLCJuYW1lIjoiIiwicGFydHMiOnsiYm9udXMiOnsiZGF0YVBhbmVscyI6e"
        "yJibCI6eyJhbmNob3IiOiJCT1RUT01MRUZUIiwiYmciOnRydWUsImJnQWxwaGEiOjQ1LCJiZ0IiOjAsImJnRyI6MCwiYmdSIjowLCJibG9ja3M"
        "iOnt9LCJib3JkZXIiOnRydWUsImJvcmRlckEiOjEwMCwiYm9yZGVyQiI6MCwiYm9yZGVyRyI6MCwiYm9yZGVyUiI6MCwiY2xvY2syNCI6dHJ1Z"
        "SwiZGVjaW1hbHMiOjEsImVuYWJsZWQiOmZhbHNlLCJncm93dGgiOiJIIiwiaGVpZ2h0IjoyMiwiaGlkZUluQ29tYmF0IjpmYWxzZSwiaG92ZXJ"
        "ITCI6ZmFsc2UsImp1c3RpZnkiOiJDRU5URVIiLCJsYWJlbEIiOjAuNywibGFiZWxHIjowLjcsImxhYmVsUiI6MC43LCJsZXZlbCI6MSwibG9jY"
        "WxUaW1lIjp0cnVlLCJsb2NrZWQiOnRydWUsIm1hcmdpbiI6MCwibW91c2VvdmVyIjpmYWxzZSwibW92YWJsZSI6ZmFsc2UsInNob3dMYWJlbHM"
        "iOnRydWUsInNpemluZyI6IkVWRU4iLCJzbG90MSI6IkdPTEQiLCJzbG90MiI6IkRVUkFCSUxJVFkiLCJzbG90MyI6IkJBR1MiLCJzbG90cyI6M"
        "ywic3RyYXRhIjoiTE9XIiwidGV4dDEiOiIiLCJ0ZXh0MTAiOiIiLCJ0ZXh0MTEiOiIiLCJ0ZXh0MTIiOiIiLCJ0ZXh0MTMiOiIiLCJ0ZXh0MTQ"
        "iOiIiLCJ0ZXh0MTUiOiIiLCJ0ZXh0MTYiOiIiLCJ0ZXh0MTciOiIiLCJ0ZXh0MTgiOiIiLCJ0ZXh0MTkiOiIiLCJ0ZXh0MiI6IiIsInRleHQyM"
        "CI6IiIsInRleHQzIjoiIiwidGV4dDQiOiIiLCJ0ZXh0NSI6IiIsInRleHQ2IjoiIiwidGV4dDciOiIiLCJ0ZXh0OCI6IiIsInRleHQ5IjoiIiw"
        "idGV4dEEiOjEwMCwidGV4dEIiOjEsInRleHRHIjoxLCJ0ZXh0UiI6MSwidGlwQW5jaG9yIjoiVE9QIiwidGlwWCI6MCwidGlwWSI6NCwidmlza"
        "WJpbGl0eSI6IiIsIndpZHRoIjo0MDAsIndpZHRoTW9kZSI6IkZJWEVEIiwieCI6MCwieSI6MH0sImJyIjp7ImFuY2hvciI6IkJPVFRPTVJJR0h"
        "UIiwiYmciOnRydWUsImJnQWxwaGEiOjQ1LCJiZ0IiOjAsImJnRyI6MCwiYmdSIjowLCJibG9ja3MiOnt9LCJib3JkZXIiOnRydWUsImJvcmRlc"
        "kEiOjEwMCwiYm9yZGVyQiI6MCwiYm9yZGVyRyI6MCwiYm9yZGVyUiI6MCwiY2xvY2syNCI6dHJ1ZSwiZGVjaW1hbHMiOjEsImVuYWJsZWQiOmZ"
        "hbHNlLCJncm93dGgiOiJIIiwiaGVpZ2h0IjoyMiwiaGlkZUluQ29tYmF0IjpmYWxzZSwiaG92ZXJITCI6ZmFsc2UsImp1c3RpZnkiOiJDRU5UR"
        "VIiLCJsYWJlbEIiOjAuNywibGFiZWxHIjowLjcsImxhYmVsUiI6MC43LCJsZXZlbCI6MSwibG9jYWxUaW1lIjp0cnVlLCJsb2NrZWQiOnRydWU"
        "sIm1hcmdpbiI6MCwibW91c2VvdmVyIjpmYWxzZSwibW92YWJsZSI6ZmFsc2UsInNob3dMYWJlbHMiOnRydWUsInNpemluZyI6IkVWRU4iLCJzb"
        "G90MSI6IlRJTUUiLCJzbG90MiI6IkZQUyIsInNsb3QzIjoiTEFURU5DWSIsInNsb3RzIjozLCJzdHJhdGEiOiJMT1ciLCJ0ZXh0MSI6IiIsInR"
        "leHQxMCI6IiIsInRleHQxMSI6IiIsInRleHQxMiI6IiIsInRleHQxMyI6IiIsInRleHQxNCI6IiIsInRleHQxNSI6IiIsInRleHQxNiI6IiIsI"
        "nRleHQxNyI6IiIsInRleHQxOCI6IiIsInRleHQxOSI6IiIsInRleHQyIjoiIiwidGV4dDIwIjoiIiwidGV4dDMiOiIiLCJ0ZXh0NCI6IiIsInR"
        "leHQ1IjoiIiwidGV4dDYiOiIiLCJ0ZXh0NyI6IiIsInRleHQ4IjoiIiwidGV4dDkiOiIiLCJ0ZXh0QSI6MTAwLCJ0ZXh0QiI6MSwidGV4dEciO"
        "jEsInRleHRSIjoxLCJ0aXBBbmNob3IiOiJUT1AiLCJ0aXBYIjowLCJ0aXBZIjo0LCJ2aXNpYmlsaXR5IjoiIiwid2lkdGgiOjQwMCwid2lkdGh"
        "Nb2RlIjoiRklYRUQiLCJ4IjowLCJ5IjowfSwiY2VudGVyIjp7ImFuY2hvciI6IkJPVFRPTSIsImJnIjp0cnVlLCJiZ0FscGhhIjo0NSwiYmdCI"
        "jowLCJiZ0ciOjAsImJnUiI6MCwiYmxvY2tzIjp7fSwiYm9yZGVyIjp0cnVlLCJib3JkZXJBIjoxMDAsImJvcmRlckIiOjAsImJvcmRlckciOjA"
        "sImJvcmRlclIiOjAsImNsb2NrMjQiOnRydWUsImRlY2ltYWxzIjoxLCJlbmFibGVkIjpmYWxzZSwiZ3Jvd3RoIjoiSCIsImhlaWdodCI6MjIsI"
        "mhpZGVJbkNvbWJhdCI6ZmFsc2UsImhvdmVySEwiOmZhbHNlLCJqdXN0aWZ5IjoiQ0VOVEVSIiwibGFiZWxCIjowLjcsImxhYmVsRyI6MC43LCJ"
        "sYWJlbFIiOjAuNywibGV2ZWwiOjEsImxvY2FsVGltZSI6dHJ1ZSwibG9ja2VkIjp0cnVlLCJtYXJnaW4iOjAsIm1vdXNlb3ZlciI6ZmFsc2UsI"
        "m1vdmFibGUiOnRydWUsInNob3dMYWJlbHMiOnRydWUsInNpemluZyI6IkVWRU4iLCJzbG90MSI6IlRJTUUiLCJzbG90MiI6IkZQUyIsInNsb3Q"
        "zIjoiTEFURU5DWSIsInNsb3RzIjozLCJzdHJhdGEiOiJMT1ciLCJ0ZXh0MSI6IiIsInRleHQxMCI6IiIsInRleHQxMSI6IiIsInRleHQxMiI6I"
        "iIsInRleHQxMyI6IiIsInRleHQxNCI6IiIsInRleHQxNSI6IiIsInRleHQxNiI6IiIsInRleHQxNyI6IiIsInRleHQxOCI6IiIsInRleHQxOSI"
        "6IiIsInRleHQyIjoiIiwidGV4dDIwIjoiIiwidGV4dDMiOiIiLCJ0ZXh0NCI6IiIsInRleHQ1IjoiIiwidGV4dDYiOiIiLCJ0ZXh0NyI6IiIsI"
        "nRleHQ4IjoiIiwidGV4dDkiOiIiLCJ0ZXh0QSI6MTAwLCJ0ZXh0QiI6MSwidGV4dEciOjEsInRleHRSIjoxLCJ0aXBBbmNob3IiOiJUT1AiLCJ"
        "0aXBYIjowLCJ0aXBZIjo0LCJ2aXNpYmlsaXR5IjoiIiwid2lkdGgiOjQwMCwid2lkdGhNb2RlIjoiRklYRUQiLCJ4IjowLCJ5IjowfSwiY3Vzd"
        "G9tTmV4dCI6MSwiY3VzdG9tcyI6e30sImdlbmVyYWwiOnsiYmxvY2tDb21iYXRDbGljayI6ZmFsc2UsImJsb2NrQ29tYmF0SG92ZXIiOmZhbHN"
        "lLCJlbmFibGVkIjpmYWxzZSwiZm9udCI6Im5vbmUiLCJvdXRsaW5lIjoiT1VUTElORSIsInNpemUiOjEzfX0sInRvb2x0aXBzIjp7ImVuYWJsZ"
        "WQiOnRydWUsImZvcmNlcyI6eyJlbmFibGVkIjp0cnVlLCJvbmx5SW5EdW5nZW9uIjp0cnVlLCJvbmx5TXl0aGljUGx1cyI6ZmFsc2V9LCJmb3J"
        "tdWxhcyI6eyJjb29sZG93biI6dHJ1ZSwiZGFtYWdlIjp0cnVlLCJlbmFibGVkIjp0cnVlfSwiaWRzIjp7ImFjaGlldmVtZW50IjpmYWxzZSwiY"
        "XVyYSI6dHJ1ZSwiYXVyYUhpbnQiOnRydWUsImJhdHRsZXBldCI6ZmFsc2UsImN1cnJlbmN5IjpmYWxzZSwiZW5hYmxlZCI6dHJ1ZSwiaWNvbiI"
        "6ZmFsc2UsIml0ZW0iOnRydWUsIm1vdW50IjpmYWxzZSwibnBjIjp0cnVlLCJxdWVzdCI6ZmFsc2UsInNwZWxsIjp0cnVlLCJ0b3kiOmZhbHNlf"
        "SwiaWx2bCI6eyJjYWNoZVNlY3MiOjEyMCwiZW5hYmxlZCI6dHJ1ZSwiaW5zcGVjdCI6dHJ1ZX0sInR5cGVDb2xvcnMiOnsiZW5hYmxlZCI6dHJ"
        "1ZX19fSwicW9sIjp7ImNoYXJhY3RlclRvb2xraXQiOnsiYWR2YW5jZWQiOmZhbHNlLCJjb2xsYXBzZWQiOnt9LCJkZXRhaWwiOiJhbGwiLCJlb"
        "mFibGVkIjpmYWxzZSwiZW5jaGFudFNsb3RzIjp7fSwiZm9udFNpemUiOjExLCJmcmVlIjp7IngiOjAsInkiOjB9LCJnZWFyU3VtU3R5bGUiOiJ"
        "iYXJzIiwiaGVpZ2h0TGFyZ2UiOjc2MCwiaGVpZ2h0U21hbGwiOjQ0MCwib3BhY2l0eSI6MC45Miwib3ZFbmNoYW50cyI6dHJ1ZSwib3ZJbHZsI"
        "jp0cnVlLCJvdlNpemUiOjExLCJvdlNvY2tldHMiOnRydWUsIm92ZXJsYXlzIjpmYWxzZSwicGFuZWwiOnRydWUsInBhbmVsT3BlbiI6dHJ1ZSw"
        "ic2lkZSI6InJpZ2h0Iiwic2l6ZU1vZGUiOiJzbWFsbCIsInNwZWxsRmlsdGVyIjoiYWxsIiwic3BlbGxzIjp7fSwic3BlbGxzQWxsIjpmYWxzZ"
        "Swic3RhdE9wZW4iOnt9LCJ0YWIiOiJzdGF0cyIsInRvb2x0aXBzIjp0cnVlLCJ3aGF0SWYiOjAsIndoYXRJZlN0YXRzIjp7fX0sImN1cnNvckh"
        "pZ2hsaWdodCI6eyJhcnQiOiJwb2ludCIsImFydFBhdGgiOiIiLCJjb2xvciI6WzEsMC44MiwwLjFdLCJjb21iYXRPbmx5IjpmYWxzZSwiZW5hY"
        "mxlZCI6ZmFsc2UsImhpZGVNb3VzZWxvb2siOnRydWUsImtlZXBDb2xvcnMiOmZhbHNlLCJvcGFjaXR5IjowLjM1LCJzaGFwZSI6ImNpcmNsZSI"
        "sInNpemUiOjU2LCJzdHlsZSI6ImZpbGwiLCJ0aGlja25lc3MiOjMsInVzZVRoZW1lQ29sb3IiOmZhbHNlfSwiY3Vyc29yVHJhaWwiOnsiY3Vzd"
        "G9tIjpbWzEsMC4zLDAuM10sWzEsMC44NSwwLjJdLFswLjMsMC41LDFdLFswLjMsMSwwLjVdLFswLjg1LDAuNCwxXSxbMSwxLDFdXSwiY3VzdG9"
        "tTiI6MywiZW5hYmxlZCI6ZmFsc2UsImhpZGVNb3VzZWxvb2siOnRydWUsImxlbmd0aCI6MC42LCJvcGFjaXR5IjoxLCJwcmVzZXQiOiJmZWwiL"
        "CJyZXZlcnNlIjpmYWxzZSwic2hhcGUiOiJzdGFyIiwic2l6ZSI6MTh9LCJyZWxlYXNlR3VhcmQiOnsiZW5hYmxlZCI6ZmFsc2UsImZsYXZvck9"
        "uIjp0cnVlLCJmbGF2b3JzIjoiQkFEIE1PTktFWVxuZGVhdGggY29tZXMgZm9yIHVzIGFsbFxuTk9QRVxuRGlzYWdyZWVcbldUQiBSZXoiLCJpb"
        "mRleCI6MCwibG9hZCI6InJhaWQiLCJtb2RpZmllciI6IlNISUZUIiwidGV4dCI6Ik5PIFJFTEVBU0UifX0sInJlc2tpbiI6eyJjaGFyYWN0ZXJ"
        "SZXNraW4iOnsiYmdBbHBoYSI6MC45NSwiY2hyb21lIjp0cnVlLCJlbmFibGVkIjpmYWxzZSwiZW5jaGFudHMiOnRydWUsImdlbXMiOnRydWUsI"
        "mdyb3VwQ29sb3IiOnt9LCJncm91cE5hbWUiOnt9LCJpbHZsIjp0cnVlLCJzdGF0Q29sb3IiOnt9LCJzdGF0SGlkZSI6e30sInN0YXRMaXN0Ijp"
        "0cnVlLCJzdGF0TW9kZSI6e30sInN0YXROYW1lIjp7fSwic3RhdE9yZGVyIjp7fSwic3RhdHMiOnRydWUsInRhbGxQeCI6MCwid2lkZSI6dHJ1Z"
        "Swid2lkZVB4Ijo0Miwid2lkZVB4VG80MiI6dHJ1ZX0sImNoYXQiOnt9LCJjaGF0MiI6eyJiYXJBbGlnbjEiOiJDRU5URVIiLCJiYXJBbGlnbjI"
        "iOiJDRU5URVIiLCJiYXJBbGlnbjMiOiJDRU5URVIiLCJiYXJBbGlnbjQiOiJDRU5URVIiLCJiYXJBbGlnbjUiOiJDRU5URVIiLCJiYXJBbGlnb"
        "jYiOiJDRU5URVIiLCJiYXJBbGlnbjciOiJDRU5URVIiLCJiYXJBbGlnbjgiOiJDRU5URVIiLCJiYXJCZ0EiOjU1LCJiYXJCZ0IiOjAuMDMsImJ"
        "hckJnRyI6MC4wMiwiYmFyQmdPbiI6dHJ1ZSwiYmFyQmdSIjowLjAyLCJiYXJCb3JkZXJBIjoxMDAsImJhckJvcmRlckIiOjAsImJhckJvcmRlc"
        "kciOjAsImJhckJvcmRlck9uIjp0cnVlLCJiYXJCb3JkZXJSIjowLCJiYXJDbG9jazI0Ijp0cnVlLCJiYXJDdXN0b20xIjoiIiwiYmFyQ3VzdG9"
        "tMiI6IiIsImJhckN1c3RvbTMiOiIiLCJiYXJDdXN0b200IjoiIiwiYmFyQ3VzdG9tNSI6IiIsImJhckN1c3RvbTYiOiIiLCJiYXJDdXN0b203I"
        "joiIiwiYmFyQ3VzdG9tOCI6IiIsImJhckZpbGwxIjpmYWxzZSwiYmFyRmlsbDIiOmZhbHNlLCJiYXJGaWxsMyI6ZmFsc2UsImJhckZpbGw0Ijp"
        "mYWxzZSwiYmFyRmlsbDUiOmZhbHNlLCJiYXJGaWxsNiI6ZmFsc2UsImJhckZpbGw3IjpmYWxzZSwiYmFyRmlsbDgiOmZhbHNlLCJiYXJHYXAiO"
        "jIsImJhckgiOjIyLCJiYXJIb3ZlciI6dHJ1ZSwiYmFyTGFiZWxzIjp0cnVlLCJiYXJMb2NhbFRpbWUiOnRydWUsImJhck9uIjp0cnVlLCJiYXJ"
        "TaWRlIjoiQk9UVE9NIiwiYmFyU2l6aW5nIjoiRVZFTiIsImJhclNsb3RzIjozLCJiYXJUZXh0QiI6MSwiYmFyVGV4dEciOjEsImJhclRleHRSI"
        "joxLCJiYXJUZXh0U2l6ZSI6MTMsImJhclR5cGUxIjoiRlBTTVMiLCJiYXJUeXBlMiI6IkZSSUVORFMiLCJiYXJUeXBlMyI6IlRJTUUiLCJiYXJ"
        "UeXBlNCI6Ik5PTkUiLCJiYXJUeXBlNSI6Ik5PTkUiLCJiYXJUeXBlNiI6Ik5PTkUiLCJiYXJUeXBlNyI6Ik5PTkUiLCJiYXJUeXBlOCI6Ik5PT"
        "kUiLCJiYXJWYWx1ZUIiOjAuOTMsImJhclZhbHVlRyI6MC4yMSwiYmFyVmFsdWVSIjowLjY0LCJiZ0EiOjU1LCJiZ0IiOjAuMDMsImJnRyI6MC4"
        "wMiwiYmdPbiI6dHJ1ZSwiYmdSIjowLjAyLCJiZ1RleCI6IiIsImJnVGV4QSI6MTAwLCJiZ1RpbGUiOmZhbHNlLCJib3JkZXJBIjoxMDAsImJvc"
        "mRlckIiOjAsImJvcmRlckciOjAsImJvcmRlck9uIjp0cnVlLCJib3JkZXJSIjowLCJjb2xsYXBzZWQiOmZhbHNlLCJlbmFibGVkIjp0cnVlLCJ"
        "mYWRlQWZ0ZXIiOjEwLCJmYWRlQmFyIjpmYWxzZSwiZmFkZU9uIjpmYWxzZSwiZmFkZVNlY29uZHMiOjAuNCwiZmFkZVRvIjowLCJmYWRlV2FrZ"
        "SI6dHJ1ZSwiZm9udCI6Im5vbmUiLCJmb250T3V0bGluZSI6Im91dGxpbmUiLCJmb250U2l6ZSI6MTQsImhlaWdodCI6MjMwLCJoaXN0QnV0dG9"
        "uIjp0cnVlLCJoaXN0Q29uc29sZSI6dHJ1ZSwiaGlzdE9uIjp0cnVlLCJoaXN0U2l6ZSI6MzAwLCJoaXN0V2hpc3BlcnMiOiJnYW1lIiwiaWdub"
        "3JlQ2xpY2siOnRydWUsImltcHJvdmVkT24iOnRydWUsImlucHV0QmRBIjoxMDAsImlucHV0QmRCIjowLCJpbnB1dEJkRyI6MCwiaW5wdXRCZFI"
        "iOjAsImlucHV0QmdBIjo3MCwiaW5wdXRCZ0IiOjAsImlucHV0QmdHIjowLCJpbnB1dEJnUiI6MCwiaW5wdXRGb2N1c0JkIjp0cnVlLCJpbnB1d"
        "EgiOjI2LCJpbnB1dEhpbnQiOnRydWUsImlucHV0SGludFRleHQiOiJQcmVzcyBFbnRlciB0byBjaGF0IiwiaW5wdXRQb3MiOiJCT1RUT00iLCJ"
        "saW5rQiI6MSwibGlua0ciOjAuNzUsImxpbmtSIjowLjQsImxpbmtzIjp0cnVlLCJwb2ludCI6IkJPVFRPTUxFRlQiLCJzY3JvbGxCYXIiOiJIS"
        "URFIiwic2Nyb2xsT3duIjp0cnVlLCJzY3JvbGxTcGVlZCI6Niwic2Nyb2xsVyI6MTAsInNvY2lhbE1vZGUiOiJISURFIiwic29jaWFsWCI6MCw"
        "ic29jaWFsWSI6MCwic291bmRzIjp7fSwic291bmRzSW5Db21iYXQiOnRydWUsInNvdW5kc09uIjp0cnVlLCJzcGFtUGhyYXNlcyI6IiIsInNwY"
        "W1SZXBlYXQiOnRydWUsInNwYW1TZWNvbmRzIjozMCwic3BhbVdvcmQiOmZhbHNlLCJzdHJpcE1vZGUiOiJISURFIiwic3RyaXBYIjowLCJzdHJ"
        "pcFkiOjAsInRhYkJnQSI6NDUsInRhYkJnQiI6MCwidGFiQmdHIjowLCJ0YWJCZ09uIjp0cnVlLCJ0YWJCZ1IiOjAsInRhYkZvbnQiOiJub25lI"
        "iwidGFiRm9udFNpemUiOjEzLCJ0YWJIZWlnaHQiOjI0LCJ0YWJPdXRsaW5lIjoic2hhZG93IiwidGFiU2VsQiI6MC4zLCJ0YWJTZWxCZ0EiOjg"
        "wLCJ0YWJTZWxCZ0IiOjAuMTgsInRhYlNlbEJnRyI6MC4xOCwidGFiU2VsQmdSIjowLjE4LCJ0YWJTZWxHIjoxLCJ0YWJTZWxSIjowLjMsInRhY"
        "lRleHRCIjowLjc1LCJ0YWJUZXh0RyI6MC43NSwidGFiVGV4dFIiOjAuNzUsInRhYnNTaG93Ijp0cnVlLCJ0ZXh0RmFkZSI6ZmFsc2UsInRleHR"
        "GYWRlQWZ0ZXIiOjEyMCwidGV4dEluc2V0Ijo2LCJ0b0JvdHRvbSI6IlNIT1ciLCJ1c2VUaGVtZSI6ZmFsc2UsIndoaXNwZXJTZWxlY3QiOnRyd"
        "WUsIndoaXNwZXJTb3VuZHMiOnt9LCJ3aGlzcGVyU291bmRzT24iOnRydWUsIndpZHRoIjo0NDAsIndyYXBJbmRlbnQiOnRydWUsIngiOjI0LCJ"
        "5Ijo5MH19LCJydWxlcyI6eyJhZGRvblZlcnNpb24iOiIwLjYuNzUiLCJmb2xkZXJzIjpbeyJkZWZhdWx0IjoiZGlzcGxheSIsImlkIjoiZjE3O"
        "TQwMDAwMDA1MzgyIiwibmFtZSI6IkRpc3BsYXkgQ3VlcyIsIm9yaWdpbiI6eyJhdCI6MTc5NDAwMDAwMCwiYnkiOiJYYXlhLUFyZWEgNTIiLCJ"
        "ob3ciOiJkZWZhdWx0In19LHsiZGVmYXVsdCI6InNvdW5kIiwiaWQiOiJmMTc5NDAwMDAwMDg4MTEiLCJuYW1lIjoiU291bmQgQ3VlcyIsIm9ya"
        "WdpbiI6eyJhdCI6MTc5NDAwMDAwMCwiYnkiOiJYYXlhLUFyZWEgNTIiLCJob3ciOiJkZWZhdWx0In19LHsiZGVmYXVsdCI6Imh5YnJpZCIsIml"
        "kIjoiZjE3OTQwMDAwMDA2MzMzIiwibmFtZSI6Ikh5YnJpZCBDdWVzIiwib3JpZ2luIjp7ImF0IjoxNzk0MDAwMDAwLCJieSI6IlhheWEtQXJlY"
        "SA1MiIsImhvdyI6ImRlZmF1bHQifX0seyJkZWZhdWx0IjoiYWR2YW5jZWQiLCJpZCI6ImYxNzk0MDAwMDAwMjkzMiIsIm5hbWUiOiJBZHZhbmN"
        "lZCBDdWUgVHJhY2tpbmciLCJvcmlnaW4iOnsiYXQiOjE3OTQwMDAwMDAsImJ5IjoiWGF5YS1BcmVhIDUyIiwiaG93IjoiZGVmYXVsdCJ9fSx7I"
        "mRlZmF1bHQiOiJjdXJzb3IiLCJpZCI6ImYxNzk0MDAwMDAwMTA5MiIsIm5hbWUiOiJNb3VzZSBDdXJzb3IgQ3VlcyIsIm9yaWdpbiI6eyJhdCI"
        "6MTc5NDAwMDAwMCwiYnkiOiJYYXlhLUFyZWEgNTIiLCJob3ciOiJkZWZhdWx0In19LHsiaWQiOiJmMTc5NDAwMDAwMDU2MzMiLCJuYW1lIjoiU"
        "2hhcmVkIGdyb3VwIiwib3JpZ2luIjp7ImF0IjoxNzk0MDAwMDAwLCJieSI6IlhheWEtQXJlYSA1MiIsImhvdyI6Im1hZGUifX0seyJpZCI6ImY"
        "xNzk0MDAwMDAwOTk2MyIsIm5hbWUiOiJJbm5lciIsIm9yaWdpbiI6eyJhdCI6MTc5NDAwMDAwMCwiYnkiOiJYYXlhLUFyZWEgNTIiLCJob3ciO"
        "iJtYWRlIn0sInBhcmVudCI6ImYxNzk0MDAwMDAwNTYzMyJ9XSwibmFtZSI6IiIsInJ1bGVzIjpbeyJidWZmSUQiOjEyMzQsImJ1ZmZTdGF0ZSI"
        "6InByZXNlbnQiLCJlbmFibGVkIjp0cnVlLCJleHRyYSI6eyJsaXN0Ijp7fX0sImZvbGRlciI6ImYxNzk0MDAwMDAwNTYzMyIsImxvYWQiOnsia"
        "W5zdGFuY2VUeXBlcyI6e319LCJtYXhDaGFyZ2VzIjowLCJuYW1lIjoiU2hhcmVkIHJ1bGUiLCJyZXBlYXRTZWMiOjAsInNvdW5kIjp7ImVuYWJ"
        "sZWQiOmZhbHNlLCJzb3VyY2UiOiJraXQiLCJ2YWx1ZSI6IiJ9LCJzcGVsbElEIjowLCJ0YWxlbnRzIjp7fSwidWlkIjoidVNoYXJlZDEiLCJ1c"
        "2VCdWZmIjp0cnVlLCJ1c2VDb29sZG93biI6ZmFsc2UsInZpc3VhbCI6eyJhYnNvcmIiOnsiYWJicmV2aWF0ZSI6dHJ1ZSwiY29sb3IiOlswLjk"
        "sMC45LDEsMV0sImVuYWJsZWQiOmZhbHNlLCJoaWRlWmVybyI6dHJ1ZSwic2l6ZSI6MTgsIngiOjAsInkiOjB9LCJhZGRpdGl2ZSI6ZmFsc2UsI"
        "mFscGhhIjoxLCJiZyI6eyJjb2xvciI6WzAsMCwwLDAuNV0sImVuYWJsZWQiOmZhbHNlfSwiYm9yZGVyIjp7ImNvbG9yIjpbMCwwLDAsMV0sImV"
        "uYWJsZWQiOmZhbHNlLCJzaXplIjoxfSwiY291bnQiOnsiY29sb3IiOlsxLDEsMSwxXSwiZW5hYmxlZCI6ZmFsc2UsInNpemUiOjE0LCJ4IjowL"
        "CJ5IjowfSwiZGVzYXRPbkNEIjpmYWxzZSwiZGVzYXR1cmF0ZSI6ZmFsc2UsImVuYWJsZWQiOmZhbHNlLCJmYWRlQWxwaGEiOmZhbHNlLCJmYWR"
        "lQWxwaGFNYXgiOjEsImZhZGVBbHBoYU1pbiI6MC4xNSwiZmFkZUNvbG9yIjpbMSwwLjEsMC4xLDFdLCJmYWRlR3JleSI6ZmFsc2UsImZpbGwiO"
        "nsiZW5hYmxlZCI6ZmFsc2UsIm1heCI6MSwibWluIjowLCJyZXZlcnNlIjpmYWxzZX0sImZsYXNoIjp7ImVuYWJsZWQiOmZhbHNlLCJzcGVlZCI"
        "6MywidGhyZXNob2xkIjozfSwiZmxpcEgiOmZhbHNlLCJmbGlwViI6ZmFsc2UsImdsb3ciOmZhbHNlLCJoIjoxMjgsImljb25IIjowLCJpY29uV"
        "yI6MCwia2VlcEFzcGVjdCI6dHJ1ZSwib29jQWxwaGEiOjEsIm91dGxpbmUiOnsiYm9yZGVyT24iOnRydWUsImNvbG9yIjpbMSwwLjgyLDAsMV0"
        "sImVuYWJsZWQiOmZhbHNlLCJnYXAiOjAsImdsb3dBbHBoYSI6MC42LCJnbG93Q29sb3IiOlsxLDAuODIsMCwxXSwiZ2xvd09uIjp0cnVlLCJnb"
        "G93U2FtZSI6dHJ1ZSwiZ2xvd1NpemUiOjgsInB1bHNlIjpmYWxzZSwic3R5bGUiOiJhdXRvIiwid2lkdGgiOjJ9LCJvdmVybGF5Ijp7ImFkZGl"
        "0aXZlIjpmYWxzZSwiYWR2YW5jZWQiOmZhbHNlLCJhbHBoYSI6MSwiZGVzYXR1cmF0ZSI6ZmFsc2UsImVuYWJsZWQiOmZhbHNlLCJ0ZXgiOiIiL"
        "CJ0aW50IjpbMSwxLDEsMV19LCJyZWNvbG9yIjpmYWxzZSwicmVxdWlyZU9uQmFyIjpmYWxzZSwicm90YXRpb24iOjAsInRleCI6IiIsInRleEF"
        "scGhhIjoxLCJ0ZXh0Ijp7ImNvbG9yIjpbMSwxLDEsMV0sImRlY2ltYWxCZWxvdyI6NSwiZGVjaW1hbHMiOnRydWUsImVuYWJsZWQiOmZhbHNlL"
        "CJzaXplIjoyMCwieCI6MCwieSI6MH0sInRpbnQiOlsxLDEsMSwxXSwidyI6MTI4LCJ4IjowLCJ5IjowLCJ6b29tIjowfSwid2hlbiI6eyJsaXN"
        "0Ijp7fX19LHsiYnVmZklEIjowLCJjdWVLZXkiOiJxYSIsImN1ZUtpbmQiOiJzb3VuZCIsImVuYWJsZWQiOnRydWUsImV4dHJhIjp7Imxpc3QiO"
        "nt9fSwiaXNDdWUiOnRydWUsImxvYWQiOnsiaW5zdGFuY2VUeXBlcyI6e319LCJtYXhDaGFyZ2VzIjowLCJuYW1lIjoiSXRzIGN1ZSIsInBhcmV"
        "udFVpZCI6InVTaGFyZWQxIiwicmVwZWF0U2VjIjowLCJzb3VuZCI6eyJlbmFibGVkIjpmYWxzZSwic291cmNlIjoia2l0IiwidmFsdWUiOiIif"
        "Swic3BlbGxJRCI6MCwidGFsZW50cyI6e30sInVzZUJ1ZmYiOmZhbHNlLCJ1c2VDb29sZG93biI6ZmFsc2UsInZpc3VhbCI6eyJhYnNvcmIiOns"
        "iYWJicmV2aWF0ZSI6dHJ1ZSwiY29sb3IiOlswLjksMC45LDEsMV0sImVuYWJsZWQiOmZhbHNlLCJoaWRlWmVybyI6dHJ1ZSwic2l6ZSI6MTgsI"
        "ngiOjAsInkiOjB9LCJhZGRpdGl2ZSI6ZmFsc2UsImFscGhhIjoxLCJiZyI6eyJjb2xvciI6WzAsMCwwLDAuNV0sImVuYWJsZWQiOmZhbHNlfSw"
        "iYm9yZGVyIjp7ImNvbG9yIjpbMCwwLDAsMV0sImVuYWJsZWQiOmZhbHNlLCJzaXplIjoxfSwiY291bnQiOnsiY29sb3IiOlsxLDEsMSwxXSwiZ"
        "W5hYmxlZCI6ZmFsc2UsInNpemUiOjE0LCJ4IjowLCJ5IjowfSwiZGVzYXRPbkNEIjpmYWxzZSwiZGVzYXR1cmF0ZSI6ZmFsc2UsImVuYWJsZWQ"
        "iOmZhbHNlLCJmYWRlQWxwaGEiOmZhbHNlLCJmYWRlQWxwaGFNYXgiOjEsImZhZGVBbHBoYU1pbiI6MC4xNSwiZmFkZUNvbG9yIjpbMSwwLjEsM"
        "C4xLDFdLCJmYWRlR3JleSI6ZmFsc2UsImZpbGwiOnsiZW5hYmxlZCI6ZmFsc2UsIm1heCI6MSwibWluIjowLCJyZXZlcnNlIjpmYWxzZX0sImZ"
        "sYXNoIjp7ImVuYWJsZWQiOmZhbHNlLCJzcGVlZCI6MywidGhyZXNob2xkIjozfSwiZmxpcEgiOmZhbHNlLCJmbGlwViI6ZmFsc2UsImdsb3ciO"
        "mZhbHNlLCJoIjoxMjgsImljb25IIjowLCJpY29uVyI6MCwia2VlcEFzcGVjdCI6dHJ1ZSwib29jQWxwaGEiOjEsIm91dGxpbmUiOnsiYm9yZGV"
        "yT24iOnRydWUsImNvbG9yIjpbMSwwLjgyLDAsMV0sImVuYWJsZWQiOmZhbHNlLCJnYXAiOjAsImdsb3dBbHBoYSI6MC42LCJnbG93Q29sb3IiO"
        "lsxLDAuODIsMCwxXSwiZ2xvd09uIjp0cnVlLCJnbG93U2FtZSI6dHJ1ZSwiZ2xvd1NpemUiOjgsInB1bHNlIjpmYWxzZSwic3R5bGUiOiJhdXR"
        "vIiwid2lkdGgiOjJ9LCJvdmVybGF5Ijp7ImFkZGl0aXZlIjpmYWxzZSwiYWR2YW5jZWQiOmZhbHNlLCJhbHBoYSI6MSwiZGVzYXR1cmF0ZSI6Z"
        "mFsc2UsImVuYWJsZWQiOmZhbHNlLCJ0ZXgiOiIiLCJ0aW50IjpbMSwxLDEsMV19LCJyZWNvbG9yIjpmYWxzZSwicmVxdWlyZU9uQmFyIjpmYWx"
        "zZSwicm90YXRpb24iOjAsInRleCI6IiIsInRleEFscGhhIjoxLCJ0ZXh0Ijp7ImNvbG9yIjpbMSwxLDEsMV0sImRlY2ltYWxCZWxvdyI6NSwiZ"
        "GVjaW1hbHMiOnRydWUsImVuYWJsZWQiOmZhbHNlLCJzaXplIjoyMCwieCI6MCwieSI6MH0sInRpbnQiOlsxLDEsMSwxXSwidyI6MTI4LCJ4Ijo"
        "wLCJ5IjowLCJ6b29tIjowfSwid2hlbiI6eyJsaXN0Ijp7fX19LHsiYnVmZklEIjowLCJlbmFibGVkIjp0cnVlLCJleHRyYSI6eyJsaXN0Ijp7f"
        "X0sImZvbGRlciI6ImYxNzk0MDAwMDAwOTk2MyIsImxvYWQiOnsiaW5zdGFuY2VUeXBlcyI6e319LCJtYXhDaGFyZ2VzIjowLCJuYW1lIjoiSW5"
        "uZXIgcnVsZSIsInJlcGVhdFNlYyI6MCwic291bmQiOnsiZW5hYmxlZCI6ZmFsc2UsInNvdXJjZSI6ImtpdCIsInZhbHVlIjoiIn0sInNwZWxsS"
        "UQiOjAsInRhbGVudHMiOnt9LCJ1aWQiOiJ1U2hhcmVkMiIsInVzZUJ1ZmYiOmZhbHNlLCJ1c2VDb29sZG93biI6ZmFsc2UsInZpc3VhbCI6eyJ"
        "hYnNvcmIiOnsiYWJicmV2aWF0ZSI6dHJ1ZSwiY29sb3IiOlswLjksMC45LDEsMV0sImVuYWJsZWQiOmZhbHNlLCJoaWRlWmVybyI6dHJ1ZSwic"
        "2l6ZSI6MTgsIngiOjAsInkiOjB9LCJhZGRpdGl2ZSI6ZmFsc2UsImFscGhhIjoxLCJiZyI6eyJjb2xvciI6WzAsMCwwLDAuNV0sImVuYWJsZWQ"
        "iOmZhbHNlfSwiYm9yZGVyIjp7ImNvbG9yIjpbMCwwLDAsMV0sImVuYWJsZWQiOmZhbHNlLCJzaXplIjoxfSwiY291bnQiOnsiY29sb3IiOlsxL"
        "DEsMSwxXSwiZW5hYmxlZCI6ZmFsc2UsInNpemUiOjE0LCJ4IjowLCJ5IjowfSwiZGVzYXRPbkNEIjpmYWxzZSwiZGVzYXR1cmF0ZSI6ZmFsc2U"
        "sImVuYWJsZWQiOmZhbHNlLCJmYWRlQWxwaGEiOmZhbHNlLCJmYWRlQWxwaGFNYXgiOjEsImZhZGVBbHBoYU1pbiI6MC4xNSwiZmFkZUNvbG9yI"
        "jpbMSwwLjEsMC4xLDFdLCJmYWRlR3JleSI6ZmFsc2UsImZpbGwiOnsiZW5hYmxlZCI6ZmFsc2UsIm1heCI6MSwibWluIjowLCJyZXZlcnNlIjp"
        "mYWxzZX0sImZsYXNoIjp7ImVuYWJsZWQiOmZhbHNlLCJzcGVlZCI6MywidGhyZXNob2xkIjozfSwiZmxpcEgiOmZhbHNlLCJmbGlwViI6ZmFsc"
        "2UsImdsb3ciOmZhbHNlLCJoIjoxMjgsImljb25IIjowLCJpY29uVyI6MCwia2VlcEFzcGVjdCI6dHJ1ZSwib29jQWxwaGEiOjEsIm91dGxpbmU"
        "iOnsiYm9yZGVyT24iOnRydWUsImNvbG9yIjpbMSwwLjgyLDAsMV0sImVuYWJsZWQiOmZhbHNlLCJnYXAiOjAsImdsb3dBbHBoYSI6MC42LCJnb"
        "G93Q29sb3IiOlsxLDAuODIsMCwxXSwiZ2xvd09uIjp0cnVlLCJnbG93U2FtZSI6dHJ1ZSwiZ2xvd1NpemUiOjgsInB1bHNlIjpmYWxzZSwic3R"
        "5bGUiOiJhdXRvIiwid2lkdGgiOjJ9LCJvdmVybGF5Ijp7ImFkZGl0aXZlIjpmYWxzZSwiYWR2YW5jZWQiOmZhbHNlLCJhbHBoYSI6MSwiZGVzY"
        "XR1cmF0ZSI6ZmFsc2UsImVuYWJsZWQiOmZhbHNlLCJ0ZXgiOiIiLCJ0aW50IjpbMSwxLDEsMV19LCJyZWNvbG9yIjpmYWxzZSwicmVxdWlyZU9"
        "uQmFyIjpmYWxzZSwicm90YXRpb24iOjAsInRleCI6IiIsInRleEFscGhhIjoxLCJ0ZXh0Ijp7ImNvbG9yIjpbMSwxLDEsMV0sImRlY2ltYWxCZ"
        "WxvdyI6NSwiZGVjaW1hbHMiOnRydWUsImVuYWJsZWQiOmZhbHNlLCJzaXplIjoyMCwieCI6MCwieSI6MH0sInRpbnQiOlsxLDEsMSwxXSwidyI"
        "6MTI4LCJ4IjowLCJ5IjowLCJ6b29tIjowfSwid2hlbiI6eyJsaXN0Ijp7fX19XSwidiI6MX0sInNldHRpbmdzIjp7Im1pbmltYXAiOnsiYW5nb"
        "GUiOjIxNSwiY2xvc2VPbkNsaWNrIjp0cnVlLCJlbnRyaWVzIjp7fSwiaGlkZSI6ZmFsc2UsImljb25PdmVycmlkZSI6IiIsImxvY2tlZCI6ZmF"
        "sc2UsInJhZGl1c09mZnNldCI6NSwic2l6ZSI6MzF9LCJ1aSI6eyJhZHZhbmNlZERlYnVnIjp0cnVlLCJmcmllbmRDb2xvcnMiOnt9fX0sInRoZ"
        "W1lcyI6eyJ0aGVtZSI6eyJiYXNlIjoiY3VzdG9tIiwiY2xhc3NlcyI6e30sImZvbnQiOiJub25lIiwic2l6ZSI6Ik0iLCJ0b2tlbnMiOnsiYWN"
        "jZW50IjpbMC4xLDAuMiwwLjMsMV19LCJ1bmRlciI6ImRlZmF1bHQifSwidGhlbWVzIjp7fX19LCJ2IjoxfQ=="),
}
ORDER = ["rule", "group", "all", "theme", "profile"]

SETUP = r'''
local function setup(W, L)
  local realTime = time
  time = function(t) if t ~= nil then return realTime(t) end return 1794000000 end
  local realDate = date
  date = function(f, t) return realDate(f, t or 1794000000) end
  math.randomseed(7)
  L.startup()
  W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
  local ns = rawget(_G, "XayaUI_NS")
  if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
  ns = rawget(_G, "XayaUI_NS")
  local A = C_AddOns; local realGet = A.GetAddOnMetadata
  A.GetAddOnMetadata = function(a, f) if f == "Version" then return "0.6.75" end return realGet(a, f) end   -- both builds report the same
  local DB = CueRulesDB
  DB.theme = { base = "custom", under = "default", tokens = { accent = { 0.1, 0.2, 0.3, 1 } }, classes = {}, font = "none", size = "M" }
  return ns
end
local function makeRules(ns)
  local g = ns.NewFolder("Shared group", nil, "made")
  local kid = ns.NewFolder("Inner", g.id, "made")
  local r1 = ns.NewRule(); r1.name = "Shared rule"; r1.uid = "uShared1"; r1.buffID = 1234; r1.useBuff = true; r1.buffState = "present"; r1.folder = g.id
  local c1 = ns.NewRule(); c1.name = "Its cue"; c1.isCue = true; c1.parentUid = "uShared1"; c1.cueKind = "sound"; c1.cueKey = "qa"
  local r2 = ns.NewRule(); r2.name = "Inner rule"; r2.uid = "uShared2"; r2.folder = kid.id
  for _, r in ipairs({ r1, c1, r2 }) do ns.NormalizeRule(r); ns.rules[#ns.rules + 1] = r end
  return g, r1
end
local function strings(ns, g, r1)
  local S = ns.Share
  local P = ns.Profile
  local all = {}
  for _, c in ipairs(P.COMPONENTS) do all[c.key] = true end
  return {
    rule = S.Encode("rules", ns.Share_SnapshotRule(r1, "")),
    group = S.Encode("rules", ns.Share_SnapshotGroup(g, "")),
    all = S.Encode("rules", ns.Share_SnapshotAll({ rules = true, bars = true, qol = true }, "")),
    theme = ns.Theme.Export(),
    profile = S.Encode("profile", P.Snapshot(all, "")),
  }
end
'''

GOLDEN_LUA = SETUP + r'''
return function(W, L)
  local ns = setup(W, L)
  local g, r1 = makeRules(ns)
  return strings(ns, g, r1)
end
'''

TEST_LUA = SETUP + r'''
return function(W, L, GOLD, rulesOn)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
local ns = setup(W, L)
local S = ns.Share
local function ruleNamed(n) for _, r in ipairs(ns.rules or {}) do if r.name == n then return r end end end
local function folderNamed(n) for _, f in ipairs(ns.folders or {}) do if f.name == n then return f end end end
if rulesOn then
  section("B: the same setup shared now", function()
    local g, r1 = makeRules(ns)
    local now = strings(ns, g, r1)
    -- (Debug chat defaults, Chat 0.6.46) the profile's one allowed difference: the Blizzard Reskin part's chat2 / chat now carry the
    -- Sidebar's and the privacy cover's defaults (they reach the saved settings at login since 0.6.46; in the game they never did).
    -- Taken out where they hold their default, the string must be the pre-split one byte for byte (tests/profile_parts_run.py, A).
    local CD = ns.Service and ns.Service("chatDebug"); CD = CD and CD.C
    local added, want, qolInfo = 0, 0, false
    if CD then for _ in pairs(CD.SIDEBAR_DEFAULTS) do want = want + 1 end for _ in pairs(ns.CHAT_DEFAULTS) do want = want + 1 end end
    do
      local data = S.Read(now.profile, "profile")
      local rk = type(data) == "table" and data.parts and data.parts.reskin
      for part, defs in pairs({ chat2 = CD and CD.SIDEBAR_DEFAULTS or {}, chat = ns.CHAT_DEFAULTS or {} }) do
        local t = rk and rk[part]
        if type(t) == "table" then for k, v in pairs(defs) do if t[k] == v then t[k] = nil; added = added + 1 end end end
      end
      -- (QoL 0.7.56, Stat Calculator V25) the second allowed difference: the QoL part is format 2 (written after Improved Character
      -- Display's merge; XayaUI_QoL/ProfilePart.lua), so the string carries that part's information (partInfo.qol). (A24 #7) Format 3
      -- since the move to the Item level / Enchants options (a style is not saved at its default, so the keys are unchanged). Its keys
      -- and values are unchanged; taken out, the string is the pre-split one.
      local qi = type(data) == "table" and data.partInfo and data.partInfo.qol
      qolInfo = qi and qi.v == 3 and qi.module == "XayaUI_QoL"
      if qi then data.partInfo.qol = nil; if next(data.partInfo) == nil then data.partInfo = nil end end
      now.profile = data and S.Encode("profile", data)
    end
    check("B: profile: the QoL part says it is format 3 (partInfo.qol, v = 3, XayaUI_QoL; A24 #7)", qolInfo == true)
    if XUI_HAS_CHAT then
      check("B: profile: the Chat defaults now saved are in it (" .. added .. " of " .. want .. ")", want > 0 and added == want, added)
    else
      R[#R + 1] = { "SKIP (QA-branch module absent: XayaUI_Chat) B: profile: the Chat defaults now saved are in it", true }
    end
    local function same(a, b)
      if type(a) ~= type(b) then return false end
      if type(a) ~= "table" then return a == b end
      for k, v in pairs(a) do if not same(v, b[k]) then return false end end
      for k in pairs(b) do if a[k] == nil then return false end end
      return true
    end
    for _, k in ipairs({ "rule", "group", "all", "theme", "profile" }) do
      local ok, shown = now[k] == GOLD[k], tostring(now[k]):sub(1, 50)
      if k == "profile" and not (XUI_HAS_CHAT and XUI_HAS_RESKIN) then
        -- the pre-split profile string holds the data of the QA-branch modules that are absent: Chat's two tables (chat, chat2) and, from
        -- Reskin, its keys inside the Settings part (ui.friendColors, gm, rsk) and its half of characterReskin in the Blizzard Reskin part.
        -- Nothing makes them without those addons, so the expected profile is taken at compare time without them and compared part by
        -- part, every key and value (the byte order of an encoded string follows how the tables were built, which differs once the golden
        -- is read back and changed). Everything of core, QoL and Bonus in it still has to match.
        local gd, nd = S.Read(GOLD.profile, "profile"), S.Read(now.profile, "profile")
        local P = type(gd) == "table" and gd.parts or {}
        if not XUI_HAS_CHAT and P.reskin then P.reskin.chat = nil; P.reskin.chat2 = nil end
        if not XUI_HAS_RESKIN then
          for _, key in ipairs(XUI_RESKIN_UI) do if P.settings and P.settings.ui then P.settings.ui[key] = nil end end
          for _, key in ipairs(XUI_RESKIN_SPLIT) do if P.reskin and P.reskin.characterReskin then P.reskin.characterReskin[key] = nil end end
        end
        ok = type(gd) == "table" and type(nd) == "table" and same(gd, nd)
      end
      check("B: " .. k .. ": the string made now is byte-for-byte the pre-split one" .. (k == "profile" and ", but for the Chat defaults now saved and the QoL part's format 3" or ""), ok, shown)
    end
    wipe(ns.rules); wipe(ns.folders)
  end)
  section("A: rule string", function()
    local data, def = S.Read(GOLD.rule)
    check("A: rule: read as the rules kind", data and def and def.kind == "rules", def and def.kind or tostring(def))
    local c = def.Apply(data, "add")
    local r, cue = ruleNamed("Shared rule"), ruleNamed("Its cue")
    check("A: rule: imported, with its cue under it (1 rule + 1 cue)", c.rules == 2 and r and cue and cue.parentUid == r.uid and r.buffID == 1234, c.rules)
    local wrap = r and ns.FolderById(r.folder)
    check("A: rule: it lands in a group of its own (\"Imported: ...\")", wrap and tostring(wrap.name):match("^Imported: ") ~= nil, wrap and wrap.name)
    wipe(ns.rules); wipe(ns.folders)
  end)
  section("A: group string", function()
    local data, def = S.Read(GOLD.group)
    check("A: group: read as the rules kind", data and def and def.kind == "rules", def and def.kind or tostring(def))
    local c = def.Apply(data, "add")
    local g, kid = folderNamed("Shared group"), folderNamed("Inner")
    check("A: group: both groups come back, the inner one inside the outer one", g and kid and kid.parent == g.id, c.folders)
    check("A: group: its rules come back in their groups (and the cue)", ruleNamed("Shared rule") and ruleNamed("Shared rule").folder == g.id
      and ruleNamed("Inner rule") and ruleNamed("Inner rule").folder == kid.id and ruleNamed("Its cue") ~= nil, c.rules)
    wipe(ns.rules); wipe(ns.folders)
  end)
  section("A: all rules (backup) string", function()
    local data, def = S.Read(GOLD.all)
    check("A: all: read as the rules kind", data and def and def.kind == "rules", def and def.kind or tostring(def))
    local c = def.Apply(data, "replace")
    local g, kid = folderNamed("Shared group"), folderNamed("Inner")
    check("A: all: Load (replace) gives back the 3 rows and every group (the 5 default categories and the 2 made here)",
      c.rules == 3 and c.folders == 7 and #ns.rules == 3 and g and kid and kid.parent == g.id, ("%s rules, %s groups"):format(c.rules, c.folders))
  end)
else
  section("C: rules strings with XayaUI Rules off", function()
    for _, k in ipairs({ "rule", "group", "all" }) do
      local data, err = S.Read(GOLD[k])
      check("C: " .. k .. ": not imported, and the message says \"needs XayaUI Rules\"", data == nil and err == "needs XayaUI Rules", err)
    end
    check("C: no rules exist (nothing of XayaUI Rules loaded)", ns.rules == nil and ns.Share.kinds.rules == nil, ns.rules)
  end)
end
section("A: theme string", function()
  CueRulesDB.theme = { base = "default", tokens = {}, classes = {}, font = "none", size = "M" }
  local data, def = S.Read(GOLD.theme)
  check("A: theme: read as the theme kind", data and def and def.kind == "theme", def and def.kind or tostring(def))
  def.Apply(data)
  local a = CueRulesDB.theme and CueRulesDB.theme.tokens and CueRulesDB.theme.tokens.accent
  check("A: theme: its accent colour is back", type(a) == "table" and math.abs(a[1] - 0.1) < 1e-6 and math.abs(a[3] - 0.3) < 1e-6, a and table.concat(a, ","))
end)
section("A: profile string", function()
  local P = ns.Profile
  local data, def = S.Read(GOLD.profile)
  check("A: profile: read as the profile kind", data and def and def.kind == "profile", def and def.kind or tostring(def))
  local miss = P.Missing(data)
  if rulesOn then
    check("A: profile: every part it holds is offered (none missing)", #miss == 0, #miss)
    local res = def.Apply(data, { inc = { rules = true, themes = true, settings = true }, rules = "add" })
    check("A: profile: the rules part imported its rules", ruleNamed("Shared rule") ~= nil and ruleNamed("Its cue") ~= nil, res and res.done and table.concat(res.done, ","))
  else
    check("C: profile: the rules part is listed as \"needs XayaUI Rules\"", #miss == 1 and miss[1].key == "rules" and miss[1].title == "XayaUI Rules", miss[1] and miss[1].title)
    local built = ns.BuildOptionsTable()
    built.args.profiles.args.import.args.importBox.set({}, GOLD.profile)
    built = ns.BuildOptionsTable()
    local line = built.args.profiles.args.import.args.needs_rules
    check("C: profile: Import shows the line \"needs XayaUI Rules\"", line and line.name == "needs XayaUI Rules", line and line.name)
    local res = def.Apply(data, { inc = { rules = true, themes = true, settings = true }, rules = "add" })
    local done = res and res.done and table.concat(res.done, ",") or ""
    check("C: profile: the other parts import (Themes, Settings), the rules part is skipped", done:find("Themes", 1, true) ~= nil and done:find("Rules", 1, true) == nil, done)
  end
end)
return R
end
'''


def runtime(enabled_filter):
    folders = H.find_addons()
    enabled = [n for n in folders if enabled_filter(n)]
    L = H.lua51.LuaRuntime(unpack_returned_tuples=True)
    api = H.to_lua(L, {k: v for k, v in H.load_api().items() if k != "framexml"})
    world = L.eval("function(path, api) return dofile(path)(api) end")(os.path.join(H.HERE, "world.lua"), api)
    loader = L.eval("function(path, W, o) return dofile(path)(W, o) end")(
        os.path.join(H.HERE, "loader.lua"), world,
        H.to_lua(L, {"folders": folders, "enabled": {k: True for k in enabled}, "saved": {}}))
    return L, world, loader


def main():
    skip = ("XayaUI_DevAssist", "XayaUI_Nameplates")
    if "--golden" in sys.argv:
        L, world, loader = runtime(lambda n: n not in skip)
        res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(GOLDEN_LUA, world, loader)
        for k in ORDER:
            print('    "%s": "%s",' % (k, res[k]))
        errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
        for e in errs:
            print("ERROR in the game stand-in:", str(e)[:600])
        return
    bad, total, errs_all = 0, 0, []
    for rules_on in (True, False):
        L, world, loader = runtime(lambda n: n not in skip and (rules_on or n != "XayaUI_Rules"))
        # (QA-branch modules: absent on main) and, for the golden profile string, the keys Reskin owns (settings_stores.py reads them from Modules.lua)
        lay = SST.layout(H.ROOT)
        L.execute("XUI_HAS_CHAT = %s; XUI_HAS_RESKIN = %s" % (str(os.path.isdir(os.path.join(H.ROOT, "XayaUI_Chat"))).lower(), str(os.path.isdir(os.path.join(H.ROOT, "XayaUI_Reskin"))).lower()))
        L.execute("XUI_RESKIN_UI = { %s }; XUI_RESKIN_SPLIT = { %s }" % (", ".join('"%s"' % k for k in lay["underUi"].get("reskin", [])),
                  ", ".join('"%s"' % k for k in lay["split"]["characterReskin"]["sub"] if lay["split"]["characterReskin"]["owner"] == "reskin")))
        res = L.eval("function(src, W, Ld, g, on) return loadstring(src)()(W, Ld, g, on) end")(TEST_LUA, world, loader, H.to_lua(L, GOLDEN), rules_on)
        tag = "[Rules on] " if rules_on else "[Rules off] "
        for i in range(1, len(res) + 1):
            name, ok = res[i][1], res[i][2]
            if str(name).startswith("SKIP ("):
                print(name.replace("SKIP (", "SKIP " + tag + "(", 1))
                continue
            print(("PASS " if ok else "FAIL ") + tag + name)
            total += 1
            if not ok:
                bad += 1
        errs = [world.errors[i] for i in range(1, len(world.errors) + 1)]
        for e in errs:
            print("ERROR in the game stand-in:", str(e)[:600])
        errs_all += errs
    print("%d checks, %d failed, %d Lua errors" % (total, bad, len(errs_all)))
    sys.exit(1 if bad or errs_all else 0)


if __name__ == "__main__":
    main()
