package main

import "core:os"
import "core:thread"
import rl "vendor:raylib"

csv_file_name :: "data/testey.csv" //easy
// csv_file_name :: "data/testier.csv"
// csv_file_name :: "data/customers-500000.csv"


Window :: struct {
	name:   cstring,
	width:  i32, // width in pixels
	height: i32, // height in pixels
	fps:    i32,
}

App :: struct {
	pause:                bool,
	resizeNeeded:         bool,

	// input state
	left_mouse_clicked:   bool,
	right_mouse_clicked:  bool,
	toggle_pause:         bool,
	mouse_world_position: i32,
	mouse_charBlock_x:    i32, // the mouses character column position
	mouse_charBlock_y:    i32, // the mouses character row position
	mouse_fieldNum:       i32, // the mouses field column position
	doubleClickThreshold: f32, // the mouses field column position
	lastClickTime:        f32,
	doubleClick:          bool,
}

// contains the info on width and height of a mono character
CharacterBlock :: struct {
	width:  f32,
	height: f32,
}


// this is the actual panel where cells will be shown
// it contains the information about what file is loaded
CellsView :: struct {
	preprocessed:               bool,
	colors:                     []rl.Color,
	font:                       rl.Font,
	fontSize:                   f32,
	charWidth:                  f32,
	charHeight:                 f32,
	topLeft:                    [2]f32,
	bottomRight:                [2]f32,


	// layout of the cells
	charColumns:                i32, // width of the viewer in columns
	charRows:                   i32, // height of the viewer in rows
	fileRowCharIndices:         [dynamic]RowInfo, // the index positions in []fileRunes that are the start of rows
	fieldRenderHeights:         []i32, // an array containing the height in characters of each row of fields being displayed
	fieldRenderWidths:          []i32, // an array containing the width in characters of each column of fields being displayed
	fileFieldsTypes:            []FieldType,

	// to render
	containsHeader:             bool,
	currentFileRow:             i32,
	runesToRender:              []rune,

	//this bool controls the whole file loading system
	fileLoadingUnderway:        bool,

	// rune count thread
	runeCountNeedsStarted:      bool,
	runeCountSuccess:           bool,
	runeCountThread:            ^thread.Thread,
	runeCountThreadActive:      bool,
	runeCountThreadComplete:    bool,
	fileNumRunes:               i32,
	fileCurrentPath:            string,

	// file loader thread
	fileRunes:                  []rune, // the loaded file
	runeArrayNeedsInitialised:  bool, // used to kick off rune array initialisation
	fileLoadNeedsStarted:       bool, // used to begin the thread to load the current file
	fileProcessingNeedsStarted: bool, // used to begin the column and row count proc
	fileLoadSuccess:            bool, // were there any errors in the file load thread
	fileLoadThread:             ^thread.Thread,
	fileLoadThreadActive:       bool,
	fileLoadThreadComplete:     bool,
	// fileCurrentPath:         string, used from above
}


Footer :: struct {
	topLeft:     [2]f32,
	bottomRight: [2]f32,
	chars:       [1000]rune,
	rune_index:  i32,
	font:        rl.Font,
	fontSize:    f32,
	charWidth:   f32,
	charHeight:  f32,
}

Header :: struct {
	topLeft:     [2]f32,
	bottomRight: [2]f32,
	chars:       [1000]rune,
	rune_index:  i32,
	font:        rl.Font,
	fontSize:    f32,
	charWidth:   f32,
	charHeight:  f32,
}

FilePanel :: struct {
	topLeft:       [2]f32, // x.y coord of the top left of the pane
	bottomRight:   [2]f32, // x.y coord of the bottom right of the pane
	chars:         [10000]rune,
	rune_index:    i32,
	font:          rl.Font,
	fontSize:      f32,
	charWidth:     f32,
	charHeight:    f32,
	charColumns:   i32, // number of columns in the pane determined by char width
	directoryList: []os.File_Info,
	hoverIndex:    i32, // will be -1 if we are not on a file
}


FieldType :: enum {
	String,
	Numeric,
	Int,
	Float,
	Date,
}

RowInfo :: struct {
	rowStartIndex: i32,
	rowEndIndex:   i32,
}
