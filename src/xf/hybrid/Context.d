module xf.hybrid.Context;

private {
	import xf.hybrid.model.Core;
	import xf.hybrid.WidgetFactory;
	import xf.hybrid.GuiRenderer;
	import xf.hybrid.Misc : _defChildSlotName, WidgetId;
	import xf.hybrid.Event;
	import xf.hybrid.Property;
	import xf.hybrid.WidgetConfig;
	import xf.hybrid.WidgetTree;
	import xf.hybrid.HybridException;
	import xf.hybrid.Rect;
	
	import xf.hybrid.Math;
	import xf.input.Input;
	import xf.utils.Memory : preallocatedAppend;
	import xf.utils.LocalArray;
	import xf.mem.StackBuffer;
	
	import tango.text.convert.Format;
	import tango.time.StopWatch : StopWatch;
	import tango.core.Traits : ParameterTupleOf, ReturnTypeOf;
	import tango.util.log.Trace;
	
	import tango.io.vfs.model.Vfs;
	import tango.io.vfs.LinkedFolder;
	import tango.io.vfs.FileFolder;

	import tango.stdc.stdlib : alloca;

	static import tango.core.Array;
}




bool iterWidgets(IWidget w, bool delegate(IWidget w, void delegate() recurse) dg) {
	assert (w !is null);
	
	bool r1 = true;
	bool r2 = dg(w, {
		int numChildren = 0;
		foreach (ref c; &w.children) {
			++numChildren;
		}
		
		IWidget[] children = (cast(IWidget*)alloca(numChildren * IWidget.sizeof))[0 .. numChildren];
		foreach (ref c; &w.children) {
			children[--numChildren] = c;
		}
		
		foreach (c; children) {
			if (!iterWidgets(c, dg)) {
				r1 = false;
				break;
			}
		}

		/+foreach_reverse (ref c; &w.children) {
			if (auto r = iterAll(c, dg)) return r;
		}+/

		/+foreach (ch; &root.children) {
			if (!iterWidgets(ch, dg)) {
				r1 = false;
				break;
			}
		}+/
	});
	
	return r1 & r2;
}



struct WidgetChain {
	IWidget[] widgets;
	
	void reset() {
		widgets.length = 0;
	}
	
	void add(IWidget w) {
		widgets ~= w;
	}
	
	void copyFrom(ref WidgetChain ch) {
		widgets.length = ch.widgets.length;
		widgets[] = ch.widgets[];
	}
	
	char[] toString() {
		char[] res;
		foreach (i, w; widgets) {
			if (i > 0) {
				res ~= " ";
			}
			res ~= (cast(Object)w).classinfo.name;
		}
		return res;
	}
}


/**
	Global context holder for the IMGUI backend. Access it through 'gui.' or 'gui().'
*/
class GuiContext {
	protected void _loadConfig() {
		this.wtree = buildWidgetTree(cfg);
	}
	
	
	/**
		Marks the beginning of a GUI code section. Except binding to the specified config, it also does cleanup
		and processes inputs from the inputChannel.
	*/
	typeof(this) begin(Config cfg) {
		assert (cfg !is null);

		inputChannel.dispatchAll();
		
		if (this.cfg !is cfg) {
			this.cfg = cfg;
			_loadConfig();
		} else {
			this.wtree.clearTemp();
		}
		
		lastWTreeNode = wtree;
		
		
		if (this.stopWatch is null) {
			(this.stopWatch = new StopWatch).start();
		}
		
		return this;
	}
	
	
	/**
		GUI structure finalization, layout, time update
	*/
	typeof(this) end() {
		doPopups();
		
		if (wtree !is null) {
			//Stdout.newline()(wtree.toString()).newline.newline;
			buildGuiStructure();
			/+foreach (ch; wtree.children) {
				Stdout((cast(Object)ch.widget).toString).newline;
			}+/
		}
		
		notifyWidgetsGuiStructureBuilt();
		
		doLayout();
		updateWidgetTime();

		assert (curChildSlot is null);
		return this;
	}
	
	
	protected void notifyWidgetsGuiStructureBuilt() {
		foreach (root; &iterRootWidgets) {
			foreach (w; iterBottomTop(root)) {
				w.onGuiStructureBuilt();
			}
		}
	}
	
	
	protected void updateWidgetTime() {
		scope tu = new TimeUpdateEvent(stopWatch.stop);
		stopWatch.start();
		pushEvent(tu);
	}
	
	
	protected int iterRootWidgets(int delegate(ref IWidget w) dg) {
		if (wtree !is null) {
			foreach (ref ch; wtree.children) {
				if (ch.widget !is null) {
					IWidget widget = ch.widget;
					if (auto res = dg(widget)) {
						return res;
					}
				}
			}
		}
		return 0;
	}
	
	
	protected void pushEvent(Event e) {
		foreach (w; &iterRootWidgets) {
			w.treeHandleEvent(e);
		}
	}
	
	
	protected void doLayout() {
		scope min	= new MinimizeLayoutEvent;
		scope exp	= new ExpandLayoutEvent;
		scope off	= new CalcOffsetsEvent;
		
		pushEvent(min);
		pushEvent(exp);
		pushEvent(off);
	}


	/**
		Add a child widget to the 'overlay' slot
	*/
	void addOverlay(IWidget w) {
		assert (w !is null);
		auto o = wtree.locate(`overlay`);
		assert (o !is null, "no overlay component");
		assert (o.widget !is null, "overlay widget is null");
		o.widget.addChild(w);
	}
	
	
	private bool sepWidgetPropName(char[] name, char[]* w, char[]* p) {
		for (int i = name.length - 1; i >= 0; --i) {
			if ('.' == name[i]) {
				*w = name[0..i];
				*p = name[i+1..$];
				return true;
			}
		}
		return false;
	}


	public void setProperty(T)(char[] name, T val) {
		char[] w, p;
		char[256] buf;
		name = fqn(name, buf);
		if (!sepWidgetPropName(name, &w, &p)) {
			throw new Exception("'" ~ name ~ "' is not a valid property");
		}
		
		auto widget = wtree.locateWidget(w);
		if (widget is null) {
			hybridThrow("getProperty: could not locate widget '{}'", w);
		}
		return .xf.hybrid.Property.setProperty!(T)(widget, p, val);
	}


	public T getProperty(T)(char[] name) {
		char[] w, p;
		char[256] buf;
		name = fqn(name, buf);
		if (!sepWidgetPropName(name, &w, &p)) {
			throw new Exception("'" ~ name ~ "' is not a valid property");
		}
		
		auto widget = wtree.locateWidget(w);
		if (widget is null) {
			hybridThrow("getProperty: could not locate widget '{}'", w);
		}
		return .xf.hybrid.Property.getProperty!(T)(widget, p);
	}

	
	/**
		Adds a name to the name stack
	*/
	typeof(this) push(char[] name) {
		nameStack ~= curName.length;
		if (curName.length > 0) {
			curName ~= '.';
			curName ~= name;
		} else {
			curName ~= name;
		}
		return this;
	}
	
	
	/**
		Removes a name from the name stack
	*/
	typeof(this) pop() {
		curName = curName[0..nameStack[$-1]];
		nameStack = nameStack[0 .. $-1];
		return this;
	}
	
	
	/**
		Returns the fully qualified name of the argument using the name stack
	*/
	char[] fqn(char[] name, char[] buffer) {
		assert (name.length > 0);
		if ('.' == name[0]) {
			return name[1..$];
		} else {
			char[] res;
			// HACK
			if (curName.length > 0) {
				res.preallocatedAppend(buffer, curName, ".", name);
			} else {
				res.preallocatedAppend(buffer, name);
			}
			return res;
		}
	}
	
	
	/**
		Render the GUI using the provided renderer
	*/
	void render(GuiRenderer renderer, Rect rect = Rect.init) {
		renderer.resetClipping();
		renderer.setClipRect(rect);

		scope render = new RenderEvent;
		render.renderer = renderer;
		pushEvent(render);
	}
	
	
	IWidget delegate() parentOverride;
	IWidget delegate()[] prevParentOverrides;
	
	
	/**
		Instantiates and returns a widget of the specified type, name and id. Used internally in static opCall of wigdets
	*/
	T getWidget(T)(char[] name, WidgetId id) {
		WidgetTree node = null;
		
		if (name !is null) {
			char[256] buf;
			node = wtree.locate(fqn(name, buf));
		} else {
			assert (lastWTreeNode !is null);
			
			if (lastWTreeNode.parent is null || curChildSlot !is null) {	// root or adding a child
				if (openWTreeNodes.length > 0) {
					node = openWTreeNodes[$-1].locate(id);
				} else {
					node = lastWTreeNode.locate(id);
				}
			} else {
				node = lastWTreeNode.parent.locate(id);
			}
		}

		assert (node !is null);
		lastWTreeNode = node;
		
		if (addRetained) {
			if (node.retained) {
				auto w = node.widget;
				auto wo = cast(Object)w;
				assert (wo !is null);
				auto res = cast(T)wo;
				assert (res !is null || wo.classinfo is T.classinfo, Format("{} vs {}", wo.classinfo.name, T.classinfo.name));
				return res;
			}
			
			//assert (!node.retained, "adding a retained widget again?");
			node.retained = true;
		}
		
		node.enabled = true;
		auto w = node.widget;
		auto res = cast(T)w;
		
		if (w !is null) {
			auto wo = cast(Object)w;
			assert (wo !is null);
			assert (res !is null || wo.classinfo is T.classinfo, Format("{} vs {}", wo.classinfo.name, T.classinfo.name));
		} else {
			w = createWidget(T.staticWidgetTypeName);
			res = cast(T)w;
			node.widget = w;
		}
		
		if (!parentOverride) {
			// named widgets already have parents in the widget tree
			if (0 == name.length) {
				if (auto cs = curChildSlot) {
					assert (!w.hasParent, "adding a widget again? " ~ (cast(Object)w).classinfo.name ~ " " ~ name);
					cs.addChild(w);
					node.slot = curSlotName;
				}
			}
		} else {
			assert (!w.hasParent, "adding a widget again? " ~ (cast(Object)w).classinfo.name ~ " " ~ name);
			parentOverride().addChild(w);
			node.slot = curSlotName;
		}

		res.wtreeNode = node;
		return res;
	}
	

	typeof(this) open(WidgetTree wtreeNode, char[] slot = null) {
		openWTreeNodes ~= lastWTreeNode;
		openChildSlots ~= lastWTreeNode.widget._open(slot);
		openSlotNames ~= slot;
		prevParentOverrides ~= parentOverride;
		parentOverride = null;
		return this;
	}

	
	/**
		Opens a child slot within the last added widget. If 'slot' is null, the default child slot is opened
	*/
	typeof(this) open(char[] slot = null) {
		return open(lastWTreeNode, slot);
	}
	
	
	/**
		Returns the slot used for overlay widgets
	*/
	IWidget getOverlayWidget() {
		auto o = wtree.locate(`overlay`);
		assert (o !is null, "no overlay component");
		assert (o.widget !is null, "overlay widget is null");
		return o.widget;
	}
	
	
	/**
		Opens the child slot of the overlay widget
	*/
	typeof(this) openOverlay() {
		auto o = wtree.locate(`overlay`);
		assert (o !is null, "no overlay component");
		assert (o.widget !is null, "overlay widget is null");
		openWTreeNodes ~= o;
		openChildSlots ~= o.widget._open(null);
		openSlotNames ~= null;
		prevParentOverrides ~= parentOverride;
		parentOverride = null;
		return this;
	}
	
	
	/**
		Closes the currently open child slot
	*/
	typeof(this) close() {
		lastWTreeNode = openWTreeNodes[$-1];
		openWTreeNodes = openWTreeNodes[0..$-1];
		openChildSlots = openChildSlots[0..$-1];
		openSlotNames = openSlotNames[0..$-1];
		parentOverride = prevParentOverrides[$-1];
		prevParentOverrides = prevParentOverrides[0..$-1];
		return this;
	}
	
	
	/**
		Switches the API into retained mode
	*/
	typeof(this) retained() {
		addRetained = true;
		return this;
	}
	
	
	/**
		Switches the API into immediate mode
	*/
	typeof(this) immediate() {
		addRetained = false;
		return this;
	}
	
	
	protected void buildGuiStructure() {
		void iter(WidgetTree wt, IWidget parent) {
			auto w = wt.widget;

			if (parent !is null && wt.enabled && w !is null && !w.hasParent) {
				auto slot = parent._open(wt.slot.length > 0 ? wt.slot : null);
				slot.addChild(w);
			}
			
			if (wt.enabled && wt.children.length > 0) {
				foreach (ch; wt.children) {
					iter(ch, w);
				}
			}
		}
		
		iter(wtree, null);
	}
	
	
	// TODO: optimize
	/**
		Return the specification of the widget type given in the 'type' argument
	*/
	WidgetTypeSpec getWigdetTypeSpec(char[] type) {
		foreach (ts; cfg.widgetTypeSpecs) {
			if (ts.name == type) {
				return ts;
			}
		}
		
		throw new Exception("Custom widget '" ~ type ~ "' not defined in the config");
	}
	
	
	private {
		int[]		nameStack;
		char[]	curName;
		
		GuiContext	parent;
		Config			cfg;
		WidgetTree	wtree;
		char[][]			openSlotNames;
		WidgetTree[]	openWTreeNodes;
		bool				addRetained;

		OpenWidgetProxy[]	openChildSlots;
		
		OpenWidgetProxy*		curChildSlot() {
			if (openChildSlots.length > 0) {
				return &openChildSlots[$-1];
			} else {
				return null;
			}
		}
		
		char[] curSlotName() {
			return openSlotNames[$-1];
		}
		
		WidgetTree	lastWTreeNode;
		WidgetTree[]	lastWTreeNodeStack;
		
		StopWatch*	stopWatch;
	}
	

	// ------------------------------------------------------------------------------------
	// Global event handling


	protected {
		bool delegate(Event)[][ClassInfo] globalEventHandlers;
	}
	

	/**
		Add an event handler globally. It will always be called, ignoring any parent-child blocking.
		The event handler should not return EventHandling, but bool. A 'true' return value will indicate
		that the event was handled and the handler can be removed. False will mean that the handler should
		not be removed fro mthe global handlers list.
	*/
	void addGlobalHandler(T)(T h) {
		alias ParameterTupleOf!(T)[0] EventT;
		globalEventHandlers[EventT.classinfo] ~= cast(ReturnTypeOf!(T) delegate(Event))h;
	}


	/**
		Fire global handlers upon the specified event
	*/
	void handleGlobalEvent(Event e) {
		for (auto ci = e.classinfo; ci !is Object.classinfo; ci = ci.base) {
			auto handlers_ = ci in globalEventHandlers;
			if (handlers_ !is null) {
				bool delegate(Event)[] newHandlers;
				
				auto handlers = *handlers_;
				globalEventHandlers.remove(ci);
				
				foreach (h; handlers) {
					if (!h(e)) {
						newHandlers ~= h;
					}
				}
				
				delete handlers;
				if (newHandlers.length > 0) {
					if (auto extHandlers = ci in globalEventHandlers) {
						*extHandlers ~= newHandlers;
					} else {
						globalEventHandlers[ci] = newHandlers;
					}
				}
			}
		}
	}
	
	// ------------------------------------------------------------------------------------
	// Input handling
	
	
	/**
		Takes keyboard focus away from the currently focused wigdet and gives it to the one specified in this function.
	*/
	void giveKeyboardFocus(IWidget w) {
		assert (w !is null);
		
		prevChains.keyboardFocus.copyFrom(curChains.keyboardFocus);
		auto chain = &curChains.keyboardFocus;
		chain.reset();
		
		do {
			chain.add(w);
			w = w.parent;
		} while (w !is null);
		
		resolveKeyboardFocusChanges();
	}
	
	
	protected {
		void findWidgetChainAtPoint(vec2 pt, ref WidgetChain ch) {
			ch.reset();
			
			foreach (root; &iterRootWidgets) {
				bool cont = true;
				
				foreach (w; iterBottomTop(root).filter((IWidget w) {
					return w.containsGlobal(pt);
				})) {
					cont = false;
					ch.add(w);
				}
				
				if (!cont) break;
			}
		}
	}
	
	
	protected void resolveKeyboardFocusChanges() {
		auto cur = &curChains.keyboardFocus;
		auto prev = &prevChains.keyboardFocus;
		
		int maxL = max(prev.widgets.length, cur.widgets.length);
		
		for (int i = 0; i < maxL; ++i) {
			auto w = i < prev.widgets.length ? prev.widgets[i] : null;
			auto w2 = i < cur.widgets.length ? cur.widgets[i] : null;
			
			if (w !is w2) {
				{
					scope evt = new LoseFocusEvent;
					for (int j = i; j < prev.widgets.length; ++j) {
						if (EventHandling.Stop == prev.widgets[j].handleEvent(evt)) {
							break;
						}
					}
				}
				{
					scope evt = new GainFocusEvent;
					for (int j = i; j < cur.widgets.length; ++j) {
						if (EventHandling.Stop == cur.widgets[j].handleEvent(evt)) {
							break;
						}
					}
				}
				return;
			}
		}
	}


	class GuiInputReader : InputReader {
		MouseButton buttonFromIdx(int i) {
			assert (i >= 0 && (1 << i) <= MouseButton.max);
			return cast(MouseButton)(1 << i);
		}
		
		vec2 mousePos = vec2.zero;
		
		
		void key(KeyboardInput* input) {
			{
				scope evt = new KeyboardEvent;
				evt.keySym = input.keySym;
				evt.down = KeyboardInput.Type.Down == input.type;
				evt.unicode = input.unicode;
				evt.modifiers = input.modifiers;
				handleGlobalEvent(evt);
			}

			//Trace.formatln("got a key event. current focus: {}", curChains.keyboardFocus);
			auto chain = curChains.keyboardFocus.widgets;

			if (chain.length > 0) {
				scope evt = new KeyboardEvent;
				evt.keySym = input.keySym;
				evt.down = KeyboardInput.Type.Down == input.type;
				evt.unicode = input.unicode;
				evt.modifiers = input.modifiers;
				
				int stoppedAt = chain.length;
				foreach (i, w; chain) {
					evt.sinking = true;
					if (EventHandling.Stop == w.handleEvent(evt)) {
						evt.handled = true;
						stoppedAt = i;
						break;
					}
				}

				foreach_reverse (w; chain[0 .. stoppedAt]) {
					evt.bubbling = true;
					w.handleEvent(evt);
				}
			}
		}
		
		
		void handleMouseMove(vec2 pos, vec2 delta, vec2 global) {
			scope stack = new StackBuffer;
			final widgets_ = LocalDynArray!(IWidget)(stack);
			scope (exit) widgets_.dispose();

			widgets_.append(prevChains.mouseOver.widgets);
			widgets_.append(curChains.mouseOver.widgets);
			for (int i = 0; i < numMouseButtons; ++i) {
				widgets_.append(prevChains.mouseButton[i].widgets);
				widgets_.append(curChains.mouseButton[i].widgets);
			}

			IWidget[] widgets = widgets_.data();
			
			auto cmp = function bool(IWidget a, IWidget b) {
				return cast(size_t)cast(void*)a < cast(size_t)cast(void*)b;
			};
			
			tango.core.Array.sort(widgets, cmp);
			
			scope evt = new MouseMoveEvent;
			evt.delta = delta;
			evt.rootPos = global;
			evt.sinking = true;
			
			IWidget prevW = null;
			foreach (w; widgets) {
				if (w is prevW) continue;
				prevW = w;
				vec2 off = w.globalOffset;
				evt.pos = pos - off;
				w.handleEvent(evt);
			}
		}


		void mouse(MouseInput* i) {
			switch (i.type) {
				case MouseInput.Type.Move: {
					this.mousePos = vec2.from(i.position);
					this.outer._mousePos = mousePos;
					
					findWidgetChainAtPoint(mousePos, curChains.mouseOver);
					//Stdout.formatln("at cursor: [{}]", curChains.mouseOver);
					
					void detectEnterLeave(ref WidgetChain prev, ref WidgetChain cur) {
						{
							scope evt = new MouseLeaveEvent;
							leaveIter: foreach (pw; prev.widgets) {
								foreach (cw; cur.widgets) {
									if (cw is pw) {
										continue leaveIter;
									}
								}
								
								if (EventHandling.Stop == pw.handleEvent(evt)) {
									break;
								}
							}
						}

						{
							scope evt = new MouseEnterEvent;
							enterIter: foreach (cw; cur.widgets) {
								foreach (pw; prev.widgets) {
									if (cw is pw) {
										if (cw.blockEventProcessing(evt)) {
											break enterIter;
										}
										continue enterIter;
									}
								}
								
								if (EventHandling.Stop == cw.handleEvent(evt) || cw.blockEventProcessing(evt)) {
									break;
								}
							}
						}
					}
					
					detectEnterLeave(prevChains.mouseOver, curChains.mouseOver);
					
					handleMouseMove(vec2.from(i.position), vec2.from(i.move), vec2.from(i.global));
				} break;
				
				case MouseInput.Type.ButtonDown: {
					void doButtonDown(MouseInput.Button btn, int idx) {
						{
							scope evt = new MouseButtonEvent;
							evt.button = btn;
							evt.down = true;
							evt.pos = mousePos;
							handleGlobalEvent(evt);
						}

						scope evt = new MouseButtonEvent;
						evt.button = btn;
						evt.down = true;
						
						if (i.buttons & btn) {
							findWidgetChainAtPoint(mousePos, curChains.mouseButton[idx]);
							
							if (0 == idx) {
								prevChains.keyboardFocus.copyFrom(curChains.keyboardFocus);
								curChains.keyboardFocus.copyFrom(curChains.mouseButton[idx]);
								resolveKeyboardFocusChanges();
							}
							
							// TODO: consider this as the correct event propagation code for mouse
							foreach (root; &iterRootWidgets) {
								iterWidgets(root, (IWidget w, void delegate() recurse) {
									if (!w.containsGlobal(mousePos)) {
										return true;
									}
									
									evt.sinking = true;
									evt.pos = mousePos - w.globalOffset;
									if (EventHandling.Stop == w.handleEvent(evt)) {
										evt.handled = true;
										return false;
									}
									
									recurse();

									evt.bubbling = true;
									evt.pos = mousePos - w.globalOffset;
									if (EventHandling.Stop == w.handleEvent(evt)) {
										evt.handled = true;
										return false;
									} else {
										return true;
									}
								});
							}
							
							/+int last = 0;
							Trace.formatln("button {} down at: [{}]", idx, curChains.mouseButton[idx]);
							foreach (w; curChains.mouseButton[idx].widgets) {
								Trace.formatln("sinking at {}", (cast(Object)w).classinfo.name);
								++last;
								evt.pos = mousePos - w.globalOffset;
								evt.sinking = true;
								if (EventHandling.Stop == w.handleEvent(evt)) {
									evt.handled = true;
									break;
								}
							}
							
							foreach_reverse (w; curChains.mouseButton[idx].widgets[0..last]) {
								Trace.formatln("bubbling at {}", (cast(Object)w).classinfo.name);
								evt.pos = mousePos - w.globalOffset;
								evt.sinking = false;
								if (EventHandling.Stop == w.handleEvent(evt)) {
									evt.handled = true;
								}
							}+/
						}
					}
					for (int b = 0; b < numMouseButtons; ++b) {
						doButtonDown(buttonFromIdx(b), b);
					}
				} break;
				
				case MouseInput.Type.ButtonUp: {
					void detectClicks(int idx, ref WidgetChain prev, ref WidgetChain cur) {
						//Stdout.formatln("Checking clicks for chains of length {} and {}", prev.widgets.length, cur.widgets.length);
						
						int from = 0;
						int to = 0;
						
						foreach (i, ref w; prev.widgets) {
							auto w2 = i < cur.widgets.length ? cur.widgets[i] : null;
							if (w is w2) {
								to = i+1;
							} else {
								break;
							}
						}
						
						{
							scope evt = new ClickEvent;
							evt.button = buttonFromIdx(idx);
							evt.pos = mousePos;
							handleGlobalEvent(evt);
						}

						scope evt = new ClickEvent;
						evt.button = buttonFromIdx(idx);

						foreach (i, w; prev.widgets[from..to]) {
							evt.sinking = true;
							evt.pos = mousePos - w.globalOffset;
							if (EventHandling.Stop == w.handleEvent(evt)) {
								evt.handled = true;
								to = i;
								break;
							}
						}

						foreach_reverse (w; prev.widgets[from..to]) {
							evt.bubbling = true;
							evt.pos = mousePos - w.globalOffset;
							if (EventHandling.Stop == w.handleEvent(evt)) {
								evt.handled = true;
							}
						}
					}
					
					void doButtonUp(MouseInput.Button btn, int idx) {
						{
							scope evt = new MouseButtonEvent;
							evt.button = btn;
							evt.down = false;
							evt.pos = mousePos;
							handleGlobalEvent(evt);
						}

						scope evt = new MouseButtonEvent;
						evt.button = btn;
						evt.down = false;

						if (i.buttons & btn) {
							findWidgetChainAtPoint(mousePos, curChains.mouseButton[idx]);
							//Stdout.formatln("button {} up at: [{}]", idx, curChains.mouseButton[idx]);

							/+foreach (w; curChains.mouseButton[idx].widgets) {
								evt.pos = mousePos - w.globalOffset;
								if (EventHandling.Stop == w.handleEvent(evt)) {
									evt.handled = true;
									break;
								}
							}+/
							
							int last = 0;

							foreach (w; curChains.mouseButton[idx].widgets) {
								++last;
								evt.pos = mousePos - w.globalOffset;
								evt.sinking = true;
								if (EventHandling.Stop == w.handleEvent(evt)) {
									evt.handled = true;
									break;
								}
							}
							
							foreach_reverse (w; curChains.mouseButton[idx].widgets[0..last]) {
								evt.pos = mousePos - w.globalOffset;
								evt.sinking = false;
								if (EventHandling.Stop == w.handleEvent(evt)) {
									evt.handled = true;
								}
							}

							detectClicks(idx, prevChains.mouseButton[idx], curChains.mouseButton[idx]);
						}
						
						curChains.mouseButton[idx].reset();
					}
					
					for (int b = 0; b < numMouseButtons; ++b) {
						doButtonUp(buttonFromIdx(b), b);
					}
				} break;

				default: break;
			}


			switch (i.type) {
				case MouseInput.Type.Move: {
					prevChains.mouseOver.copyFrom(curChains.mouseOver);
					curChains.mouseOver.reset();
				} break;
				
				case MouseInput.Type.ButtonUp: {
				} break;
				
				case MouseInput.Type.ButtonDown: {
					void doButtonReset(MouseInput.Button btn, int idx) {
						if (i.buttons & btn) {
							prevChains.mouseButton[idx].copyFrom(curChains.mouseButton[idx]);
							curChains.mouseButton[idx].reset();
						}
					}

					for (int b = 0; b < numMouseButtons; ++b) {
						doButtonReset(buttonFromIdx(b), b);
					}
				} break;

				default: assert (false);
			}
		}
		
		
		this() {
			registerReader!(KeyboardInput)(&this.key);
			registerReader!(MouseInput)(&this.mouse);
		}
	}
	
	
	/**
		Returns the input channel used for giving inputs to the GUI
	*/
	InputChannel inputChannel() {
		if (_inputChannel is null) {
			_inputChannel = new InputChannel;
			_inputChannel.addReader(_inputReader = new GuiInputReader);
		}
		return _inputChannel;
	}


	void overrideInputChannel(InputChannel ch) {
		_inputChannel = ch;
		_inputChannel.addReader(_inputReader = new GuiInputReader);
	}
	
	
	vec2 mousePos() {
		return _mousePos;
	}
	
		
	private {
		const int numMouseButtons = 7;

		struct Chains {
			WidgetChain[numMouseButtons]	mouseButton;
			WidgetChain						mouseOver;
			WidgetChain						keyboardFocus;
		}
		
		Chains	prevChains;
		Chains	curChains;
		
		GuiInputReader		_inputReader;
		InputChannel		_inputChannel;
		
		vec2				_mousePos;
	}
	


	// ------------------------------------------------------------------------------------
	// Context menus


	template popup(Container) {
		PopupProxy!(Container, T) popup(T ...)(T t) {
			return PopupProxy!(Container, T)(this, t, mousePos);
		}
	}
	
	
	private {
		bool delegate(int)[] popups;
		
		
		void doPopups() {
			int dst = 0;
			for (int src = 0; src < popups.length; ++src) {
				if (popups[src](src)) {
					popups[dst++] = popups[src];
				}
			}
			popups = popups[0..dst];
		}
		
		
		struct PopupProxyCommand(Container, T ...) {
			GuiContext gui;
			T args;
			bool delegate(T) dg;
			vec2 pos;

			bool run(int i) {
				gui.openOverlay;
				scope (exit) gui.close;
				auto box = Container(i);
				box.parentOffset = pos;
				box.globalOffset = pos;
				box.open;
				scope (exit) gui.close;
				return dg(args);
			}
		}

		struct PopupProxy(Container, T ...) {
			GuiContext gui;
			T args;
			vec2 pos;
			
			void opAssign(bool delegate(T) dg) {
				auto cmd = new PopupProxyCommand!(Container, T);
				cmd.gui = this.gui;
				cmd.args = this.args;
				cmd.dg = dg;
				cmd.pos = this.pos;
				gui.popups ~= &cmd.run;
			}
		}
	}
	
	// ------------------------------------------------------------------------------------
	// VFS
	
	/**
		Returns the VfsHost used for this GUI context. The default instance contains one mount dir, "."
	*/
	VfsHost vfs() {
		if (_vfsRoot is null) {
			resetVfs(".");
		}
		return _vfsRoot;
	}
	
	
	/**
		Resets the current VfsHost, removing any mounts; returns it
	*/
	VfsHost resetVfs() {
		if (_vfsRoot !is null) {
			delete _vfsRoot;
		}
		
		return _vfsRoot = new LinkedFolder("hybrid");
	}
	

	/**
		Resets the current VfsHost, mounts the [path] directory as FileFolder; returns the VfsHost
	*/
	VfsHost resetVfs(char[] path) {
		resetVfs();
		return vfsMountDir(path);
	}
	
	
	/**
		Mounts the [path] directory as FileFolder; returns the VfsHost
	*/
	VfsHost vfsMountDir(char[] path) {
		return vfs.mount(new FileFolder(path));
	}

	
	private {
		VfsHost _vfsRoot;
	}
}



/**
	Returns the current GUI context. Not thread-safe at the moment.
*/
GuiContext gui() {
	if (_guiContext is null) {
		_guiContext = new GuiContext;
	}
	return _guiContext;
}
private GuiContext _guiContext;		// TODO: TLS
