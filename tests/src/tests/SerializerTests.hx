package tests;

import binserializer.Serializer;
import haxe.Int64;
import tests.UnserializerTests.TestClass;
import tests.UnserializerTests.TestEnum;
import tests.UnserializerTests;

using StringTools;

@:access(binserializer.Unserializer)
@:access(binserializer.Serializer)
@:access(UnserializerTests)
class SerializerTests {
	static var hexRegex = ~/[^0-9a-fA-F]/g;

	static function cleanHex(hex:String):String {
		return hexRegex.replace(hex, "");
	}

	static function unserialize(hex:String):Dynamic {
		return UnserializerTests.unserialize(hex);
	}

	static function serialize(obj:Dynamic):String {
		return Serializer.runToHex(obj);
	}

	public static function assert(actual:Dynamic, expected:Dynamic, ?pos:haxe.PosInfos) {
		if ((expected is String)) {
			expected = cleanHex(expected).toLowerCase();
		}
		AssertUtils.assertEquals(actual, expected, pos);
	}

	public static function assertAny(actual:Dynamic, expected:Array<Dynamic>, ?pos:haxe.PosInfos) {
		for (e in expected) {
			if ((e is String)) {
				e = cleanHex(e).toLowerCase();
			}
			if (CompareUtils.deepEqual(actual, expected)) {
				return;
			}
		}
		expected = expected.map(function(e) {
			if ((e is String)) {
				e = cleanHex(e).toLowerCase();
			}
			return e;
		});
		throw 'Expected $actual to match any of $expected at ${pos.fileName}:${pos.lineNumber}';
	}

	public static function test() {
		Sys.println("## SerializerTests ##");

		AssertUtils.shouldFinish("Writes NULL", function() {
			assert(serialize(null), "00");
		});

		AssertUtils.shouldFinish("Writes TRUE", function() {
			assert(serialize(true), "01");
		});

		AssertUtils.shouldFinish("Writes FALSE", function() {
			assert(serialize(false), "02");
		});

		AssertUtils.shouldFinish("Writes ZERO", function() {
			assert(serialize(0), "03");
		});

		AssertUtils.shouldFinish("Writes INT_8", function() {
			assert(serialize(127), "04 7f");
			assert(serialize(128), "04 80");
			assert(serialize(255), "04 ff");
			assert(serialize(1), "04 01"); // cant use 0 because we have a special case for 0
		});

		AssertUtils.shouldFinish("Writes INT_16", function() {
			assert(serialize(256), "05 00 01");
			assert(serialize(65535), "05 ff ff");
			assert(serialize(32767), "05 ff 7f");
		});

		AssertUtils.shouldFinish("Writes INT_32", function() {
			assert(serialize(65536), "06 00 00 01 00");
			assert(serialize(-2), "06 fe ff ff ff"); // cant use -1 because we have a special case for -1
			assert(serialize(2147483647), "06 ff ff ff 7f");
			assert(serialize(-2147483648), "06 00 00 00 80");
		});

		AssertUtils.shouldFinish("Writes INT_64", function() {
			// assert(serialize(Int64.make(0, 1)), "07 01 00 00 00 00 00 00 00");
			assert(serialize(Int64.make(0, -1)), "07 ff ff ff ff 00 00 00 00");
			// assert(serialize(Int64.make(0, 0)), "07 00 00 00 00 00 00 00 00");
			assert(serialize(Int64.make(0x7fffffff, 0xffffffff)), "07 ff ff ff ff ff ff ff 7f");
			assert(serialize(Int64.make(0x80000000, 0x00000000)), "07 00 00 00 00 00 00 00 80");
			// assert(serialize(Int64.make(0xffffffff, 0xffffffff)), "07 ff ff ff ff ff ff ff ff");
		});

		AssertUtils.shouldFinish("Writes FLOAT", function() {
			// assert(serialize(0.0), "08 00 00 00 00 00 00 00 00");
			assert(serialize(1.5), "08 00 00 00 00 00 00 f8 3f");
			assert(serialize(1 / 3), "08 55 55 55 55 55 55 d5 3f");
			// assert(serialize(-1), "08 00 00 00 00 00 00 f0 bf");
		});

		// AssertUtils.shouldFinish("Writes SINGLE", function() {
		//	// assert(serialize((0.0 : Single)), "09 00 00 00 00");
		//	assert(serialize((1.5 : Single)), "09 00 00 c0 3f");
		//	assert(serialize((1 / 3 : Single)), "09 ab aa aa 3e");
		//	// assert(serialize((-1.0 : Single)), "09 00 00 80 bf");
		// });

		AssertUtils.shouldFinish("Writes STRING_8", function() {
			assert(serialize("ABC"), "0a 03 41 42 43");
			assert(serialize("ABCD"), "0a 04 41 42 43 44");
			assert(serialize("ABCDE"), "0a 05 41 42 43 44 45");
			assert(serialize(""), "0a 00");
		});

		AssertUtils.shouldFinish("Writes STRING_16", function() {
			var abc = "ABC";
			for (i in 0...1000) {
				abc += "ABC";
			}
			// trace(abc.length); // 3003
			var abcHex = "414243";
			for (i in 0...1000) {
				abcHex += "414243";
			}
			assert(serialize(abc), "0b bb 0b " + abcHex);
		});

		// Too big to test
		/*AssertUtils.shouldFinish("Writes STRING_32", function() {
			assert(serialize("ABC"), "0c 03 00 00 00 41 42 43");
			assert(serialize("ABCD"), "0c 04 00 00 00 41 42 43 44");
			assert(serialize("ABCDE"), "0c 05 00 00 00 41 42 43 44 45");
			assert(serialize(""), "0c 00 00 00 00");
		});*/

		AssertUtils.shouldFinish("Writes NAN", function() {
			assert(serialize(Math.NaN), "0d");
		});

		AssertUtils.shouldFinish("Writes POSITIVE_INFINITY", function() {
			assert(serialize(Math.POSITIVE_INFINITY), "0e");
		});

		AssertUtils.shouldFinish("Writes NEGATIVE_INFINITY", function() {
			assert(serialize(Math.NEGATIVE_INFINITY), "0f");
		});

		AssertUtils.shouldFinish("Writes ARRAY", function() {
			assert(serialize([1, 2, 3]), "10 0401 0402 0403 ff");
			assert(serialize([1, 2, 3, 4]), "10 0401 0402 0403 0404 ff");
		});

		AssertUtils.shouldFinish("Writes OBJECT", function() {
			assert(serialize({a: 1}), "11 0a0161: 0401 ff");
			assert(serialize({a: 1, b: 2}), "11 0a0161: 0401 | 0a0162: 0402 ff");
			assert(serialize({a: 1, b: 2, c: 3}), "11 0a0161: 0401 | 0a0162: 0402 | 0a0163: 0403 ff");
		});

		AssertUtils.shouldFinish("Writes OBJECT_REF_8", function() {
			var obj = {a: null};
			Serializer.USE_CACHE = true;
			assert(serialize([obj, obj]), "10! {11 0a0161: 00 ff} 12 01 !ff");
			assert(serialize([obj, obj, obj]), "10! {11 0a0161: 00 ff} 12 01 12 01 !ff");
			Serializer.USE_CACHE = false;
		});

		/*AssertUtils.shouldFinish("Writes OBJECT_REF_16", function() {
				var obj = {a: null};
				assert(serialize([obj, obj]), "10! {11 0a0161: 00 ff} 13 0100 !ff");
				assert(serialize([obj, obj, obj]), "10! {11 0a0161: 00 ff} 13 0100 13 0100 !ff");
			});

			AssertUtils.shouldFinish("Writes OBJECT_REF_32", function() {
				var obj = {a: null};
				assert(serialize([obj, obj]), "10! {11 0a0161: 00 ff} 14 01000000 !ff");
				assert(serialize([obj, obj, obj]), "10! {11 0a0161: 00 ff} 14 01000000 14 01000000 !ff");
		});*/

		AssertUtils.shouldFinish("Writes STRING_REF_8", function() {
			assert(serialize(["ABC", "ABC"]), "10! 0a03_414243 15 00 !ff");
			assert(serialize(["ABC", "ABC", "ABC"]), "10! 0a03_414243 15 00 15 00 !ff");
		});

		/*AssertUtils.shouldFinish("Writes STRING_REF_16", function() {
				assert(serialize(["ABC", "ABC"]), "10! 0a03_414243 16 0000 !ff");
				assert(serialize(["ABC", "ABC", "ABC"]), "10! 0a03_414243 16 0000 16 0000 !ff");
			});

			AssertUtils.shouldFinish("Writes STRING_REF_32", function() {
				assert(serialize(["ABC", "ABC"]), "10! 0a03_414243 17 00000000 !ff");
				assert(serialize(["ABC", "ABC", "ABC"]), "10! 0a03_414243 17 00000000 17 00000000 !ff");
		});*/

		AssertUtils.shouldFinish("Writes EXCEPTION", function() {
			var serializer = new Serializer();
			serializer.serializeException("ABC");
			assert(serializer.toString(), "18 0a03_414243");
		});

		AssertUtils.shouldFinish("Writes CLASS_INSTANCE", function() {
			//                        "tests.TestClass" == 74657374732e54657374436c617373
			assert(serialize(new TestClass(0, "ABC")), "19 0a 0f 74657374732e54657374436c617373 {0a0161=03 0a0162=0a03414243 ff}");
			assert(serialize(new TestClass(1, "A")), "19 0a 0f 74657374732e54657374436c617373 {0a0161=0401 0a0162=0a0141 ff}");
		});

		AssertUtils.shouldFinish("Writes ENUM_INSTANCE", function() {
			//                         "tests.TestEnum" == 74657374732e54657374456e756d
			assert(serialize(TestEnum.A), "1a 0a 0e 74657374732e54657374456e756d 0a0141 [ff]");
			assert(serialize(TestEnum.B(1)), "1a 0a 0e 74657374732e54657374456e756d 0a0142 [0401 ff]");
		});

		AssertUtils.shouldFinish("Writes LIST", function() {
			var list = new haxe.ds.List();
			list.add("ABC");
			list.add("DEF");
			assert(serialize(list), "1b 0a03 414243 0a03 444546 ff");
		});

		AssertUtils.shouldFinish("Writes STRING_MAP", function() {
			var map = new haxe.ds.StringMap();
			map.set("ABC", "DEF");
			map.set("GHI", "JKL");
			assertAny(serialize(map), [
				"1c {0a03 414243:0a03 444546} {0a03 474849:0a03 4a4b4c} ff",
				"1c {0a03 474849:0a03 4a4b4c} {0a03 414243:0a03 444546} ff"
			]);
		});

		AssertUtils.shouldFinish("Writes INT_MAP", function() {
			var map = new haxe.ds.IntMap();
			map.set(1, 2);
			map.set(3, 4);
			assertAny(serialize(map), ["1d {0401:0402} {0403:0404} ff", "1d {0403:0404} {0401:0402} ff"]);
		});

		AssertUtils.shouldFinish("Writes OBJECT_MAP", function() {
			var map = new haxe.ds.ObjectMap<Dynamic, Dynamic>();
			map.set({a: 1}, {b: 2});
			map.set({c: 3}, {d: 4});
			assertAny(serialize(map), [
				"1e {{11 0a0161:0401 ff}:{11 0a0162:0402 ff}} {{11 0a0163:0403 ff}:{11 0a0164:0404 ff}} ff",
				"1e {{11 0a0163:0403 ff}:{11 0a0164:0404 ff}} {{11 0a0161:0401 ff}:{11 0a0162:0402 ff}} ff"
			]);
		});

		AssertUtils.shouldFinish("Writes ENUM_MAP", function() {
			var map = new haxe.ds.EnumValueMap<TestEnum, Dynamic>();
			map.set(TestEnum.A, {a: 1});
			map.set(TestEnum.B(1), {b: 2});
			var eStart = "1a 0a0e 74657374732e54657374456e756d";
			var eSecond = "1a 15 00";

			var eAHex = "0a0141 [ff]";
			var eB_1_Hex = "0a0142 [0401 ff]";

			// @formatter:off
			assertAny(serialize(map), [
                "1f [" + eStart + eAHex + " 11 0a0161:0401 ff] [" + eSecond + eB_1_Hex + " 11 0a0162:0402 ff] ff",
                "1f [" + eStart + eB_1_Hex + " 11 0a0162:0402 ff] [" + eSecond + eAHex + " 11 0a0161:0401 ff] ff",
			]);
			// @formatter:on
		});

		AssertUtils.shouldFinish("Writes DATE", function() {
			assert(serialize(Date.fromString("1988-12-25")), "20 0000b053f46e6142");
			assert(serialize(Date.fromString("2005-10-22")), "20 0000b02053717042");
		});

		AssertUtils.shouldFinish("Writes BYTES", function() {
			assert(serialize(haxe.io.Bytes.ofHex("414141")), "21 0403 414141");
			assert(serialize(haxe.io.Bytes.ofHex("00ff7f")), "21 0403 00ff7f");
		});

		AssertUtils.shouldFinish("Writes CLASS_TYPE", function() {
			// "tests.TestClass" == 74657374732e54657374436c617373
			var testClassHex = "74657374732e54657374436c617373";
			assert(serialize(TestClass), "22 0a0f " + testClassHex);
		});

		AssertUtils.shouldFinish("Writes ENUM_TYPE", function() {
			// "tests.TestEnum" == 74657374732e54657374456e756d
			var testEnumHex = "74657374732e54657374456e756d";
			assert(serialize(TestEnum), "23 0a0e " + testEnumHex);
		});

		AssertUtils.shouldFinish("Writes NEG_ONE", function() {
			assert(serialize(-1), "24");
		});

		AssertUtils.shouldFinish("Writes EMPTY_SPACE", function() {
			assert(serialize([1, 2, 3, 4, 5]), "10 0401 0402 0403 0404 0405 ff");
			assert(serialize([1, null, null, null, 5]), "10 0401 fc 03 0405 ff");
		});
	}
}
