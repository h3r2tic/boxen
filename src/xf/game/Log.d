module xf.game.Log;

private {
	import xf.utils.Log;
	import xf.utils.Error;
}


mixin(createLoggerMixin("gameLog"));
mixin(createErrorMixin("GameException", "gameError"));
