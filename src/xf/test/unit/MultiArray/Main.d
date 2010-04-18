module Main;

private {
	import xf.mem.MultiArray;
}


struct Foo {
	mixin(multiArray(`zomg`, `
		int		a
		float	b
	`));
}


void main() {
}
