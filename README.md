# Coeus
This is a personal fun exploration into rendering csv's using Odin + Raylib.
It is part of generally learning Odin + Raylib to build cross platform performant apps in the age of slop.

## Technical implementation
- Built in **Odin** on top of **Raylib**: resizable window + monospaced `JetBrainsMono` font, rendering text via `DrawTextCodepoint` in a real-time draw loop.
- **Non-blocking CSV load** (triggered on Enter) uses `core:thread` in two phases: stream-count UTF-8 runes (to preallocate a fixed `[]rune`), then load+decode the file into that array while also building row start offsets for fast vertical scrolling.
- **Viewport renderer** walks the rune buffer from the current row offset, does minimal CSV parsing (commas/newlines + quote toggling), clips cells using per-column widths, draws column dividers, and shows a footer with FPS + cursor cell coordinates.

# Things to do

## Sizing of columns
this should be easy the only tough bit is learning how to work with on mouse down and mouse exit to determine drag distance.
perhaps in loading a file we should also store the max character width of a column.
If it is less than the default min size of the field we could set the field width to that instead.

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


Boiled down to its absolute essentials, the lifecycle of managing a non-blocking background thread in Odin follows a strict **5-step sequence**:

* **1. Allocate & Package**
Pre-allocate your output memory containers (like slices) on the main thread and bundle them with your input data inside a custom struct payload. This prevents threads from wrestling over memory allocation locks.
* **2. Create & Initialize**
Instantiate the worker with `thread.create(worker_proc)`. Assign your custom data bundle pointer to the thread's built-in `t.data` slot.
* **3. Kickoff**
Call `thread.start(t)`. The thread immediately forks into the background, allowing your main rendering loop to continue executing seamlessly without frame drops.
* **4. Non-Blocking Poll**
Inside your main application loop, query `thread.is_done(t)` every frame. This reads an atomic status flag instantly without blocking execution.
* **5. Join, Destroy & Consume**
Once `is_done` returns true, execute `thread.join(t)` followed by `thread.destroy(t)` to free the OS handle and internal memory structures. Your main thread can now safely consume or display the output data.
