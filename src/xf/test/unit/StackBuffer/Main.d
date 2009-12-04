module Main;

import tango.core.tools.TraceExceptions;
import xf.test.Common;

import xf.mem.StackBuffer;


void main() {
	int* addr1 = void;
	
	{
		scope buf = new StackBuffer;
		
		int* i1 = addr1 = buf.New!(int)(123);
		assertEqual(123, *i1);
	}

	{
		scope buf = new StackBuffer;
		
		int* i1 = buf.New!(int)(456);
		assertEqual(456, *i1);
		assertEqual(i1, addr1);
	}
}
