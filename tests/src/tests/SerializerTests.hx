package tests;

import binserializer.Serializer;
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
			// assert(serialize(-2), "06 fe ff ff ff"); // cant use -1 because we have a special case for -1
			assert(serialize(2147483647), "06 ff ff ff 7f");
			assert(serialize(-2147483648), "06 00 00 00 80");
		});

		AssertUtils.shouldFinish("Writes INT_64", function() {
			// assert(serialize(Int64.make(0, 1)), "07 01 00 00 00 00 00 00 00");
			assert(serialize(haxe.Int64.make(0, -1)), "07 ff ff ff ff 00 00 00 00");
			// assert(serialize(Int64.make(0, 0)), "07 00 00 00 00 00 00 00 00");
			assert(serialize(haxe.Int64.make(0x7fffffff, 0xffffffff)), "07 ff ff ff ff ff ff ff 7f");
			assert(serialize(haxe.Int64.make(0x80000000, 0x00000000)), "07 00 00 00 00 00 00 00 80");
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
			assert(serialize("ABC"), "0e 03 41 42 43");
			assert(serialize("ABCD"), "0e 04 41 42 43 44");
			assert(serialize("ABCDE"), "0e 05 41 42 43 44 45");
			assert(serialize(""), "0e 00");
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
			assert(serialize(abc), "0f bb 0b " + abcHex);
		});

		// Too big to test
		/*AssertUtils.shouldFinish("Writes STRING_32", function() {
			assert(serialize("ABC"), "0c 03 00 00 00 41 42 43");
			assert(serialize("ABCD"), "0c 04 00 00 00 41 42 43 44");
			assert(serialize("ABCDE"), "0c 05 00 00 00 41 42 43 44 45");
			assert(serialize(""), "0c 00 00 00 00");
		});*/

		AssertUtils.shouldFinish("Writes NAN", function() {
			assert(serialize(Math.NaN), "0a");
		});

		AssertUtils.shouldFinish("Writes POSITIVE_INFINITY", function() {
			assert(serialize(Math.POSITIVE_INFINITY), "0b");
		});

		AssertUtils.shouldFinish("Writes NEGATIVE_INFINITY", function() {
			assert(serialize(Math.NEGATIVE_INFINITY), "0c");
		});

		AssertUtils.shouldFinish("Writes ARRAY", function() {
			assert(serialize([1, 2, 3]), "11 0401 0402 0403 ff");
			assert(serialize([1, 2, 3, 4]), "11 0401 0402 0403 0404 ff");
		});

		AssertUtils.shouldFinish("Writes OBJECT", function() {
			assert(serialize({a: 1}), "12 0e0161: 0401 ff");
			assert(serialize({a: 1, b: 2}), "12 0e0161: 0401 | 0e0162: 0402 ff");
			assert(serialize({a: 1, b: 2, c: 3}), "12 0e0161: 0401 | 0e0162: 0402 | 0e0163: 0403 ff");
		});

		AssertUtils.shouldFinish("Writes OBJECT_REF_8", function() {
			var obj = {a: null};
			Serializer.USE_CACHE = true;
			assert(serialize([obj, obj]), "11! {12 0e0161: 00 ff} 13 01 !ff");
			assert(serialize([obj, obj, obj]), "11! {12 0e0161: 00 ff} 13 01 13 01 !ff");
			Serializer.USE_CACHE = false;
		});

		/*AssertUtils.shouldFinish("Writes OBJECT_REF_16", function() {
				var obj = {a: null};
				assert(serialize([obj, obj]), "11! {12 0e0161: 00 ff} 14 0100 !ff");
				assert(serialize([obj, obj, obj]), "11! {12 0e0161: 00 ff} 14 0100 14 0100 !ff");
			});

			AssertUtils.shouldFinish("Writes OBJECT_REF_32", function() {
				var obj = {a: null};
				assert(serialize([obj, obj]), "11! {12 0e0161: 00 ff} 15 01000000 !ff");
				assert(serialize([obj, obj, obj]), "11! {12 0e0161: 00 ff} 15 01000000 15 01000000 !ff");
		});*/

		AssertUtils.shouldFinish("Writes STRING_REF_8", function() {
			assert(serialize(["ABC", "ABC"]), "11! 0e03_414243 16 00 !ff");
			assert(serialize(["ABC", "ABC", "ABC"]), "11! 0e03_414243 16 00 16 00 !ff");
		});

		/*AssertUtils.shouldFinish("Writes STRING_REF_16", function() {
				assert(serialize(["ABC", "ABC"]), "11! 0e03_414243 17 0000 !ff");
				assert(serialize(["ABC", "ABC", "ABC"]), "11! 0e03_414243 17 0000 17 0000 !ff");
			});

			AssertUtils.shouldFinish("Writes STRING_REF_32", function() {
				assert(serialize(["ABC", "ABC"]), "11! 0e03_414243 18 00000000 !ff");
				assert(serialize(["ABC", "ABC", "ABC"]), "11! 0e03_414243 18 00000000 18 00000000 !ff");
		});*/

		AssertUtils.shouldFinish("Writes EXCEPTION", function() {
			var serializer = new Serializer();
			serializer.serializeException("ABC");
			assert(serializer.toString(), "19 0e03_414243");
		});

		AssertUtils.shouldFinish("Writes CLASS_INSTANCE", function() {
			//                        "tests.TestClass" == 74657374732e54657374436c617373
			assert(serialize(new TestClass(0, "ABC")), "1a 0e 0f 74657374732e54657374436c617373 {0e0161=03 0e0162=0e03414243 ff}");
			assert(serialize(new TestClass(1, "A")), "1a 0e 0f 74657374732e54657374436c617373 {0e0161=0401 0e0162=0e0141 ff}");
		});

		AssertUtils.shouldFinish("Writes ENUM_INSTANCE", function() {
			//                         "tests.TestEnum" == 74657374732e54657374456e756d
			assert(serialize(TestEnum.A), "1b 0e 0e 74657374732e54657374456e756d 0e0141 [ff]");
			assert(serialize(TestEnum.B(1)), "1b 0e 0e 74657374732e54657374456e756d 0e0142 [0401 ff]");
		});

		AssertUtils.shouldFinish("Writes LIST", function() {
			var list = new haxe.ds.List();
			list.add("ABC");
			list.add("DEF");
			assert(serialize(list), "1c 0e03 414243 0e03 444546 ff");
		});

		AssertUtils.shouldFinish("Writes STRING_MAP", function() {
			var map = new haxe.ds.StringMap();
			map.set("ABC", "DEF");
			map.set("GHI", "JKL");
			assertAny(serialize(map), [
				"1d {0e03 414243:0e03 444546} {0e03 474849:0e03 4a4b4c} ff",
				"1d {0e03 474849:0e03 4a4b4c} {0e03 414243:0e03 444546} ff"
			]);
		});

		AssertUtils.shouldFinish("Writes INT_MAP", function() {
			var map = new haxe.ds.IntMap();
			map.set(1, 2);
			map.set(3, 4);
			assertAny(serialize(map), ["1e {0401:0402} {0403:0404} ff", "1e {0403:0404} {0401:0402} ff"]);
		});

		AssertUtils.shouldFinish("Writes OBJECT_MAP", function() {
			var map = new haxe.ds.ObjectMap<Dynamic, Dynamic>();
			map.set({a: 1}, {b: 2});
			map.set({c: 3}, {d: 4});
			assertAny(serialize(map), [
				"1f {{12 0e0161:0401 ff}:{12 0e0162:0402 ff}} {{12 0e0163:0403 ff}:{12 0e0164:0404 ff}} ff",
				"1f {{12 0e0163:0403 ff}:{12 0e0164:0404 ff}} {{12 0e0161:0401 ff}:{12 0e0162:0402 ff}} ff"
			]);
		});

		AssertUtils.shouldFinish("Writes ENUM_MAP", function() {
			var map = new haxe.ds.EnumValueMap<TestEnum, Dynamic>();
			map.set(TestEnum.A, {a: 1});
			map.set(TestEnum.B(1), {b: 2});
			var eStart = "1b 0e0e 74657374732e54657374456e756d";
			var eSecond = "1b 15 00";

			var eAHex = "0e0141 [ff]";
			var eB_1_Hex = "0e0142 [0401 ff]";

			// @formatter:off
			assertAny(serialize(map), [
                "20 [" + eStart + eAHex + " 12 0e0161:0401 ff] [" + eSecond + eB_1_Hex + " 12 0e0162:0402 ff] ff",
                "20 [" + eStart + eB_1_Hex + " 12 0e0162:0402 ff] [" + eSecond + eAHex + " 12 0e0161:0401 ff] ff",
			]);
			// @formatter:on
		});

		AssertUtils.shouldFinish("Writes DATE", function() {
			assert(serialize(Date.fromString("1988-12-25")), "21 0000b053f46e6142");
			assert(serialize(Date.fromString("2005-10-22")), "21 0000b02053717042");
		});

		AssertUtils.shouldFinish("Writes BYTES", function() {
			assert(serialize(haxe.io.Bytes.ofHex("414141")), "22 0403 414141");
			assert(serialize(haxe.io.Bytes.ofHex("00ff7f")), "22 0403 00ff7f");
		});

		AssertUtils.shouldFinish("Writes CLASS_TYPE", function() {
			// "tests.TestClass" == 74657374732e54657374436c617373
			var testClassHex = "74657374732e54657374436c617373";
			assert(serialize(TestClass), "23 0e0f " + testClassHex);
		});

		AssertUtils.shouldFinish("Writes ENUM_TYPE", function() {
			// "tests.TestEnum" == 74657374732e54657374456e756d
			var testEnumHex = "74657374732e54657374456e756d";
			assert(serialize(TestEnum), "24 0e0e " + testEnumHex);
		});

		AssertUtils.shouldFinish("Writes NEG_ONE", function() {
			assert(serialize(-1), "25");
		});

		AssertUtils.shouldFinish("Writes EMPTY_SPACE", function() {
			assert(serialize([1, 2, 3, 4, 5]), "11 0401 0402 0403 0404 0405 ff");
			assert(serialize([1, null, null, null, 5]), "11 0401 fc 03 0405 ff");
		});

		AssertUtils.shouldFinish("Writes PI", function() {
			assert(serialize(Math.PI), "0d");
		});

		AssertUtils.shouldFinish("Writes NEG_INT8", function() {
			assert(serialize(-2), "26 02");
		});

		AssertUtils.shouldFinish("Writes NEG_INT16", function() {
			assert(serialize(-512), "27 00 02");
		});
	}
}
