package;

import haxe.Constraints.IMap;

class AssertUtils {
	public static function stringifyMap(map:IMap<Dynamic, Dynamic>) {
		var string = "[";
		var first = true;
		for (key => value in map) {
			string += first ? "" : ", ";
			first = false;
			string += key + " => " + value;
		}
		if (!first)
			string += "";
		return string + "]";
	}

	public static function objToString(obj:Dynamic) {
		var type = Type.typeof(obj);
		switch (type) {
			case TNull:
				return "null";
			case TObject:
				if (Reflect.hasField(obj, "toString")) {
					return obj.toString();
				}
			case TFunction:
				return "<function>";
			case TClass(Date):
				return "Date(" + obj.getTime() + ")";
			case TClass(c):
				if (obj is IMap) {
					var map:IMap<Dynamic, Dynamic> = cast obj;
					return stringifyMap(map);
				}
			default:
		}
		return Std.string(obj);
	}

	public static function assertEquals<T>(actual:T, expected:T, ?pos:haxe.PosInfos) {
		if (!CompareUtils.deepEqual(actual, expected)) {
			var errorMsg = 'Expected ${objToString(expected)} but was ${objToString(actual)} at ${pos.fileName}:${pos.lineNumber}';
			Sys.println(errorMsg);
			throw errorMsg;
		}
	}

	public static function assertTrue(value:Bool, ?pos:haxe.PosInfos) {
		if (!value) {
			var errorMsg = 'Expected true but was false at ${pos.fileName}:${pos.lineNumber}';
			Sys.println(errorMsg);
			throw errorMsg;
		}
	}

	public static function assertFalse(value:Bool, ?pos:haxe.PosInfos) {
		if (value) {
			var errorMsg = 'Expected false but was true at ${pos.fileName}:${pos.lineNumber}';
			Sys.println(errorMsg);
			throw errorMsg;
		}
	}

	public static function assertNull(value:Dynamic, ?pos:haxe.PosInfos) {
		if (value != null) {
			var errorMsg = 'Expected null but was $value at ${pos.fileName}:${pos.lineNumber}';
			Sys.println(errorMsg);
			throw errorMsg;
		}
	}

	public static function assertNotNull(value:Dynamic, ?pos:haxe.PosInfos) {
		if (value == null) {
			var errorMsg = 'Expected not null but was null at ${pos.fileName}:${pos.lineNumber}';
			Sys.println(errorMsg);
			throw errorMsg;
		}
	}

	public static function assertThrows(expectedThrown:Dynamic, f:Void->Void, ?pos:haxe.PosInfos) {
		try {
			f();
		}
		catch (e:Dynamic) {
			if (!CompareUtils.deepEqual(e, expectedThrown)) {
				var errorMsg = 'Expected $expectedThrown but it threw $e at ${pos.fileName}:${pos.lineNumber}';
				Sys.println(errorMsg);
				throw errorMsg;
			}
		}
	}

	public static function shouldFinish(msg:String, f:Void->Void) {
		try {
			f();
		}
		catch (e:Dynamic) {
			var errorMsg = 'Expected $msg to finish but it threw $e at ${haxe.CallStack.toString(haxe.CallStack.callStack())}';
			Sys.println(errorMsg);
			Sys.println(haxe.CallStack.toString(haxe.CallStack.exceptionStack(true)));
			throw errorMsg;
		}
		Sys.println('Passed $msg');
	}

	public static function shouldFail(msg:String, f:Void->Void) {
		try {
			f();
		}
		catch (e:Dynamic) {
			var errorMsg = 'Expected $msg to fail but it did not';
			Sys.println(errorMsg);
			throw errorMsg;
		}
		Sys.println('Passed $msg');
	}

	public static function shouldThrow(msg:String, expectedThrown:Dynamic, f:Void->Void) {
		try {
			f();
		}
		catch (e:Dynamic) {
			if (!CompareUtils.deepEqual(e, expectedThrown)) {
				var errorMsg = 'Expected $msg to throw $expectedThrown but it threw $e at ${haxe.CallStack.toString(haxe.CallStack.callStack())}';
				Sys.println(errorMsg);
				throw errorMsg;
			}
		}
		Sys.println('Passed $msg');
	}
}
