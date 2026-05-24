package main

import "core:fmt"
import "core:thread"
import "core:time"
import rl "vendor:raylib"

// Reuse our payload structure
Thread_Data :: struct {
	input:  []rune,
	output: []rune,
}

worker_proc :: proc(t: ^thread.Thread) {
	data := cast(^Thread_Data)t.data
	for r, index in data.input {
		// Simulate some heavy computations by stalling
		// (Don't use time.sleep in actual fast code, this just simulates long work)
		if r == 'a' do data.output[index] = 'A'
		else do data.output[index] = r
	}
}

// main :: proc() {
// 	run()
// }

run :: proc() {
	rl.InitWindow(800, 450, "Odin Thread Polling Example")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	// State tracking variables
	background_thread: ^thread.Thread = nil
	task_data: Thread_Data
	thread_active := false
	work_completed := false

	for !rl.WindowShouldClose() {
		// --- 1. UPDATE / POLL THE THREAD ---
		if thread_active && background_thread != nil {
			// This call checks atomic state registers non-blockingly!
			if thread.is_done(background_thread) {

				// Clean up the thread resources completely
				thread.join(background_thread)
				thread.destroy(background_thread)
				background_thread = nil

				thread_active = false
				work_completed = true // Signals the UI it can now display the data safely
				fmt.println("Thread finished execution safely!")
			}
		}

		// --- 2. INPUT HANDLING ---
		// Start the thread only if it's not already running on press Space bar
		if rl.IsKeyPressed(.SPACE) && !thread_active {
			work_completed = false

			// Setup data arrays
			task_data.input = []rune {
				'r',
				'a',
				'y',
				'l',
				'i',
				'b',
				' ',
				'a',
				'n',
				'i',
				'm',
				'a',
				't',
				'i',
				'o',
				'n',
			}
			task_data.output = make([]rune, len(task_data.input)) // Allocate

			background_thread = thread.create(worker_proc)
			if background_thread != nil {
				background_thread.data = &task_data
				thread.start(background_thread)
				thread_active = true
			}
		}

		// --- 3. DRAWING ---
		rl.BeginDrawing()
		rl.ClearBackground(rl.RAYWHITE)

		if thread_active {
			rl.DrawText("Processing array in background thread...", 40, 40, 20, rl.DARKGRAY)
			// The game is not freezing! A loading spinner would spin completely smoothly here.
			rl.DrawCircle(400, 220, 30, rl.MAROON)
		} else if work_completed {
			rl.DrawText("Work completed successfully!", 40, 40, 20, rl.LIME)
			// It is completely safe to read task_data.output here because the thread is destroyed
			rl.DrawText(
				rl.TextFormat("Output raw data address: %p", &task_data.output[0]),
				40,
				80,
				20,
				rl.BLACK,
			)
		} else {
			rl.DrawText(
				"Press SPACE to spin up a background worker thread",
				40,
				40,
				20,
				rl.DARKGRAY,
			)
		}

		rl.EndDrawing()
	}

	// --- 4. EMERGENCY TIDY-UP ---
	// If the user exits the window while the background thread is running,
	// clean it up to prevent an orphan process freeze or a leak.
	if background_thread != nil {
		thread.join(background_thread)
		thread.destroy(background_thread)
	}
	if len(task_data.output) > 0 {
		delete(task_data.output)
	}
}
