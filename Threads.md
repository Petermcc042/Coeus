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
