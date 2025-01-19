package tests;

import binserializer.Unserializer;
import haxe.Int64;
import haxe.io.Bytes;

using StringTools;

@:access(binserializer.Unserializer)
class UnserializerTests {
	static var hexRegex = ~/[^0-9a-fA-F]/g;

	static function fromHex(hex:String):Bytes {
		hex = hexRegex.replace(hex, "");
		return Bytes.ofHex(hex);
	}

	public static function unserialize(hex:String):Dynamic {
		var bytes = fromHex(hex);
		var unserializer = new Unserializer(bytes);
		var result:Dynamic = unserializer.unserialize();

		if (unserializer.pos != bytes.length) {
			throw 'Pointer not at end of buffer, but at ${unserializer.pos} instead of ${bytes.length}, result was ${result}';
		}
		return result;
	}

	public static function test() {
		Sys.println("## UnserializerTests ##");

		AssertUtils.shouldFinish("Parse NULL", function() {
			AssertUtils.assertEquals(unserialize("00"), null);
		});

		AssertUtils.shouldFinish("Parse TRUE", function() {
			AssertUtils.assertEquals(unserialize("01"), true);
		});

		AssertUtils.shouldFinish("Parse FALSE", function() {
			AssertUtils.assertEquals(unserialize("02"), false);
		});

		AssertUtils.shouldFinish("Parse ZERO", function() {
			AssertUtils.assertEquals(unserialize("03"), 0);
		});

		AssertUtils.shouldFinish("Parse INT_8", function() {
			AssertUtils.assertEquals(unserialize("04 7f"), 127);
			AssertUtils.assertEquals(unserialize("04 80"), 128);
			AssertUtils.assertEquals(unserialize("04 ff"), 255);
			AssertUtils.assertEquals(unserialize("04 00"), 0);
		});

		AssertUtils.shouldFinish("Parse INT_16", function() {
			AssertUtils.assertEquals(unserialize("05 00 01"), 256);
			AssertUtils.assertEquals(unserialize("05 ff ff"), 65535);
			AssertUtils.assertEquals(unserialize("05 00 00"), 0);
			AssertUtils.assertEquals(unserialize("05 ff 7f"), 32767);
			AssertUtils.assertEquals(unserialize("05 05 00"), 5);
		});

		AssertUtils.shouldFinish("Parse INT_32", function() {
			AssertUtils.assertEquals(unserialize("06 00 00 01 00"), 65536);
			AssertUtils.assertEquals(unserialize("06 ff ff ff ff"), -1);
			AssertUtils.assertEquals(unserialize("06 00 00 00 00"), 0);
			AssertUtils.assertEquals(unserialize("06 ff ff ff 7f"), 2147483647);
			AssertUtils.assertEquals(unserialize("06 00 00 00 80"), -2147483648);
		});

		AssertUtils.shouldFinish("Parse INT_64", function() {
			AssertUtils.assertEquals(unserialize("07 01 00 00 00 00 00 00 00"), Int64.make(0, 1));
			AssertUtils.assertEquals(unserialize("07 ff ff ff ff 00 00 00 00"), Int64.make(0, -1));
			AssertUtils.assertEquals(unserialize("07 00 00 00 00 00 00 00 00"), Int64.make(0, 0));
			AssertUtils.assertEquals(unserialize("07 ff ff ff ff ff ff ff 7f"), Int64.make(0x7fffffff, 0xffffffff));
			AssertUtils.assertEquals(unserialize("07 00 00 00 00 00 00 00 80"), Int64.make(0x80000000, 0x00000000));
			AssertUtils.assertEquals(unserialize("07 ff ff ff ff ff ff ff ff"), Int64.make(0xffffffff, 0xffffffff));
		});

		/*var bytes = fromHex("00000000");
			bytes.setFloat(0, 0.0);
			trace(bytes.toHex());

			bytes = fromHex("00000000");
			bytes.setFloat(0, 1.5);
			trace(bytes.toHex());

			bytes = fromHex("00000000");
			bytes.setFloat(0, 1 / 3);
			trace(bytes.toHex());

			bytes = fromHex("00000000");
			bytes.setFloat(0, -1.0);
			trace(bytes.toHex()); */

		AssertUtils.shouldFinish("Parse FLOAT", function() {
			AssertUtils.assertEquals(unserialize("08 00 00 00 00 00 00 00 00"), 0.0);
			AssertUtils.assertEquals(unserialize("08 00 00 00 00 00 00 f8 3f"), 1.5);
			AssertUtils.assertEquals(unserialize("08 55 55 55 55 55 55 d5 3f"), 1 / 3);
			AssertUtils.assertEquals(unserialize("08 00 00 00 00 00 00 f0 bf"), -1);
		});

		AssertUtils.shouldFinish("Parse SINGLE", function() {
			AssertUtils.assertEquals(unserialize("09 00 00 00 00"), ((0.0 : Single)));
			AssertUtils.assertEquals(unserialize("09 00 00 c0 3f"), ((1.5 : Single)));
			AssertUtils.assertEquals(unserialize("09 ab aa aa 3e"), ((1 / 3) : Single));
			AssertUtils.assertEquals(unserialize("09 00 00 80 bf"), ((-1.0 : Single)));
		});

		AssertUtils.shouldFinish("Parse STRING_8", function() {
			AssertUtils.assertEquals(unserialize("0e 03 41 42 43"), "ABC");
			AssertUtils.assertEquals(unserialize("0e 04 41 42 43 44"), "ABCD");
			AssertUtils.assertEquals(unserialize("0e 05 41 42 43 44 45"), "ABCDE");
			AssertUtils.assertEquals(unserialize("0e 00"), "");
		});

		AssertUtils.shouldFinish("Parse STRING_16", function() {
			AssertUtils.assertEquals(unserialize("0f 03 00 41 42 43"), "ABC");
			AssertUtils.assertEquals(unserialize("0f 04 00 41 42 43 44"), "ABCD");
			AssertUtils.assertEquals(unserialize("0f 05 00 41 42 43 44 45"), "ABCDE");
			AssertUtils.assertEquals(unserialize("0f 00 00"), "");
		});

		AssertUtils.shouldFinish("Parse STRING_32", function() {
			AssertUtils.assertEquals(unserialize("10 03 00 00 00 41 42 43"), "ABC");
			AssertUtils.assertEquals(unserialize("10 04 00 00 00 41 42 43 44"), "ABCD");
			AssertUtils.assertEquals(unserialize("10 05 00 00 00 41 42 43 44 45"), "ABCDE");
			AssertUtils.assertEquals(unserialize("10 00 00 00 00"), "");
		});

		AssertUtils.shouldFinish("Parse NAN", function() {
			AssertUtils.assertEquals(unserialize("0a"), Math.NaN);
		});

		AssertUtils.shouldFinish("Parse POSITIVE_INFINITY", function() {
			AssertUtils.assertEquals(unserialize("0b"), Math.POSITIVE_INFINITY);
		});

		AssertUtils.shouldFinish("Parse NEGATIVE_INFINITY", function() {
			AssertUtils.assertEquals(unserialize("0c"), Math.NEGATIVE_INFINITY);
		});

		AssertUtils.shouldFinish("Parse ARRAY", function() {
			AssertUtils.assertEquals(unserialize("11 ff"), []);
			AssertUtils.assertEquals(unserialize("11 00 ff"), [null]);
			AssertUtils.assertEquals(unserialize("11 01 ff"), [true]);
			AssertUtils.assertEquals(unserialize("11 02 ff"), [false]);
			AssertUtils.assertEquals(unserialize("11 0e 03 41 42 43 ff"), ["ABC"]);
		});

		AssertUtils.shouldFinish("Parse OBJECT", function() {
			AssertUtils.assertEquals(unserialize("{12 0e0161: 00 ff}"), {a: null});
			AssertUtils.assertEquals(unserialize("{12 0e0161: {12 0e0162: 04ff ff} ff}"), {a: {b: 255}});
		});

		AssertUtils.shouldFinish("Parse OBJECT_REF_8", function() {
			var obj = {a: null};
			AssertUtils.assertEquals(unserialize("[11! {12 0e0161: 00 ff} 13 01 !ff]"), [obj, obj]);
			AssertUtils.assertEquals(unserialize("[11! {12 0e0161: 00 ff} 13 01 13 01 !ff]"), [obj, obj, obj]);
		});

		AssertUtils.shouldFinish("Parse OBJECT_REF_16", function() {
			var obj = {a: null};
			AssertUtils.assertEquals(unserialize("[11! {12 0e0161: 00 ff} 14 0100 !ff]"), [obj, obj]);
			AssertUtils.assertEquals(unserialize("[11! {12 0e0161: 00 ff} 14 0100 14 0100 !ff]"), [obj, obj, obj]);
		});

		AssertUtils.shouldFinish("Parse OBJECT_REF_32", function() {
			var obj = {a: null};
			AssertUtils.assertEquals(unserialize("[11! {12 0e0161: 00 ff} 15 01000000 !ff]"), [obj, obj]);
			AssertUtils.assertEquals(unserialize("[11! {12 0e0161: 00 ff} 15 01000000 15 01000000 !ff]"), [obj, obj, obj]);
		});

		AssertUtils.shouldFinish("Parse STRING_REF_8", function() {
			AssertUtils.assertEquals(unserialize("[11! 0e03_414243 16 00 !ff]"), ["ABC", "ABC"]);
			AssertUtils.assertEquals(unserialize("[11! 0e03_414243 16 00 16 00 !ff]"), ["ABC", "ABC", "ABC"]);
		});

		AssertUtils.shouldFinish("Parse STRING_REF_16", function() {
			AssertUtils.assertEquals(unserialize("[11! 0e03_414243 17 0000 !ff]"), ["ABC", "ABC"]);
			AssertUtils.assertEquals(unserialize("[11! 0e03_414243 17 0000 17 0000 !ff]"), ["ABC", "ABC", "ABC"]);
		});

		AssertUtils.shouldFinish("Parse STRING_REF_32", function() {
			AssertUtils.assertEquals(unserialize("[11! 0e03_414243 18 00000000 !ff]"), ["ABC", "ABC"]);
			AssertUtils.assertEquals(unserialize("[11! 0e03_414243 18 00000000 18 00000000 !ff]"), ["ABC", "ABC", "ABC"]);
		});

		AssertUtils.shouldFinish("Parse EXCEPTION", function() {
			AssertUtils.assertThrows("ABC", function() {
				unserialize("19 0e03_414243");
			});
			AssertUtils.assertThrows({a: 1}, function() {
				unserialize("19 {11 0e0161: 0401 ff}");
			});
		});

		AssertUtils.shouldFinish("Parse CLASS_INSTANCE", function() {
			//                        "tests.TestClass" == 74657374732e54657374436c617373
			AssertUtils.assertEquals(unserialize("1a 0e 0f 74657374732e54657374436c617373 {0e0161=03 0e0162=0e03414243 ff}").toString(),
				(new TestClass(0, "ABC")).toString());
			AssertUtils.assertEquals(unserialize("1a 0e 0f 74657374732e54657374436c617373 {0e0161=0401 0e0162=0e0141 ff}").toString(),
				(new TestClass(1, "A")).toString());
		});

		AssertUtils.shouldFinish("Parse ENUM_INSTANCE", function() {
			//                         "tests.TestEnum" == 74657374732e54657374456e756d
			AssertUtils.assertEquals(unserialize("1b 0e 0e 74657374732e54657374456e756d 0e0141 [ff]"), TestEnum.A);
			AssertUtils.assertEquals(unserialize("1b 0e 0e 74657374732e54657374456e756d 0e0142 [0401 ff]"), TestEnum.B(1));
		});

		AssertUtils.shouldFinish("Parse LIST", function() {
			var list = new haxe.ds.List();
			list.add("ABC");
			list.add("DEF");
			AssertUtils.assertEquals(unserialize("1c 0e03 414243 0e03 444546 ff"), list);
		});

		AssertUtils.shouldFinish("Parse STRING_MAP", function() {
			var map = new haxe.ds.StringMap();
			map.set("ABC", "DEF");
			map.set("GHI", "JKL");
			AssertUtils.assertEquals(unserialize("1d {0e03 414243:0e03 444546} {0e03 474849:0e03 4a4b4c} ff"), map);
		});

		AssertUtils.shouldFinish("Parse INT_MAP", function() {
			var map = new haxe.ds.IntMap();
			map.set(1, 2);
			map.set(3, 4);
			AssertUtils.assertEquals(unserialize("1e {0401:0402} {0403:0404} ff"), map);
		});

		AssertUtils.shouldFinish("Parse OBJECT_MAP", function() {
			var map = new haxe.ds.ObjectMap<Dynamic, Dynamic>();
			map.set({a: 1}, {b: 2});
			map.set({c: 3}, {d: 4});
			AssertUtils.assertEquals(unserialize("1f {{12 0e0161:0401 ff}:{12 0e0162:0402 ff}} {{12 0e0163:0403 ff}:{12 0e0164:0404 ff}} ff"), map);
		});

		AssertUtils.shouldFinish("Parse ENUM_MAP", function() {
			var map = new haxe.ds.EnumValueMap<TestEnum, Dynamic>();
			map.set(TestEnum.A, {a: 1});
			map.set(TestEnum.B(1), {b: 2});
			var testEnumAHex = "1b 0e0e 74657374732e54657374456e756d 0e0141 [ff]";
			var testEnumB_1_Hex = "1b 0e0e 74657374732e54657374456e756d 0e0142 [0401 ff]";
			AssertUtils.assertEquals(unserialize("20 [" + testEnumAHex + " 12 0e0161:0401 ff] [" + testEnumB_1_Hex + " 12 0e0162:0402 ff] ff"), map);
		});

		AssertUtils.shouldFinish("Parse DATE", function() {
			AssertUtils.assertEquals(unserialize("21 0000b053f46e6142"), Date.fromString("1988-12-25")); // random date
			AssertUtils.assertEquals(unserialize("21 0000b02053717042"), Date.fromString("2005-10-22")); // when haxe started
		});

		AssertUtils.shouldFinish("Parse BYTES", function() {
			AssertUtils.assertEquals(unserialize("22 0403 414141"), haxe.io.Bytes.ofHex("414141"));
			AssertUtils.assertEquals(unserialize("22 0403 00ff7f"), haxe.io.Bytes.ofHex("00ff7f"));
		});

		AssertUtils.shouldFinish("Parse CLASS_TYPE", function() {
			// "tests.TestClass" == 74657374732e54657374436c617373
			var testClassHex = "74657374732e54657374436c617373";
			AssertUtils.assertEquals(unserialize("23 0e0f " + testClassHex), TestClass);
		});

		AssertUtils.shouldFinish("Parse ENUM_TYPE", function() {
			// "tests.TestEnum" == 74657374732e54657374456e756d
			var testEnumHex = "74657374732e54657374456e756d";
			AssertUtils.assertEquals(unserialize("24 0e0e " + testEnumHex), TestEnum);
		});

		AssertUtils.shouldFinish("Parse NEG_ONE", function() {
			AssertUtils.assertEquals(unserialize("25"), -1);
		});

		AssertUtils.shouldFinish("Parse EMPTY_SPACE", function() {
			AssertUtils.assertEquals(unserialize("11 0401 00 00 00 0405 ff"), [1, null, null, null, 5]);
			AssertUtils.assertEquals(unserialize("11 0401 fc 03 0405 ff"), [1, null, null, null, 5]);
		});

		AssertUtils.shouldFinish("Parse PI", function() {
			AssertUtils.assertEquals(unserialize("0d"), Math.PI);
		});

		AssertUtils.shouldFinish("Parse NEG_INT8", function() {
			AssertUtils.assertEquals(unserialize("26 02"), -2);
		});

		AssertUtils.shouldFinish("Parse NEG_INT16", function() {
			AssertUtils.assertEquals(unserialize("27 02 00"), -2);
		});

		// var bytes = fromHex("0000000000000000");
		// bytes.setInt64(0, Int64.make(0x80000000, 0x00000000));
		// trace(bytes.toHex());

		// var hex = "10 0e 03 414243 11 0e 03 414141 00 FF 01 0f 15 00 ff";
		// trace(Unserializer.run(fromHex(hex)));
		// var hex = "10 0e 03 414243 11 0b 0300 414141 00 FF 01 0f 15 00 ff";
		// trace(Unserializer.run(fromHex(hex)));
	}
}

class TestClass {
	public var a:Int;
	public var b:String;

	public function new(a:Int, b:String) {
		this.a = a;
		this.b = b;
	}

	public function toString() {
		return 'TestClass($a, $b)';
	}
}

enum TestEnum {
	A;
	B(a:Int);
}
