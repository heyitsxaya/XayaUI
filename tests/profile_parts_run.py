#!/usr/bin/env python3
"""Platform services P1 (core 0.6.74, Options 0.6.80, QoL 0.7.46, Bonus 0.6.30, Chat 0.6.40, Reskin 0.6.20, Nameplates 0.2.2;
docs/plans/PLATFORM-SPLIT-2026-11-07.md sections 6.1, 6.3 and 6.6). Loads the real addons in the stand-in game and checks what the
player gets:
  A byte-identical export: with every part ticked (the Export tab's Generate button) on a fixed setup, the profile string is exactly the
    one the old code (main 774980c, the fixed P.COMPONENTS list) produced for the same setup (GOLDEN below, produced by
    `python3 tests/profile_parts_run.py --golden` run against a checkout of 774980c); also with the six parts ticked by hand.
  B Nameplates part (plan 6.1 "fixes today's gap"): with XayaUI Nameplates on, Export offers it, the string carries it (target colour
    switch and colour, never the Put back store) with its own format version and addon, and Import puts the colour back.
  C a part whose module is not loaded (XayaUI Nameplates off): the pasted profile keeps it, Import shows "needs XayaUI Nameplates" and
    skips it; the other parts import.
  D Recycle Bin kinds: a rule deleted and restored through the registered "rule" kind; an item of a kind no module registered reads
    "(<kind>: module not loaded)", Restore refuses it and it stays in the bin; a newly registered kind restores through its own call.
  E Theme scopes: no scope = exactly the old answer for every class and property; element override > element theme > module override >
    global; the cache is dropped on Resolve; storage is sparse; the registered scopes and labels; scopes travel in the Themes part.
  (Debug chat defaults, Chat 0.6.46) A's one allowed difference: the Blizzard Reskin part's chat2 / chat now carry the Sidebar's and
    the privacy cover's defaults (all 37, each with its default value; decoded and compared with the old string: nothing else differs),
    since they now reach the saved settings at login; taken out, the string is the old one byte for byte.
Negative control: B-E fail on main 774980c (no ns.RegisterProfilePart / RegisterBinKind / Theme scopes; the bin restores any item as
rules; Profiles drops unknown parts). A passes there by design: it is the reference the new code must match.
Run: python3 tests/profile_parts_run.py"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.environ.get("XUI_HARNESS") or os.path.join(HERE, "harness"))
import run as H  # noqa: E402  (the whole-addon harness)

# QA-branch modules (XayaUI_Chat, XayaUI_Reskin, XayaUI_Nameplates) are absent on main: presence is read from the folder
ROOT = os.path.dirname(HERE)
HAS = {m: os.path.isdir(os.path.join(ROOT, "XayaUI_" + m)) for m in ("Chat", "Reskin", "Nameplates")}

# produced by the old code (main 774980c) with --golden; see the docstring
GOLDEN = (
    "XUIPROFILE1:95cd7060:eyJhZGRvblZlcnNpb24iOiIwLjYuNzMiLCJuYW1lIjoiIiwicGFydHMiOnsiYm9udXMiOnsiY2FsY3VsYXRvciI6e"
    "yJlbmFibGVkIjp0cnVlfSwiZGF0YVBhbmVscyI6eyJibCI6eyJhbmNob3IiOiJCT1RUT01MRUZUIiwiYmciOnRydWUsImJnQWxwaGEiOjQ1LCJ"
    "iZ0IiOjAsImJnRyI6MCwiYmdSIjowLCJibG9ja3MiOnt9LCJib3JkZXIiOnRydWUsImJvcmRlckEiOjEwMCwiYm9yZGVyQiI6MCwiYm9yZGVyR"
    "yI6MCwiYm9yZGVyUiI6MCwiY2xvY2syNCI6dHJ1ZSwiZGVjaW1hbHMiOjEsImVuYWJsZWQiOmZhbHNlLCJncm93dGgiOiJIIiwiaGVpZ2h0Ijo"
    "yMiwiaGlkZUluQ29tYmF0IjpmYWxzZSwiaG92ZXJITCI6ZmFsc2UsImp1c3RpZnkiOiJDRU5URVIiLCJsYWJlbEIiOjAuNywibGFiZWxHIjowL"
    "jcsImxhYmVsUiI6MC43LCJsZXZlbCI6MSwibG9jYWxUaW1lIjp0cnVlLCJsb2NrZWQiOnRydWUsIm1hcmdpbiI6MCwibW91c2VvdmVyIjpmYWx"
    "zZSwibW92YWJsZSI6ZmFsc2UsInNob3dMYWJlbHMiOnRydWUsInNpemluZyI6IkVWRU4iLCJzbG90MSI6IkdPTEQiLCJzbG90MiI6IkRVUkFCS"
    "UxJVFkiLCJzbG90MyI6IkJBR1MiLCJzbG90cyI6Mywic3RyYXRhIjoiTE9XIiwidGV4dDEiOiIiLCJ0ZXh0MTAiOiIiLCJ0ZXh0MTEiOiIiLCJ"
    "0ZXh0MTIiOiIiLCJ0ZXh0MTMiOiIiLCJ0ZXh0MTQiOiIiLCJ0ZXh0MTUiOiIiLCJ0ZXh0MTYiOiIiLCJ0ZXh0MTciOiIiLCJ0ZXh0MTgiOiIiL"
    "CJ0ZXh0MTkiOiIiLCJ0ZXh0MiI6IiIsInRleHQyMCI6IiIsInRleHQzIjoiIiwidGV4dDQiOiIiLCJ0ZXh0NSI6IiIsInRleHQ2IjoiIiwidGV"
    "4dDciOiIiLCJ0ZXh0OCI6IiIsInRleHQ5IjoiIiwidGV4dEEiOjEwMCwidGV4dEIiOjEsInRleHRHIjoxLCJ0ZXh0UiI6MSwidGlwQW5jaG9yI"
    "joiVE9QIiwidGlwWCI6MCwidGlwWSI6NCwidmlzaWJpbGl0eSI6IiIsIndpZHRoIjo0MDAsIndpZHRoTW9kZSI6IkZJWEVEIiwieCI6MCwieSI"
    "6MH0sImJyIjp7ImFuY2hvciI6IkJPVFRPTVJJR0hUIiwiYmciOnRydWUsImJnQWxwaGEiOjQ1LCJiZ0IiOjAsImJnRyI6MCwiYmdSIjowLCJib"
    "G9ja3MiOnt9LCJib3JkZXIiOnRydWUsImJvcmRlckEiOjEwMCwiYm9yZGVyQiI6MCwiYm9yZGVyRyI6MCwiYm9yZGVyUiI6MCwiY2xvY2syNCI"
    "6dHJ1ZSwiZGVjaW1hbHMiOjEsImVuYWJsZWQiOmZhbHNlLCJncm93dGgiOiJIIiwiaGVpZ2h0IjoyMiwiaGlkZUluQ29tYmF0IjpmYWxzZSwia"
    "G92ZXJITCI6ZmFsc2UsImp1c3RpZnkiOiJDRU5URVIiLCJsYWJlbEIiOjAuNywibGFiZWxHIjowLjcsImxhYmVsUiI6MC43LCJsZXZlbCI6MSw"
    "ibG9jYWxUaW1lIjp0cnVlLCJsb2NrZWQiOnRydWUsIm1hcmdpbiI6MCwibW91c2VvdmVyIjpmYWxzZSwibW92YWJsZSI6ZmFsc2UsInNob3dMY"
    "WJlbHMiOnRydWUsInNpemluZyI6IkVWRU4iLCJzbG90MSI6IlRJTUUiLCJzbG90MiI6IkZQUyIsInNsb3QzIjoiTEFURU5DWSIsInNsb3RzIjo"
    "zLCJzdHJhdGEiOiJMT1ciLCJ0ZXh0MSI6IiIsInRleHQxMCI6IiIsInRleHQxMSI6IiIsInRleHQxMiI6IiIsInRleHQxMyI6IiIsInRleHQxN"
    "CI6IiIsInRleHQxNSI6IiIsInRleHQxNiI6IiIsInRleHQxNyI6IiIsInRleHQxOCI6IiIsInRleHQxOSI6IiIsInRleHQyIjoiIiwidGV4dDI"
    "wIjoiIiwidGV4dDMiOiIiLCJ0ZXh0NCI6IiIsInRleHQ1IjoiIiwidGV4dDYiOiIiLCJ0ZXh0NyI6IiIsInRleHQ4IjoiIiwidGV4dDkiOiIiL"
    "CJ0ZXh0QSI6MTAwLCJ0ZXh0QiI6MSwidGV4dEciOjEsInRleHRSIjoxLCJ0aXBBbmNob3IiOiJUT1AiLCJ0aXBYIjowLCJ0aXBZIjo0LCJ2aXN"
    "pYmlsaXR5IjoiIiwid2lkdGgiOjQwMCwid2lkdGhNb2RlIjoiRklYRUQiLCJ4IjowLCJ5IjowfSwiY2VudGVyIjp7ImFuY2hvciI6IkJPVFRPT"
    "SIsImJnIjp0cnVlLCJiZ0FscGhhIjo0NSwiYmdCIjowLCJiZ0ciOjAsImJnUiI6MCwiYmxvY2tzIjp7fSwiYm9yZGVyIjp0cnVlLCJib3JkZXJ"
    "BIjoxMDAsImJvcmRlckIiOjAsImJvcmRlckciOjAsImJvcmRlclIiOjAsImNsb2NrMjQiOnRydWUsImRlY2ltYWxzIjoxLCJlbmFibGVkIjpmY"
    "WxzZSwiZ3Jvd3RoIjoiSCIsImhlaWdodCI6MjIsImhpZGVJbkNvbWJhdCI6ZmFsc2UsImhvdmVySEwiOmZhbHNlLCJqdXN0aWZ5IjoiQ0VOVEV"
    "SIiwibGFiZWxCIjowLjcsImxhYmVsRyI6MC43LCJsYWJlbFIiOjAuNywibGV2ZWwiOjEsImxvY2FsVGltZSI6dHJ1ZSwibG9ja2VkIjp0cnVlL"
    "CJtYXJnaW4iOjAsIm1vdXNlb3ZlciI6ZmFsc2UsIm1vdmFibGUiOnRydWUsInNob3dMYWJlbHMiOnRydWUsInNpemluZyI6IkVWRU4iLCJzbG9"
    "0MSI6IlRJTUUiLCJzbG90MiI6IkZQUyIsInNsb3QzIjoiTEFURU5DWSIsInNsb3RzIjozLCJzdHJhdGEiOiJMT1ciLCJ0ZXh0MSI6IiIsInRle"
    "HQxMCI6IiIsInRleHQxMSI6IiIsInRleHQxMiI6IiIsInRleHQxMyI6IiIsInRleHQxNCI6IiIsInRleHQxNSI6IiIsInRleHQxNiI6IiIsInR"
    "leHQxNyI6IiIsInRleHQxOCI6IiIsInRleHQxOSI6IiIsInRleHQyIjoiIiwidGV4dDIwIjoiIiwidGV4dDMiOiIiLCJ0ZXh0NCI6IiIsInRle"
    "HQ1IjoiIiwidGV4dDYiOiIiLCJ0ZXh0NyI6IiIsInRleHQ4IjoiIiwidGV4dDkiOiIiLCJ0ZXh0QSI6MTAwLCJ0ZXh0QiI6MSwidGV4dEciOjE"
    "sInRleHRSIjoxLCJ0aXBBbmNob3IiOiJUT1AiLCJ0aXBYIjowLCJ0aXBZIjo0LCJ2aXNpYmlsaXR5IjoiIiwid2lkdGgiOjQwMCwid2lkdGhNb"
    "2RlIjoiRklYRUQiLCJ4IjowLCJ5IjowfSwiY3VzdG9tTmV4dCI6MSwiY3VzdG9tcyI6e30sImdlbmVyYWwiOnsiYmxvY2tDb21iYXRDbGljayI"
    "6ZmFsc2UsImJsb2NrQ29tYmF0SG92ZXIiOmZhbHNlLCJlbmFibGVkIjpmYWxzZSwiZm9udCI6Im5vbmUiLCJvdXRsaW5lIjoiT1VUTElORSIsI"
    "nNpemUiOjEzfSwibWFya2VyQSI6ImEifSwidG9vbHRpcHMiOnsiZW5hYmxlZCI6dHJ1ZSwiZm9yY2VzIjp7ImVuYWJsZWQiOnRydWUsIm9ubHl"
    "JbkR1bmdlb24iOnRydWUsIm9ubHlNeXRoaWNQbHVzIjpmYWxzZX0sImZvcm11bGFzIjp7ImNvb2xkb3duIjp0cnVlLCJkYW1hZ2UiOnRydWUsI"
    "mVuYWJsZWQiOnRydWV9LCJpZHMiOnsiYWNoaWV2ZW1lbnQiOmZhbHNlLCJhdXJhIjp0cnVlLCJhdXJhSGludCI6dHJ1ZSwiYmF0dGxlcGV0Ijp"
    "mYWxzZSwiY3VycmVuY3kiOmZhbHNlLCJlbmFibGVkIjp0cnVlLCJpY29uIjpmYWxzZSwiaXRlbSI6dHJ1ZSwibW91bnQiOmZhbHNlLCJucGMiO"
    "nRydWUsInF1ZXN0IjpmYWxzZSwic3BlbGwiOnRydWUsInRveSI6ZmFsc2V9LCJpbHZsIjp7ImNhY2hlU2VjcyI6MTIwLCJlbmFibGVkIjp0cnV"
    "lLCJpbnNwZWN0Ijp0cnVlfSwibWFya2VyIjozLCJ0eXBlQ29sb3JzIjp7ImVuYWJsZWQiOnRydWV9fX0sInFvbCI6eyJjaGFyYWN0ZXJUb29sa"
    "2l0Ijp7ImFkdmFuY2VkIjpmYWxzZSwiY29sbGFwc2VkIjp7fSwiZGV0YWlsIjoiYWxsIiwiZW5hYmxlZCI6ZmFsc2UsImVuY2hhbnRTbG90cyI"
    "6e30sImZvbnRTaXplIjoxMSwiZnJlZSI6eyJ4IjowLCJ5IjowfSwiZ2VhclN1bVN0eWxlIjoiYmFycyIsImhlaWdodExhcmdlIjo3NjAsImhla"
    "WdodFNtYWxsIjo0NDAsIm1hcmtlciI6MSwib3BhY2l0eSI6MC45Miwib3ZFbmNoYW50cyI6dHJ1ZSwib3ZJbHZsIjp0cnVlLCJvdlNpemUiOjE"
    "xLCJvdlNvY2tldHMiOnRydWUsIm92ZXJsYXlzIjpmYWxzZSwicGFuZWwiOnRydWUsInBhbmVsT3BlbiI6dHJ1ZSwic2lkZSI6InJpZ2h0Iiwic"
    "2l6ZU1vZGUiOiJzbWFsbCIsInNwZWxsRmlsdGVyIjoiYWxsIiwic3BlbGxzIjp7fSwic3BlbGxzQWxsIjpmYWxzZSwic3RhdE9wZW4iOnt9LCJ"
    "0YWIiOiJzdGF0cyIsInRvb2x0aXBzIjp0cnVlLCJ3aGF0SWYiOjAsIndoYXRJZlN0YXRzIjp7fX0sImN1cnNvciI6eyJhIjoxfSwiY3Vyc29yS"
    "GlnaGxpZ2h0Ijp7ImFydCI6InBvaW50IiwiYXJ0UGF0aCI6IiIsImNvbG9yIjpbMSwwLjgyLDAuMV0sImNvbWJhdE9ubHkiOmZhbHNlLCJlbmF"
    "ibGVkIjpmYWxzZSwiaGlkZU1vdXNlbG9vayI6dHJ1ZSwia2VlcENvbG9ycyI6ZmFsc2UsIm1hcmtlciI6NDAsIm9wYWNpdHkiOjAuMzUsInNoY"
    "XBlIjoiY2lyY2xlIiwic2l6ZSI6NTYsInN0eWxlIjoiZmlsbCIsInRoaWNrbmVzcyI6MywidXNlVGhlbWVDb2xvciI6ZmFsc2V9LCJjdXJzb3J"
    "UcmFpbCI6eyJjdXN0b20iOltbMSwwLjMsMC4zXSxbMSwwLjg1LDAuMl0sWzAuMywwLjUsMV0sWzAuMywxLDAuNV0sWzAuODUsMC40LDFdLFsxL"
    "DEsMV1dLCJjdXN0b21OIjozLCJlbmFibGVkIjpmYWxzZSwiaGlkZU1vdXNlbG9vayI6dHJ1ZSwibGVuZ3RoIjowLjYsIm1hcmtlciI6MTIsIm9"
    "wYWNpdHkiOjEsInByZXNldCI6ImZlbCIsInJldmVyc2UiOmZhbHNlLCJzaGFwZSI6InN0YXIiLCJzaXplIjoxOH0sInJlbGVhc2VHdWFyZCI6e"
    "yJlbmFibGVkIjpmYWxzZSwiZmxhdm9yT24iOnRydWUsImZsYXZvcnMiOiJCQUQgTU9OS0VZXG5kZWF0aCBjb21lcyBmb3IgdXMgYWxsXG5OT1B"
    "FXG5EaXNhZ3JlZVxuV1RCIFJleiIsImluZGV4IjowLCJsb2FkIjoicmFpZCIsIm1hcmtlciI6dHJ1ZSwibW9kaWZpZXIiOiJTSElGVCIsInRle"
    "HQiOiJOTyBSRUxFQVNFIn19LCJyZXNraW4iOnsiY2hhcmFjdGVyUmVza2luIjp7ImJnQWxwaGEiOjAuOTUsImNocm9tZSI6dHJ1ZSwiZW5hYmx"
    "lZCI6ZmFsc2UsImVuY2hhbnRzIjp0cnVlLCJnZW1zIjp0cnVlLCJncm91cENvbG9yIjp7fSwiZ3JvdXBOYW1lIjp7fSwiaWx2bCI6dHJ1ZSwib"
    "WFya2VyIjp0cnVlLCJzdGF0Q29sb3IiOnt9LCJzdGF0SGlkZSI6e30sInN0YXRMaXN0Ijp0cnVlLCJzdGF0TW9kZSI6e30sInN0YXROYW1lIjp"
    "7fSwic3RhdE9yZGVyIjp7fSwic3RhdHMiOnRydWUsInRhbGxQeCI6MCwid2lkZSI6dHJ1ZSwid2lkZVB4Ijo0Miwid2lkZVB4VG80MiI6dHJ1Z"
    "X0sImNoYXQiOnsibWFya2VyIjoiYyJ9LCJjaGF0MiI6eyJiYXJBbGlnbjEiOiJDRU5URVIiLCJiYXJBbGlnbjIiOiJDRU5URVIiLCJiYXJBbGl"
    "nbjMiOiJDRU5URVIiLCJiYXJBbGlnbjQiOiJDRU5URVIiLCJiYXJBbGlnbjUiOiJDRU5URVIiLCJiYXJBbGlnbjYiOiJDRU5URVIiLCJiYXJBb"
    "GlnbjciOiJDRU5URVIiLCJiYXJBbGlnbjgiOiJDRU5URVIiLCJiYXJCZ0EiOjU1LCJiYXJCZ0IiOjAuMDMsImJhckJnRyI6MC4wMiwiYmFyQmd"
    "PbiI6dHJ1ZSwiYmFyQmdSIjowLjAyLCJiYXJCb3JkZXJBIjoxMDAsImJhckJvcmRlckIiOjAsImJhckJvcmRlckciOjAsImJhckJvcmRlck9uI"
    "jp0cnVlLCJiYXJCb3JkZXJSIjowLCJiYXJDbG9jazI0Ijp0cnVlLCJiYXJDdXN0b20xIjoiIiwiYmFyQ3VzdG9tMiI6IiIsImJhckN1c3RvbTM"
    "iOiIiLCJiYXJDdXN0b200IjoiIiwiYmFyQ3VzdG9tNSI6IiIsImJhckN1c3RvbTYiOiIiLCJiYXJDdXN0b203IjoiIiwiYmFyQ3VzdG9tOCI6I"
    "iIsImJhckZpbGwxIjpmYWxzZSwiYmFyRmlsbDIiOmZhbHNlLCJiYXJGaWxsMyI6ZmFsc2UsImJhckZpbGw0IjpmYWxzZSwiYmFyRmlsbDUiOmZ"
    "hbHNlLCJiYXJGaWxsNiI6ZmFsc2UsImJhckZpbGw3IjpmYWxzZSwiYmFyRmlsbDgiOmZhbHNlLCJiYXJHYXAiOjIsImJhckgiOjIyLCJiYXJIb"
    "3ZlciI6dHJ1ZSwiYmFyTGFiZWxzIjp0cnVlLCJiYXJMb2NhbFRpbWUiOnRydWUsImJhck9uIjp0cnVlLCJiYXJTaWRlIjoiQk9UVE9NIiwiYmF"
    "yU2l6aW5nIjoiRVZFTiIsImJhclNsb3RzIjozLCJiYXJUZXh0QiI6MSwiYmFyVGV4dEciOjEsImJhclRleHRSIjoxLCJiYXJUZXh0U2l6ZSI6M"
    "TMsImJhclR5cGUxIjoiRlBTTVMiLCJiYXJUeXBlMiI6IkZSSUVORFMiLCJiYXJUeXBlMyI6IlRJTUUiLCJiYXJUeXBlNCI6Ik5PTkUiLCJiYXJ"
    "UeXBlNSI6Ik5PTkUiLCJiYXJUeXBlNiI6Ik5PTkUiLCJiYXJUeXBlNyI6Ik5PTkUiLCJiYXJUeXBlOCI6Ik5PTkUiLCJiYXJWYWx1ZUIiOjAuO"
    "TMsImJhclZhbHVlRyI6MC4yMSwiYmFyVmFsdWVSIjowLjY0LCJiZ0EiOjU1LCJiZ0IiOjAuMDMsImJnRyI6MC4wMiwiYmdPbiI6dHJ1ZSwiYmd"
    "SIjowLjAyLCJiZ1RleCI6IiIsImJnVGV4QSI6MTAwLCJiZ1RpbGUiOmZhbHNlLCJib3JkZXJBIjoxMDAsImJvcmRlckIiOjAsImJvcmRlckciO"
    "jAsImJvcmRlck9uIjp0cnVlLCJib3JkZXJSIjowLCJjb2xsYXBzZWQiOmZhbHNlLCJlbmFibGVkIjp0cnVlLCJmYWRlQWZ0ZXIiOjEwLCJmYWR"
    "lQmFyIjpmYWxzZSwiZmFkZU1hcmtlciI6NywiZmFkZU9uIjpmYWxzZSwiZmFkZVNlY29uZHMiOjAuNCwiZmFkZVRvIjowLCJmYWRlV2FrZSI6d"
    "HJ1ZSwiZm9udCI6Im5vbmUiLCJmb250T3V0bGluZSI6Im91dGxpbmUiLCJmb250U2l6ZSI6MTQsImhlaWdodCI6MjMwLCJoaXN0QnV0dG9uIjp"
    "0cnVlLCJoaXN0Q29uc29sZSI6dHJ1ZSwiaGlzdE9uIjp0cnVlLCJoaXN0U2l6ZSI6MzAwLCJoaXN0V2hpc3BlcnMiOiJnYW1lIiwiaWdub3JlQ"
    "2xpY2siOnRydWUsImltcHJvdmVkT24iOnRydWUsImlucHV0QmRBIjoxMDAsImlucHV0QmRCIjowLCJpbnB1dEJkRyI6MCwiaW5wdXRCZFIiOjA"
    "sImlucHV0QmdBIjo3MCwiaW5wdXRCZ0IiOjAsImlucHV0QmdHIjowLCJpbnB1dEJnUiI6MCwiaW5wdXRGb2N1c0JkIjp0cnVlLCJpbnB1dEgiO"
    "jI2LCJpbnB1dEhpbnQiOnRydWUsImlucHV0SGludFRleHQiOiJQcmVzcyBFbnRlciB0byBjaGF0IiwiaW5wdXRQb3MiOiJCT1RUT00iLCJsaW5"
    "rQiI6MSwibGlua0ciOjAuNzUsImxpbmtSIjowLjQsImxpbmtzIjp0cnVlLCJwb2ludCI6IkJPVFRPTUxFRlQiLCJzY3JvbGxCYXIiOiJISURFI"
    "iwic2Nyb2xsT3duIjp0cnVlLCJzY3JvbGxTcGVlZCI6Niwic2Nyb2xsVyI6MTAsInNvY2lhbE1vZGUiOiJISURFIiwic29jaWFsWCI6MCwic29"
    "jaWFsWSI6MCwic291bmRzIjp7fSwic291bmRzSW5Db21iYXQiOnRydWUsInNvdW5kc09uIjp0cnVlLCJzcGFtUGhyYXNlcyI6IiIsInNwYW1SZ"
    "XBlYXQiOnRydWUsInNwYW1TZWNvbmRzIjozMCwic3BhbVdvcmQiOmZhbHNlLCJzdHJpcE1vZGUiOiJISURFIiwic3RyaXBYIjowLCJzdHJpcFk"
    "iOjAsInRhYkJnQSI6NDUsInRhYkJnQiI6MCwidGFiQmdHIjowLCJ0YWJCZ09uIjp0cnVlLCJ0YWJCZ1IiOjAsInRhYkZvbnQiOiJub25lIiwid"
    "GFiRm9udFNpemUiOjEzLCJ0YWJIZWlnaHQiOjI0LCJ0YWJPdXRsaW5lIjoic2hhZG93IiwidGFiU2VsQiI6MC4zLCJ0YWJTZWxCZ0EiOjgwLCJ"
    "0YWJTZWxCZ0IiOjAuMTgsInRhYlNlbEJnRyI6MC4xOCwidGFiU2VsQmdSIjowLjE4LCJ0YWJTZWxHIjoxLCJ0YWJTZWxSIjowLjMsInRhYlRle"
    "HRCIjowLjc1LCJ0YWJUZXh0RyI6MC43NSwidGFiVGV4dFIiOjAuNzUsInRhYnNTaG93Ijp0cnVlLCJ0ZXh0RmFkZSI6ZmFsc2UsInRleHRGYWR"
    "lQWZ0ZXIiOjEyMCwidGV4dEluc2V0Ijo2LCJ0b0JvdHRvbSI6IlNIT1ciLCJ1c2VUaGVtZSI6ZmFsc2UsIndoaXNwZXJTZWxlY3QiOnRydWUsI"
    "ndoaXNwZXJTb3VuZHMiOnsiZmF2Ijp7ImVuYWJsZWQiOnRydWV9fSwid2hpc3BlclNvdW5kc09uIjp0cnVlLCJ3aWR0aCI6NDQwLCJ3cmFwSW5"
    "kZW50Ijp0cnVlLCJ4IjoyNCwieSI6OTB9LCJyZXNraW5UYWJPZmYiOnRydWV9LCJydWxlcyI6eyJhZGRvblZlcnNpb24iOiIwLjYuNzMiLCJmb"
    "2xkZXJzIjpbeyJkZWZhdWx0IjoiZGlzcGxheSIsImlkIjoiZjE3OTQwMDAwMDA4NTYxIiwibmFtZSI6IkRpc3BsYXkgQ3VlcyIsIm9yaWdpbiI"
    "6eyJhdCI6MTc5NDAwMDAwMCwiYnkiOiJYYXlhLUFyZWEgNTIiLCJob3ciOiJkZWZhdWx0In19LHsiZGVmYXVsdCI6InNvdW5kIiwiaWQiOiJmM"
    "Tc5NDAwMDAwMDQ1NDkiLCJuYW1lIjoiU291bmQgQ3VlcyIsIm9yaWdpbiI6eyJhdCI6MTc5NDAwMDAwMCwiYnkiOiJYYXlhLUFyZWEgNTIiLCJ"
    "ob3ciOiJkZWZhdWx0In19LHsiZGVmYXVsdCI6Imh5YnJpZCIsImlkIjoiZjE3OTQwMDAwMDA4MDQ3IiwibmFtZSI6Ikh5YnJpZCBDdWVzIiwib"
    "3JpZ2luIjp7ImF0IjoxNzk0MDAwMDAwLCJieSI6IlhheWEtQXJlYSA1MiIsImhvdyI6ImRlZmF1bHQifX0seyJkZWZhdWx0IjoiYWR2YW5jZWQ"
    "iLCJpZCI6ImYxNzk0MDAwMDAwODE4NSIsIm5hbWUiOiJBZHZhbmNlZCBDdWUgVHJhY2tpbmciLCJvcmlnaW4iOnsiYXQiOjE3OTQwMDAwMDAsI"
    "mJ5IjoiWGF5YS1BcmVhIDUyIiwiaG93IjoiZGVmYXVsdCJ9fSx7ImRlZmF1bHQiOiJjdXJzb3IiLCJpZCI6ImYxNzk0MDAwMDAwOTIwNCIsIm5"
    "hbWUiOiJNb3VzZSBDdXJzb3IgQ3VlcyIsIm9yaWdpbiI6eyJhdCI6MTc5NDAwMDAwMCwiYnkiOiJYYXlhLUFyZWEgNTIiLCJob3ciOiJkZWZhd"
    "Wx0In19XSwibmFtZSI6IiIsInJ1bGVzIjp7fSwidiI6MX0sInNldHRpbmdzIjp7Im1pbmltYXAiOnsiaGlkZSI6dHJ1ZSwibWluaW1hcFBvcyI"
    "6MjAwfSwidWkiOnsiYWR2YW5jZWREZWJ1ZyI6dHJ1ZSwiZnJpZW5kQ29sb3JzIjp7fSwic2VsU3R5bGUiOiJiYXIifX0sInRoZW1lcyI6eyJ0a"
    "GVtZSI6eyJiYXNlIjoiY3VzdG9tIiwiY2xhc3NlcyI6eyJ4dWktYnV0dG9uIjp7InRleHQiOlsxLDAsMCwxXX19LCJmb250Ijoibm9uZSIsInN"
    "pemUiOiJNIiwidG9rZW5zIjp7ImFjY2VudCI6WzAuMSwwLjIsMC4zLDFdfSwidW5kZXIiOiJkZWZhdWx0In0sInRoZW1lcyI6eyJNaW5lIjp7I"
    "mJhc2UiOiJkZWZhdWx0IiwiY2xhc3NlcyI6e30sImZvbnQiOiJub25lIiwic2l6ZSI6IkwiLCJ0b2tlbnMiOnsibGFiZWwiOlswLjUsMC41LDA"
    "uNSwxXX19fX19LCJ2IjoxfQ=="
)

SETUP = r'''
local function setup(W, L)
  -- a fixed clock: new groups get ids and dates from time() (the string must not change from run to run)
  local realTime = time
  time = function(t) if t ~= nil then return realTime(t) end return 1794000000 end
  L.startup()
  W.fire("PLAYER_LOGIN"); W.fire("PLAYER_ENTERING_WORLD", true, false); W.tick(0.1, 20)
  local ns = rawget(_G, "XayaUI_NS")
  if ns and ns.LoadOptions then pcall(ns.LoadOptions) end; W.tick(0.1, 5)
  ns = rawget(_G, "XayaUI_NS")
  -- the version both builds report (the string carries it; the new build has a newer number)
  local A = C_AddOns; local realGet = A.GetAddOnMetadata
  A.GetAddOnMetadata = function(a, f) if f == "Version" then return "0.6.73" end return realGet(a, f) end
  local DB = ns.SettingsRoutedForTests()   -- (P5) each key where its module reads it now (its own store or CueRulesDB)
  DB.theme = { base = "custom", under = "default", tokens = { accent = { 0.1, 0.2, 0.3, 1 } }, classes = { ["xui-button"] = { text = { 1, 0, 0, 1 } } }, font = "none", size = "M" }
  DB.themes = { Mine = { base = "default", tokens = { label = { 0.5, 0.5, 0.5, 1 } }, classes = {}, font = "none", size = "L" } }
  DB.ui = DB.ui or {}; DB.ui.selStyle = "bar"; DB.ui.hybridMigrated = true; DB.ui._tmp = 1
  DB.minimap = { hide = true, minimapPos = 200 }
  DB.cursorHighlight = DB.cursorHighlight or {}; DB.cursorHighlight.marker = 40; DB.cursorHighlight._x = 1
  DB.cursorTrail = DB.cursorTrail or {}; DB.cursorTrail.marker = 12
  DB.characterToolkit = DB.characterToolkit or {}; DB.characterToolkit.marker = 1
  DB.releaseGuard = DB.releaseGuard or {}; DB.releaseGuard.marker = true
  DB.cursor = { a = 1 }
  DB.dataPanels = DB.dataPanels or {}; DB.dataPanels.markerA = "a"
  DB.tooltips = DB.tooltips or {}; DB.tooltips.selfAura = { build = "x", ids = { [1] = true } }; DB.tooltips.marker = 3
  DB.calculator = { enabled = true, history = { "1+1 = 2" }, x = 5, point = "CENTER" }
  if __HAS_CHAT__ then   -- (QA-branch module XayaUI_Chat: its two stores exist only where the folder is)
    DB.chat2 = DB.chat2 or {}; DB.chat2.fadeMarker = 7; DB.chat2.whisperSounds = { list = { { who = "Friend-Realm" } }, fav = { enabled = true } }
    DB.chat = DB.chat or {}; DB.chat.marker = "c"
  end
  DB.characterReskin = DB.characterReskin or {}; DB.characterReskin.marker = true
  DB.reskinTabOff = true
  return ns
end
local HAS_CHAT, HAS_RESKIN, HAS_NP = __HAS_CHAT__, __HAS_RESKIN__, __HAS_NP__
local SIX = { rules = true, themes = true, settings = true, qol = true, bonus = true, reskin = true }
local function exportAll(ns)   -- the Export tab's Generate button with every part ticked
  local built = ns.BuildOptionsTable()
  local st = ns.OptionsApi.ProfileState()
  for k in pairs(st.profInc) do st.profInc[k] = true end
  built.args.profiles.args.export.args.gen.func()
  return built.args.profiles.args.export.args.exportBox.get()
end
'''

GOLDEN_LUA = SETUP + r'''
return function(W, L)
  local ns = setup(W, L)
  return { exportAll(ns), ns.Share.Encode("profile", ns.Profile.Snapshot(SIX, "")) }
end
'''

TEST_LUA = SETUP + r'''
return function(W, L, GOLDEN, npOn)
local R = {}
local function check(name, ok, extra) R[#R + 1] = { name .. (ok and "" or ("  [" .. tostring(extra) .. "]")), ok and true or false } end
local function skip(mod, name) R[#R + 1] = { "SKIP (QA-branch module absent: " .. mod .. ") " .. name, true, true } end
local function section(name, fn) local ok, err = pcall(fn); if not ok then check(name .. ": ran to its end (a Lua error stopped it)", false, err) end end
local ns = setup(W, L)
check("settings window addon loaded", ns and ns.BuildOptionsTable ~= nil and ns.Profile ~= nil)
if not (ns and ns.Profile) then return R end
local P = ns.Profile

if not npOn then
  section("A: byte-identical export", function()
    -- (Debug chat defaults, Chat 0.6.46) the one allowed difference from the old build's string: the Sidebar's (C.SIDEBAR_DEFAULTS)
    -- and the privacy cover's (ns.CHAT_DEFAULTS) defaults now reach the saved settings at login (in the game they never did), so the
    -- Blizzard Reskin part's chat2 / chat carry them, each with its default value. Taken out where they hold the default, the string
    -- must be the old build's byte for byte.
    local CD = ns.Service and ns.Service("chatDebug"); CD = CD and CD.C
    local added, qolV = 0, nil
    local function fold(str)
      local data = ns.Share.Read(str, "profile")
      local rk = type(data) == "table" and data.parts and data.parts.reskin
      for part, defs in pairs({ chat2 = CD and CD.SIDEBAR_DEFAULTS or {}, chat = ns.CHAT_DEFAULTS or {} }) do
        local t = rk and rk[part]
        if type(t) == "table" then for k, v in pairs(defs) do if t[k] == v then t[k] = nil; added = added + 1 end end end
      end
      -- (QoL 0.7.56, Stat Calculator V25) the second allowed difference: the QoL part is format 2 (XayaUI_QoL/ProfilePart.lua), so the
      -- string carries its part information (partInfo.qol, v = 2); keys and values unchanged. Taken out, the old string.
      local qi = type(data) == "table" and data.partInfo and data.partInfo.qol
      if qi then qolV = qi.v; data.partInfo.qol = nil; if next(data.partInfo) == nil then data.partInfo = nil end end
      return data and ns.Share.Encode("profile", data)
    end
    local box = exportAll(ns)
    local folded = fold(box)
    -- the old build's string carries parts of the QA-branch modules: with one absent, the old string is decoded and the keys of that
    -- module taken out of it, and the two decoded profiles are compared whole (key by key, values included) instead of as strings
    local gold = GOLDEN
    local same = (folded == GOLDEN)
    if not (HAS_CHAT and HAS_RESKIN) then
      local gd = ns.Share.Read(GOLDEN, "profile")
      local rk = type(gd) == "table" and gd.parts and gd.parts.reskin
      if rk and not HAS_CHAT then rk.chat2 = nil; rk.chat = nil end
      -- without XayaUI_Reskin the Character pane's own keys (Modules.lua LEGACY_SPLIT.characterReskin.sub) are not saved; QoL's half stays
      if rk and rk.characterReskin and not HAS_RESKIN then
        for _, k in ipairs({ "enabled", "chrome", "stats", "bgAlpha", "wide", "widePx", "widePxTo42", "tallPx" }) do rk.characterReskin[k] = nil end
      end
      -- ...and the Settings part's ui.friendColors (Modules.lua LEGACY_UNDER_UI.reskin: rsk, gm, friendColors) is XayaUI_Reskin's too
      local st = type(gd) == "table" and gd.parts and gd.parts.settings
      if st and st.ui and not HAS_RESKIN then st.ui.friendColors = nil; st.ui.rsk = nil; st.ui.gm = nil end
      local function eq(x, y)
        if type(x) ~= type(y) then return false end
        if type(x) ~= "table" then return x == y end
        for k, v in pairs(x) do if not eq(v, y[k]) then return false end end
        for k in pairs(y) do if x[k] == nil then return false end end
        return true
      end
      same = eq(ns.Share.Read(folded, "profile"), gd)
    end
    check("A: Generate with every part ticked gives exactly the old build's string (XayaUI Nameplates off), but for the Chat defaults now saved and the QoL part's format 2", same, tostring(folded):sub(1, 60))
    if HAS_CHAT then
      check("A: ... those are the Sidebar's and the privacy cover's defaults, all of them (" .. added .. ")", CD and added == (function() local n = 0 for _ in pairs(CD.SIDEBAR_DEFAULTS) do n = n + 1 end for _ in pairs(ns.CHAT_DEFAULTS) do n = n + 1 end return n end)(), added)
    else
      skip("XayaUI_Chat", "A: ... those are the Sidebar's and the privacy cover's defaults, all of them")
    end
    check("A: ...the QoL part says it is format 2 (partInfo.qol.v = 2)", qolV == 2, qolV)
    local six = ns.Share.Encode("profile", P.Snapshot(SIX, ""))
    check("A: the six parts ticked by hand give the same string", six == box, tostring(six):sub(1, 60))
  end)
  section("C: a part whose module is not loaded", function()
    check("C: Nameplates is not offered while XayaUI Nameplates is off", P.BY_KEY.nameplates == nil)
    local data = P.Snapshot({ settings = true }, "x")
    data.parts.nameplates = { targetColor = false, color = { 1, 0, 0 } }
    data.partInfo = { nameplates = { v = 1, module = "XayaUI_Nameplates", title = "XayaUI Nameplates", label = "Nameplates" } }
    local txt = ns.Share.Encode("profile", data)
    local back, def = ns.Share.Read(txt)
    check("C: the pasted profile keeps the part", back and back.parts and type(back.parts.nameplates) == "table", back and back.parts and tostring(back.parts.nameplates))
    local miss = P.Missing(back)
    check("C: it is listed as missing, with its addon's title", #miss == 1 and miss[1].title == "XayaUI Nameplates", #miss)
    local built = ns.BuildOptionsTable()
    built.args.profiles.args.import.args.importBox.set({}, txt)
    built = ns.BuildOptionsTable()
    local ia = built.args.profiles.args.import.args
    local line = ia.needs_nameplates and ia.needs_nameplates.name
    check("C: Import shows the line \"needs XayaUI Nameplates\"", line == "needs XayaUI Nameplates", line)
    local before = CueRulesDB.ui.selStyle
    CueRulesDB.ui.selStyle = "text"
    local res = def.Apply(back, { inc = { settings = true, nameplates = true }, rules = "add" })
    check("C: Import skips it and says which addon it needs", res and res.skipped and res.skipped[1] == "XayaUI Nameplates" and #res.done == 1 and res.done[1] == "Settings",
      res and table.concat(res.done or {}, ",") .. " / " .. table.concat(res.skipped or {}, ","))
    check("C: ...and the other part still imports", CueRulesDB.ui.selStyle == before, CueRulesDB.ui.selStyle)
    check("C: nothing of the skipped part was written anywhere", rawget(_G, "XayaUINameplatesDB") == nil)
    local junk = P.Check({ v = 1, parts = { evil = { x = 1 }, settings = { minimap = { hide = true } } } })
    check("C: a part that names no addon is still dropped", junk.parts.evil == nil and junk.parts.settings ~= nil)
  end)
else
  section("B: the Nameplates part", function()
    local NP = ns.Service("nameplates")
    check("B: XayaUI Nameplates is on in this run", NP ~= nil)
    local d = NP.DB()
    d.color = { 0.2, 0.4, 0.6 }; d.targetColor = true; d.blizzBefore = { nameplateShowAll = "1" }
    local built = ns.BuildOptionsTable()
    local tick = built.args.profiles.args.export.args.inc_nameplates
    check("B: Export offers a Nameplates tick box, ticked", tick and tick.name == "Nameplates" and tick.get() == true, tick and tick.name)
    local box = exportAll(ns)
    local data = ns.Share.Read(box)
    local np = data and data.parts and data.parts.nameplates
    check("B: the profile carries the target colour switch and colour", np and np.targetColor == true and np.color and math.abs(np.color[2] - 0.4) < 1e-9, np and tostring(np.color))
    check("B: ...never the Put back store (blizzBefore)", np and np.blizzBefore == nil)
    local info = data and data.partInfo and data.partInfo.nameplates
    check("B: the part says its format version and addon", info and info.v == 1 and info.module == "XayaUI_Nameplates" and info.title == "XayaUI Nameplates", info and tostring(info.title))
    check("B: the six older parts carry no part information (their strings stay as before)", data and data.partInfo and data.partInfo.rules == nil and data.partInfo.reskin == nil)
    d.color = { 1, 1, 1 }; d.targetColor = false
    local back, def = ns.Share.Read(box)
    local res = def.Apply(back, { inc = { nameplates = true }, rules = "add" })
    check("B: Import puts the colour and the switch back", math.abs(d.color[1] - 0.2) < 1e-9 and math.abs(d.color[3] - 0.6) < 1e-9 and d.targetColor == true, d.color[1])
    check("B: ...and asks for a reload", res and res.reload == true and res.done[1] == "Nameplates", res and table.concat(res.done or {}, ","))
  end)
end

section("D: Recycle Bin kinds", function()
  check("D: the six rule kinds are registered", ns.BinKind and ns.BinKind("rule") and ns.BinKind("group") and ns.BinKind("groupAll") and ns.BinKind("cue") and ns.BinKind("condition") and ns.BinKind("trigger") and true or false)
  local r
  for _, x in ipairs(ns.rules or {}) do if not x.parentUid then r = x; break end end
  if not r then r = { name = "QA bin rule", enabled = false }; ns.rules[#ns.rules + 1] = r end
  local n0 = #ns.rules
  local it = ns.RecycleRule(r)
  local items = ns.RecycleItems()
  local row
  for _, x in ipairs(items) do if x.id == it.id then row = x end end
  check("D: a deleted rule reads 'Rule' on the page", row and row.what == "Rule", row and row.what)
  local calls = 0
  local k = ns.BinKind("rule"); local realRestore = k.restore
  k.restore = function(i) calls = calls + 1; return realRestore(i) end
  local ok = ns.RecycleRestore(it.id)
  k.restore = realRestore
  local back = false
  for _, x in ipairs(ns.rules) do if x == r then back = true end end
  check("D: Restore goes through the registered kind and the rule is back", ok and calls == 1 and back and #ns.rules == n0, calls)
  local b = ns.RecycleDB()
  b.items[#b.items + 1] = { id = 9001, kind = "notepadPage", name = "My page", deletedAt = time(), rules = {} }
  local seen
  for _, x in ipairs(ns.RecycleItems()) do if x.id == 9001 then seen = x end end
  check("D: an item of an unregistered kind reads \"(notepadPage: module not loaded)\"", seen and seen.what == "(notepadPage: module not loaded)", seen and seen.what)
  local ok2, note = ns.RecycleRestore(9001)
  local still = false
  for _, x in ipairs(b.items) do if x.id == 9001 then still = true end end
  check("D: Restore refuses it and it stays in the bin, untouched", ok2 == false and still and note == "(notepadPage: module not loaded)" and #ns.rules == n0, note)
  local built = ns.BuildOptionsTable()
  -- (a long line is folded into the item's (i) info by the window, Options.lua; so every text of the item's group is searched)
  local function texts(t, out, d)
    if type(t) ~= "table" or d > 6 then return out end
    for _, v in pairs(t) do if type(v) == "string" then out[#out + 1] = v elseif type(v) == "table" then texts(v, out, d + 1) end end
    return out
  end
  local found
  for _, v in pairs(built.args.profiles.args.bin.args) do
    if type(v) == "table" and v.name == "My page" then found = table.concat(texts(v, {}, 1), " | ") end
  end
  check("D: the bin page shows it with that line", found and found:find("(notepadPage: module not loaded)", 1, true) ~= nil, found)
  ns.RegisterBinKind({ kind = "notepadPage", label = "Notepad page", describe = function(i) return "Notepad page" end, restore = function(i) i.restored = true; return true, "" end })
  local ok3 = ns.RecycleRestore(9001)
  still = false
  for _, x in ipairs(b.items) do if x.id == 9001 then still = true end end
  check("D: once its module registers the kind, Restore uses it and the item leaves the bin", ok3 == true and not still)
end)

section("E: theme scopes", function()
  local T = ns.Theme
  T.Resolve()   -- the setup wrote the theme directly; resolve it as the game does at login
  local base = {}
  for _, c in ipairs(T.CLASSES) do for prop in pairs(c[3]) do base[c[1] .. "." .. prop] = T.Col(c[1], prop) end end
  local function same(a, b) return a and b and a[1] == b[1] and a[2] == b[2] and a[3] == b[3] and a[4] == b[4] end
  if HAS_RESKIN then
    check("E: scopes are registered with their page titles", T.Scope and T.Scope("reskin") and T.Scope("reskin").label == "Blizzard Reskin"
      and T.Scope("reskin.tooltips") and T.Scope("reskin.tooltips").label == "Tooltips" and T.Scope("reskin.tooltips").parent == "reskin"
      and T.Scope("reskin.chatpanel") and T.Scope("reskin.chatpanel").label == "Chat Panel" and T.Scope("reskin.charreskin").label == "Character Reskin"
      and T.Scope("reskin.gamemenu").label == "Esc Menu" and T.Scope("settings").label == "Settings window" and true or false)
    local n = 0
    for _, id in ipairs(T.scopeList or {}) do if id:find("^reskin%.") and id ~= "reskin.chatpanel" and id ~= "reskin.charreskin" then n = n + 1 end end
    check("E: the 13 reskin pages each have a scope", n == 13, n)
  else
    skip("XayaUI_Reskin", "E: scopes are registered with their page titles (Tooltips, Chat Panel, Esc Menu: registered by the Reskin pages)")
    skip("XayaUI_Reskin", "E: the 13 reskin pages each have a scope")
    -- what the folders present do register: the core's two and QoL's Character Pane
    check("E (present modules): the core's scopes and QoL's Character Pane are registered with their page titles", T.Scope and T.Scope("reskin") and T.Scope("reskin").label == "Blizzard Reskin"
      and T.Scope("settings") and T.Scope("settings").label == "Settings window" and T.Scope("reskin.charreskin") and T.Scope("reskin.charreskin").label == "Character Reskin" and true or false)
    -- the checks below resolve colours through two pages the Reskin folder registers (reskin.tooltips, reskin.menus): stand-ins with the same
    -- ids and parent, so the resolution order (core Theme.lua) is still asserted
    T.RegisterScope({ id = "reskin.tooltips", label = "Tooltips", parent = "reskin" })
    T.RegisterScope({ id = "reskin.menus", label = "Menus", parent = "reskin" })
  end
  check("E: nothing is stored while no scope overrides anything", CueRulesDB.theme.scopes == nil)
  T.SetScopeToken("reskin.tooltips", "buttonBg", { 0.9, 0.1, 0.1, 1 })
  T.SetScopeClassColor("reskin", "xui-window", "bg", { 0.2, 0.9, 0.2, 1 })
  T.SetScopeTheme("reskin.menus", "Mine")
  local bad = {}
  for _, c in ipairs(T.CLASSES) do for prop in pairs(c[3]) do if not same(T.Col(c[1], prop), base[c[1] .. "." .. prop]) then bad[#bad + 1] = c[1] .. "." .. prop end end end
  check("E: with scopes set, every call without a scope gives exactly the old answer", #bad == 0, table.concat(bad, ","))
  check("E: ...and a fallback table is still a fallback, not a scope", same(T.Col("no-such-class", "bg", { 0.3, 0.3, 0.3, 1 }), { 0.3, 0.3, 0.3, 1 }))
  check("E: 1. the element's own override wins", same(T.Col("xui-button", "bg", "reskin.tooltips"), { 0.9, 0.1, 0.1, 1 }), T.ColFrom("xui-button", "bg", "reskin.tooltips"))
  check("E: 3. the module's override reaches its element", same(T.Col("xui-window", "bg", "reskin.tooltips"), { 0.2, 0.9, 0.2, 1 }) and T.ColFrom("xui-window", "bg", "reskin.tooltips") == "reskin")
  check("E: 2. the element's chosen theme beats the module's override", same(T.Col("xui-label", "text", "reskin.menus"), { 0.5, 0.5, 0.5, 1 }) and T.ColFrom("xui-label", "text", "reskin.menus") == "reskin.menus")
  check("E: 4. what no scope sets comes from the global theme", same(T.Col("xui-text", "text", "reskin.tooltips"), base["xui-text.text"]) and T.ColFrom("xui-text", "text", "reskin.tooltips") == "global")
  check("E: a scope outside the reskin tab is untouched by its overrides", same(T.Col("xui-window", "bg", "settings"), base["xui-window.bg"]))
  CueRulesDB.theme.scopes["reskin.tooltips"].tokens.buttonBg = { 0, 0, 1, 1 }
  local stale = T.Col("xui-button", "bg", "reskin.tooltips")
  T.Resolve()
  check("E: resolved colours are cached and the cache is dropped on Resolve", same(stale, { 0.9, 0.1, 0.1, 1 }) and same(T.Col("xui-button", "bg", "reskin.tooltips"), { 0, 0, 1, 1 }))
  local data = ns.Share.Read(ns.Share.Encode("profile", P.Snapshot({ themes = true }, "s")))
  local sc = data and data.parts.themes.theme.scopes
  check("E: the Themes profile part carries the scopes", sc and sc["reskin.menus"] and sc["reskin.menus"].theme == "Mine" and sc.reskin.classes["xui-window"].bg[2] == 0.9)
  T.ResetScope("reskin.menus"); T.SetScopeClassColor("reskin", "xui-window", "bg", nil); T.SetScopeToken("reskin.tooltips", "buttonBg", nil)
  check("E: removing every override leaves nothing stored (sparse)", CueRulesDB.theme.scopes == nil, CueRulesDB.theme.scopes and next(CueRulesDB.theme.scopes))
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
    if "--golden" in sys.argv:
        L, world, loader = runtime(lambda n: n not in ("XayaUI_DevAssist", "XayaUI_Nameplates"))
        res = L.eval("function(src, W, Ld) return loadstring(src)()(W, Ld) end")(fill(GOLDEN_LUA), world, loader)
        print("BUTTON " + str(res[1]))
        print("SIX " + str(res[2]))
        return
    bad, total, errs_all = 0, 0, []
    fill = lambda src: (src.replace("__HAS_CHAT__", str(HAS["Chat"]).lower()).replace("__HAS_RESKIN__", str(HAS["Reskin"]).lower())
                        .replace("__HAS_NP__", str(HAS["Nameplates"]).lower()))
    for np_on in (False, True):
        if np_on and not HAS["Nameplates"]:
            print("SKIP (QA-branch module absent: XayaUI_Nameplates) [Nameplates on] B: the Nameplates part (whole run: Export offers it, the string carries it, Import puts it back)")
            continue
        L, world, loader = runtime(lambda n: n != "XayaUI_DevAssist" and (np_on or n != "XayaUI_Nameplates"))
        res = L.eval("function(src, W, Ld, g, np) return loadstring(src)()(W, Ld, g, np) end")(fill(TEST_LUA), world, loader, GOLDEN, np_on)
        tag = "[Nameplates on] " if np_on else "[Nameplates off] "
        for i in range(1, len(res) + 1):
            name, ok = res[i][1], res[i][2]
            if len(res[i]) >= 3 and res[i][3]:
                print(name.replace(") ", ") " + tag, 1))
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
