# Coeus
This is a personal fun exploration into rendering csv's using Odin + Raylib.
It is part of generally learning Odin + Raylib to build cross platform performant apps in the age of slop.

## Technical implementation
- Built in **Odin** on top of **Raylib**: resizable window + monospaced `JetBrainsMono` font, rendering text via `DrawTextCodepoint` in a real-time draw loop.
- **Non-blocking CSV load** (triggered on Enter) uses `core:thread` in two phases: stream-count UTF-8 runes (to preallocate a fixed `[]rune`), then load+decode the file into that array while also building row start offsets for fast vertical scrolling.
- **Viewport renderer** walks the rune buffer from the current row offset, does minimal CSV parsing (commas/newlines + quote toggling), clips cells using per-column widths, draws column dividers, and shows a footer with FPS + cursor cell coordinates.

# Things to do

## Header Row Recognition
Currently you just scroll past the header.

## search/filter
No idea how to start this atm will get to it... maybe.

## Render Blocks of text 
currently the code renders every single character as an individual draw call. 
As we loop over the characters required in the frame they could be added to one array of size (width * height)
from here as long as there are '\n' characters we can pass a whole array to rl.DrawTextEx()
This should cut it down to one draw call.
Not sure how we convert the array of runes to strings to do this
