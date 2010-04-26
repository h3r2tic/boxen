module xf.hybrid.Misc;

private {
	import tango.util.Convert : to;
}


///
struct WidgetId {
	size_t	ret, cur;
	size_t	user;
	
	char[] toString() {
		return to!(char[])(ret) ~ ":" ~ to!(char[])(cur) ~ "," ~ to!(char[])(user);
	}
}


///
typedef size_t GuiId = NoId;

///
const GuiId	NoId			= cast(GuiId)-1;
const GuiId	AutoId		= cast(GuiId)-2;


const char[]	_defChildSlotName = null;


version (X86_64) {
const char[] widgetIdCalcSM = `
	WidgetId widgetId;
	{
		size_t retAddr = void;
		size_t curAddr = void;
		asm {
			movq RDX, RSP; movq RSP, RBP; popq RBP; popq RAX;
			pushq RAX; pushq RBP; movq RBP, RSP; movq RSP, RDX;
			movq retAddr, RAX;
			
			call GIMMEH_EIP;
			GIMMEH_EIP: popq RDX; movq curAddr, RDX;
		}
		/+if (NoId == id) {
			id = cast(GuiId)retAddr;
		}+/
		widgetId.ret = retAddr;
		widgetId.cur = curAddr;
	}
`;
} else {
const char[] widgetIdCalcSM = `
	WidgetId widgetId;
	{
		size_t retAddr = void;
		size_t curAddr = void;
		asm {
			mov EDX, ESP; mov ESP, EBP; pop EBP; pop EAX;
			push EAX; push EBP; mov EBP, ESP; mov ESP, EDX;
			mov retAddr, EAX;
			
			call GIMMEH_EIP;
			GIMMEH_EIP: pop EDX; mov curAddr, EDX;
		}
		/+if (NoId == id) {
			id = cast(GuiId)retAddr;
		}+/
		widgetId.ret = retAddr;
		widgetId.cur = curAddr;
	}
`;
}
