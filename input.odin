package main

import "core:math"
import rl "vendor:raylib"

process_user_input :: proc(app: ^App, cellsView: ^CellsView) {
	m_pos := rl.GetMousePosition()

	// Calculate tile based on pixel / cell size directly
	mouse_x := i32(m_pos.x / cellsView.charBlock.width)
	mouse_y := i32(m_pos.y / cellsView.charBlock.height)

	m_worl_pos := mouse_y * cellsView.charColumns + mouse_x

	// Clamp to current grid bounds
	mouse_x = clamp(mouse_x, 0, cellsView.charColumns - 1)
	mouse_y = clamp(mouse_y, 0, cellsView.charRows - 1)

	if rl.IsKeyPressed(.ENTER) {
		cellsView.fileLoadingUnderway = true
		cellsView.runeCountNeedsStarted = true
	}

	if rl.IsKeyPressed(.EQUAL) && rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyPressed(.KP_ADD) {
		update_text_size(true, cellsView)
	}

	if rl.IsKeyPressed(.MINUS) && rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyPressed(.KP_SUBTRACT) {
		update_text_size(false, cellsView)
	}

	scroll := rl.GetMouseWheelMove()

	if scroll != 0 {
		if (rl.IsKeyDown(.LEFT_SHIFT)) {
			//do nothing
		} else {
			// Adjust how fast a single wheel tick scrolls.
			// e.g., 'row_delta * 3' would scroll 3 rows per notch.
			row_delta := i32(scroll * -1) * 3

			cellsView.currentFileRow = math.max(cellsView.currentFileRow + row_delta, 0)
		}
	}


	app^ = App {
		left_mouse_clicked   = rl.IsMouseButtonDown(.LEFT),
		right_mouse_clicked  = rl.IsMouseButtonDown(.RIGHT),
		toggle_pause         = rl.IsKeyPressed(.SPACE),
		mouse_world_position = mouse_y * cellsView.charColumns + mouse_x,
		mouse_charBlock_x    = mouse_x,
		mouse_charBlock_y    = mouse_y,
	}
}
