module xf.hybrid.Selectable;



/**
	Exclusive-Or selector
	
	Example:
---
XorSelector grp;
DefaultOption = SomeXorSelectable.group(grp);
SomeXorSelectable.group(grp);
SomeXorSelectable.group(grp);
int selected = grp.index;
auto selectedObj = grp.sel;
---
*/
struct XorSelector {
	ulong			selTick__	= 0;
	short				indexCntr__ = 0;


	ISelectable	sel		= null;
	short				index	= 0;
}


/**
	An interface all selectables must implement. The basic implementation is provided by the MSelectable mixin template
*/
interface ISelectable {
	void	select(ulong tick);
	void	deselect();
	bool	initialized();
}


// HACK, TODO: make me thread-safe
ulong globalSelectionTickCntr = 0;



/**
	Provides an implementation for the ISelectable interface
*/
template MSelectable() {
	protected {
		bool	selectableGrouped = false;
		uint	selectedAtTick = 0;
	}
	
	
	bool select() {
		if (!selectableGrouped) return false;
		this.selectedAtTick = 0 == globalSelectionTickCntr ? (globalSelectionTickCntr += 2) : ++globalSelectionTickCntr;
		return true;
	}


	void select(ulong tick) {
		selectedAtTick = tick;
		
		static if (is(typeof(this.onSelected))) {
			this.onSelected();
		}
	}
	
	
	void deselect() {
		static if (is(typeof(this.onDeselected))) {
			this.onDeselected();
		}
	}
}


/**
	Provides grouping for selectables
*/
template MXorSelectable() {
	mixin MSelectable;
	
	/**
		Puts the selectable into a group of the provided XorSelector for the current frame
	*/
	typeof(this) group(inout XorSelector grp) {
		this.selectableGrouped = true;
		
		if (this.selectedAtTick >= grp.selTick__) {
			if (grp.sel !is null) {
				grp.sel.deselect();
			}
			
			grp.selTick__ = this.selectedAtTick;
			grp.sel = this;
			grp.index = grp.indexCntr__;
			this.select(this.selectedAtTick);
		} else {
			this.deselect();
		}

		++grp.indexCntr__;
		return this;
	}
}


struct DefaultOption__ {
	S opAssign(S)(S s) {
		if (!s.initialized) {
			s.select(1);
		}
		return s;
	}
}


/**
	When used with opAssign on some Selectable, will make it selected by default
	
	Works by calling .select on the selectable if .initialized returns false
*/
DefaultOption__ DefaultOption;
