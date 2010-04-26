module GridInput;

private {
	import xf.hybrid.Common;
	import xf.hybrid.Hybrid;
	import tango.io.Stdout;
}



struct DynamicGridInputModel {
	void delegate() onAddRow;
	void delegate(int index) onRemoveRow;
	void delegate(int row, int column, char[] val) onCellChanged;
	
	int delegate() getNumRows;
	int delegate() getNumColumns;
	char[] delegate(int row, int column) getCellValue;
}



class DynamicGridInput : Group {
	
	// TODO; optimize my memory usage
	struct State {
		int		rows;
		int		columns;
		char[][]	data;
		
		char[] opIndex(int row, int col) {
			return data[row * columns + col];
		}
		
		void opIndexAssign(char[] val, int row, int col) {
			int off = row * columns + col;
			if (data.length <= off) {
				data.length = off+1;
			}
			data[off].length = val.length;
			data[off][] = val;
		}
	}
	
	
	State		prevState;
	vec2i		focused;
	bool			keyHandlerInstalled = false;
	Input[][]	cells;
	
	const vec2	cellSize			= {x: 100, y: 0};
	const vec2	cellSpacing	= {x: 2, y: 2};
	
	
	this() {
		addHandler(&keyHandler);
	}
	
	
	void setFocus() {
		auto foc = cells[focused.y][focused.x];
		foc.inputArea.grabKeyboardFocus();
	}
	
	
	protected EventHandling keyHandler(KeyboardEvent e) {
		if (cells.length > 0) {
			switch (e.keySym) {
				case KeySym.Tab: if (e.sinking && e.down) {
					if (e.modifiers & e.modifiers.SHIFT) {
						--focused.x;
						if (focused.x < 0) {
							focused.x = cells[0].length-1;
						}
					} else {
						++focused.x;
						if (focused.x >= cells[0].length) {
							focused.x = 0;
						}
					}
					
					setFocus();
				} return EventHandling.Stop;

				case KeySym.Up:
				case KeySym.Down:
				case KeySym.Return: if (e.sinking && e.down) {
					bool up = KeySym.Up == e.keySym;
					up |= (KeySym.Return == e.keySym && (e.modifiers & e.modifiers.SHIFT) != 0);
					
					if (up) {
						--focused.y;
						if (focused.y < 0) {
							focused.y = cells.length-1;
						}
					} else {
						++focused.y;
						if (focused.y >= cells[0].length) {
							focused.y = cells.length-1;
						}
					}
					
					if (KeySym.Return == e.keySym) {
						focused.x = 0;
					}
					
					auto foc = cells[focused.y][focused.x];
					foc.inputArea.grabKeyboardFocus();
				} return EventHandling.Stop;

				default: break;
			}
		}

		return EventHandling.Continue;
	}
	
	
	void addRow(DynamicGridInputModel model) {
		int cols = model.getNumColumns();
		cells.length = cells.length + 1;
		foreach (ref c; cells) {
			c.length = cols;
		}
		model.onAddRow();
	}
	

	void removeRow(DynamicGridInputModel model, int i) {
		for (int y = i; y+1 < cells.length; ++y) {
			for (int x = 0; x < cells[y].length; ++x) {
				cells[y][x].text = cells[y+1][x].text;
			}
		}
		foreach (ref c; cells[$-1]) {
			c = null;
		}
		cells.length = cells.length - 1;
		model.onRemoveRow(i);
	}
	
	
	private bool externalStateChange(DynamicGridInputModel model) {
		int modelRows = model.getNumRows();
		int modelCols = model.getNumColumns();
		
		int rows = 0;
		if ((rows = prevState.rows-1) != modelRows) {
			return true;
		} else {
			int cols = 0;
			if (cells.length > 0 && (cols = modelCols) != cells[0].length) {
				return true;
			} else {
				for (int y = 0; y < rows; ++y) {
					for (int x = 0; x < cols; ++x) {
						if (model.getCellValue(y, x) != prevState.data[y * cols + x]) {
							return true;
						}
					}
				}
			}
		}
		
		return false;
	}
	
	
	void doGUI(bool shouldSetFocus, DynamicGridInputModel model) {
		this.open;
		scope (exit) gui.close;
		
		int rows = model.getNumRows();
		int cols = model.getNumColumns();

		bool recreate = false;
		if (rows+1 != cells.length) {
			recreate = true;
			cells.length = rows+1;
			foreach (ref c; cells) {
				c.length = cols;
			}
		} else if (externalStateChange(model)) {
			recreate = true;
		}
		focused = vec2i.zero;
		
		VBox().spacing(cellSpacing.y).padding(vec2(5, 5)) [{
			int emptyRow = -1;
			
			HBox().spacing(cellSpacing.x) [{
				Label().text(`type`).userSize = cellSize;
				Label().text(`name`).userSize = cellSize;
				Label().text(`semantic`).userSize = cellSize;
			}];
			
			for (int y = 0; y < rows+1; ++y) {
				bool empty = true;
				bool created = false;
				
				HBox(y).spacing(cellSpacing.x) [{
					for (int x = 0; x < cols; ++x) {
						auto input = Input(x);
						if (cells[y][x] is null) {
							input.text = null;
						}
						
						cells[y][x] = input;
						input.userSize = cellSize;
						
						if (recreate) {
							input.text = model.getCellValue(y, x);
						}
						
						if (input.text.length > 0) {
							empty = false;
						}
						
						if (!recreate && input.text != model.getCellValue(y, x)) {
							if (!created && y == rows) {
								addRow(model);
								created = true;
							}
							model.onCellChanged(y, x, input.text);
						}
						
						if (input.hasFocus) {
							focused = vec2i(x, y);
						}
					}
				}];
				
				if (y < rows && empty) {
					emptyRow = y;
				}
			}
			
			if (emptyRow != -1) {
				removeRow(model, emptyRow);
			}
		}];

		if (shouldSetFocus) {
			setFocus();
		}

		// store the 'previous state'
		prevState.rows = cells.length;
		if (cells.length > 0) {
			prevState.columns = cells[0].length;
			for (int y = 0; y < prevState.rows; ++y) {
				for (int x = 0; x < prevState.columns; ++x) {
					auto cell = cells[y][x];
					prevState[y, x] = cell is null ? null : cell.text;
				}
			}
		}
	}


	mixin MWidget;
}
