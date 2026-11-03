XayaUI Media: your own pictures and sounds
===========================================
Why this folder exists: updating XayaUI replaces the whole XayaUI folder, so anything you put inside it is lost. World of Warcraft can
only load files from inside Interface\AddOns, so the safe place is a SEPARATE addon folder next to it: this one. XayaUI never touches it.
Rules saved in XayaUI point at these files by path, so they keep working after any XayaUI update.

1. Put files here (inside this folder):
     Graphics\   pictures used as textures/overlays
     Icons\      small square pictures used as icons
     Sounds\     sound files
   Pictures: .png, .tga, .blp or .jpg. Width and height must each be a power of two (16, 32, 64, 128, 256, 512...). They do not need to
   be square. PNG must be listed with its .png ending (the script does this). Sounds: .ogg or .mp3.
   Icons\ must be SQUARE and at most 200x200 pixels (the script skips any that are not; in practice 32, 64 or 128 because of the power-of-two rule).
   Subfolders are fine. Avoid spaces and odd characters in file names.
2. Run Update-UserMedia.py (needs Python 3; double-click it or run: python Update-UserMedia.py). It scans the folders, checks each picture's
   size, and rewrites UserMedia.lua. It prints a warning for any file the game will probably not draw.
   No Python? Edit UserMedia.lua by hand: copy one line and change it.
3. In game type /reload (new files in an AddOns folder normally need only a reload; if a picture or sound is still missing, restart the game).
4. Open /xui. Your files appear in the texture / sound lists as "[User] name" and "[User icon] name".

Check with /xui media in game: it says whether this addon is loaded and how many files it found.
Sharing a rule with someone else: they need the same files in their own XayaUI_Media folder, or the art/sound will be blank/silent for them.
Back this folder up yourself; it is the only copy of your files.
