module Grid;

private {
	import GridInput;
	import xf.hybrid.Hybrid;
	import xf.hybrid.backend.GL;

	import tango.core.Thread;
	import tango.text.convert.Format;
	import tango.io.Stdout;
}



void main() {
	version (DontMountExtra) {} else gui.vfsMountDir(`../../`);
	scope cfg = loadHybridConfig(`./Grid.cfg`);
	scope renderer = new Renderer;


	int cols = 3;
	
	char[][][] gridData;
	bool resetStuff = false;

	bool programRunning = true;
	while (programRunning) {
		gui.begin(cfg);
			if (gui().getProperty!(bool)("main.frame.closeClicked")) {
				programRunning = false;
			}
			
			gui.push(`main`);
			VBox(`contents`) [{
				if (resetStuff) {
					gridData.length = 2;
					gridData[0] = ["11", "21", "31"];
					gridData[1] = ["12", "22", "32"];
					resetStuff = false;
				}
				
				DynamicGridInputModel model;
				model.onAddRow = {
					Stdout.formatln("onAddRow()");
					gridData ~= new char[][cols];
				};
				model.onRemoveRow = (int idx) {
					Stdout.formatln("onRemoveRow({})", idx);
					gridData = gridData[0..idx] ~ gridData[idx+1..$];
				};
				model.onCellChanged = (int row, int column, char[] val) {
					if ("lol" == val) {
						resetStuff = true;
					}
					Stdout.formatln("onCellChanged({}, {}, \"{}\")", row, column, val);
					gridData[row][column] = val.dup;
				};
				model.getNumRows = delegate int(){
					return gridData.length;
				};
				model.getNumColumns = {
					return cols;
				};
				model.getCellValue = (int row, int column) {
					if (row < gridData.length) {
						return gridData[row][column];
					} else {
						return cast(char[])null;
					}
				};
				DynamicGridInput().doGUI(false, model);
			}];
			gui.pop;
		gui.end;
		gui.render(renderer);
		Thread.yield;
	}
}
