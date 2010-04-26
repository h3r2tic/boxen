module Dynamic2;

private {
	import xf.hybrid.Hybrid;
	import xf.hybrid.backend.GL;
	import xf.hybrid.WidgetFactory;
	import xf.hybrid.Property;

	// for Thread.yield
	import tango.core.Thread;
}



void main() {
	version (DontMountExtra) {} else gui.vfsMountDir(`../../`);
	scope cfg = loadHybridConfig(`./Dynamic2.cfg`);
	scope renderer = new Renderer;
	
	char[][] widgetsToUse = [
		"Button", "Check", "Label", "Combo", "Input",
		"InputArea", "Progressbar", "FloatInputSpinner"
	];
		
	IWidget[char[]] createdWidgets;
	
	gui.begin(cfg);
		foreach (name; widgetsToUse) {
			createdWidgets[name] = createWidget(name)
			.layoutAttribs("hexpand vexpand hfill vfill");
		}
	gui.end();
	
	char[] previousSelection;

	bool programRunning = true;
	while (programRunning) {
		gui.begin(cfg);
			if (gui().getProperty!(bool)("main.frame.closeClicked")) {
				programRunning = false;
			}
			
			auto dynWidgetParent = Group(`main.dynamicWidget`);
			
			VBox(`main.controls`) [{
				auto combo = Combo();
				if (0 == combo.items.length) {
					foreach (w; widgetsToUse) {
						combo.addItem(w);
					}
				}
				
				bool autoUpdate = Check().text(`Auto update`).checked;
				
				auto sel = combo.selected();
				bool selectionChanged = previousSelection != sel;
				previousSelection = sel;
				
				if (auto w = sel in createdWidgets) {
					dynWidgetParent.addChild(*w);
					
					int i = 0;
					foreach (prop; &w.iterExportedProperties) {
						if (prop.readOnly) {
							continue;
						}
						
						HBox(i++).cfg(`layout = { spacing = 5; }`) [{
							Label().text(prop.name).halign(2)
							.layoutAttribs(`vexpand`).userSize = vec2(75, 0);
							
							if (prop.type is typeid(char[])) {
								mixin(
								valueUpdateCode(`Input`, `char[]`, `text`));
							}
							else if (prop.type is typeid(int)) {
								mixin(
								valueUpdateCode(`IntInputSpinner`, `int`, `value`));
							}
							else if (prop.type is typeid(float)) {
								mixin(
								valueUpdateCode(`FloatInputSpinner`, `float`, `value`));
							}
							else if (prop.type is typeid(bool)) {
								mixin(
								valueUpdateCode(`Check`, `bool`, `checked`));
							}
							else {
								Label().text("... not supported ...")
									.fontSize(10).halign(2).valign(1)
									.layoutAttribs(`hexpand vexpand`);
							}
						}];
					}
				}
			}];
		gui.end();
		gui.render(renderer);
		Thread.yield();
	}
}


char[] valueUpdateCode(char[] widget, char[] type, char[] field) {
		return 
			`auto editField = `~ widget ~`();
			editField.layoutAttribs("hexpand hfill vexpand");`
			
			~ type ~` val = editField.`~ field ~`;

			`~ type ~` backup = void;
			bool backupValid = false;
			try {
				backup = getProperty!(`~ type ~`)(*w, prop.name);
				backupValid = true;
			} catch {}

			if (backupValid &&
				(selectionChanged || (!autoUpdate && Button().text("get").clicked)))
			{
				try {
					editField.`~ field ~` = backup;
				} catch {}
			}

			if ((autoUpdate && backupValid) || Button().text("set").clicked) {
				try {
					setProperty(*w, prop.name, val);
				} catch {
					if (backupValid) {
						setProperty(*w, prop.name, backup);
					}
				}
			}
		`;		
}
