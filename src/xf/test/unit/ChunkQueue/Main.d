module Main;

import tango.io.Stdout;
import tango.core.Thread;

import xf.mem.ChunkQueue;
import xf.utils.GlobalThreadDataRegistry;

private {
	__thread ChunkQueue!(double)								queue;
	mixin GlobalThreadDataRegistryM!(typeof(queue)*)	QueueRegistry;
}

void main() {
	(new Thread({
		QueueRegistry.register(&queue);
		queue.pushBack(1.0);
		queue.pushBack(2.0);
		Thread.sleep(1);
		Stdout.formatln("exiting");
		Stdout.flush();
	})).start;
	
	(new Thread({
		QueueRegistry.register(&queue);
		queue.pushBack(3.0);
		queue.pushBack(4.0);
		Thread.sleep(1.1);
		Stdout.formatln("exiting");
		Stdout.flush();
	})).start;
	
	Thread.sleep(0.2);
	
	Stdout.formatln("ohai");
	Stdout.flush();

	QueueRegistry.register(&queue);
	queue.pushBack(5.0);
	queue.pushBack(6.0);
	
	foreach (thi, thq; QueueRegistry.each) {
		Stdout.formatln("items for thread {}", thi);
		Stdout.flush();
		foreach (i, x; *thq) {
			Stdout.formatln("item {}: {}", i, x);
			Stdout.flush();
		}
		(*thq).clear();
	}
	
	QueueRegistry.clearRegistrations();
	
	thread_joinAll();
}
