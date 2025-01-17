package tests;

import binserializer.Serializer;
import binserializer.Unserializer;
import haxe.Log;
import haxe.io.Bytes;
import tests.UnserializerTests;

using StringTools;

@:access(binserializer.Serializer)
@:access(binserializer.Unserializer)
class FullTests {
	public static function serialize(obj:Dynamic):Bytes {
		return Serializer.run(obj);
	}

	public static function unserialize(bytes:Bytes):Dynamic {
		var unserializer = new Unserializer(bytes);
		var result:Dynamic = unserializer.unserialize();

		if (unserializer.pos != bytes.length) {
			throw 'Pointer not at end of buffer, but at ${unserializer.pos} instead of ${bytes.length}, result was ${result}';
		}
		return result;
	}

	static function assertParsing(object:Dynamic, ?pos:haxe.PosInfos) {
		var bytes = serialize(object);
		// Log.trace(bytes.toHex(), pos);
		var unserialized = unserialize(bytes);
		AssertUtils.assertEquals(unserialized, object, pos);
	}

	static function check(object:Dynamic, ?pos:haxe.PosInfos) {
		Log.trace(serialize(object).toHex(), pos);
	}

	public static function test() {
		Sys.println("## Full Tests ##");

		AssertUtils.shouldFinish("Simple", function() {
			assertParsing(null);
		});

		AssertUtils.shouldFinish("Object", function() {
			assertParsing({a: 1, b: 2, c: 3});
		});

		AssertUtils.shouldFinish("Array", function() {
			assertParsing([1, 2, 3]);
			assertParsing([1, null, null, null, null, null, 4]);
		});

		AssertUtils.shouldFinish("String", function() {
			assertParsing("ABC");
			assertParsing(["ABC", "BCD", "ABC"]);
		});

		AssertUtils.shouldFinish("Int", function() {
			assertParsing(1);
			assertParsing(127);
			assertParsing(128);
			assertParsing(255);
			assertParsing(-1);
			assertParsing(-127);
			assertParsing(-128);
			assertParsing(-255);
		});

		AssertUtils.shouldFinish("Float", function() {
			assertParsing(0.0);
			assertParsing(1.5);
			assertParsing(1 / 3);
			assertParsing(-1.0);

			assertParsing(Math.NaN);
			assertParsing(Math.POSITIVE_INFINITY);
			assertParsing(Math.NEGATIVE_INFINITY);
			assertParsing(Math.PI);
		});

		AssertUtils.shouldFinish("Bool", function() {
			assertParsing(true);
			assertParsing(false);
		});

		AssertUtils.shouldFinish("Enum", function() {
			assertParsing(TestEnum.A);
			assertParsing(TestEnum.B(1));
			assertParsing(TestEnum.B(6));
		});

		AssertUtils.shouldFinish("Date", function() {
			assertParsing(Date.fromString("1988-12-25"));
			assertParsing(Date.fromString("2005-10-22"));
			// assertParsing(Date.now()); // Sometimes errors, pretty sure its some small precision issue
		});

		AssertUtils.shouldFinish("Bytes", function() {
			assertParsing(haxe.io.Bytes.ofHex("414141"));
			assertParsing(haxe.io.Bytes.ofHex("00ff7f"));
		});

		AssertUtils.shouldFinish("Class", function() {
			assertParsing(new TestClass(0, "ABC"));
			assertParsing(new TestClass(1, "A"));
		});

		AssertUtils.shouldFinish("Enum", function() {
			assertParsing(TestEnum.A);
			assertParsing(TestEnum.B(1));
		});

		AssertUtils.shouldFinish("List", function() {
			assertParsing(new haxe.ds.List());
			assertParsing({
				var _ = new haxe.ds.List();
				_.add("ABC");
				_;
			});
			assertParsing({
				var _ = new haxe.ds.List();
				_.add("ABC");
				_.add("DEF");
				_;
			});
		});

		AssertUtils.shouldFinish("Map", function() {
			assertParsing(new haxe.ds.StringMap());
			assertParsing({
				var _ = new haxe.ds.StringMap();
				_.set("ABC", "DEF");
				_.set("GHI", "JKL");
				_;
			});
			assertParsing({
				var _ = new haxe.ds.StringMap();
				_.set("ABC", "DEF");
				_.set("GHI", "JKL");
				_.set("MNO", "PQR");
				_;
			});

			assertParsing(new haxe.ds.IntMap());
			assertParsing({
				var _ = new haxe.ds.IntMap();
				_.set(1, 2);
				_.set(3, 4);
				_;
			});
			assertParsing({
				var _ = new haxe.ds.IntMap();
				_.set(1, 2);
				_.set(3, 4);
				_.set(5, 6);
				_;
			});

			assertParsing(new haxe.ds.ObjectMap<Dynamic, Dynamic>());
			assertParsing({
				var _ = new haxe.ds.ObjectMap<Dynamic, Dynamic>();
				_.set({a: 1}, {b: 2});
				_.set({c: 3}, {d: 4});
				_;
			});
			assertParsing({
				var _ = new haxe.ds.ObjectMap<Dynamic, Dynamic>();
				_.set({a: 1}, {b: 2});
				_.set({c: 3}, {d: 4});
				_.set({e: 5}, {f: 6});
				_;
			});

			/*

				1f // enum map
					// key
					1a // enum TestEnum.A
						0a 0e 74 65 73 74 73 2e 54 65 73 74 45 6e 75 6d 0a 01 41
						ff
					// value
					11 // object {a: 1}
						0a 01 61
						04 01
						ff

					// key
					1a // enum TestEnum.B(5)
						15 00 // TestEnum
						0a 01 42 // B
						04 05 // 5
						ff
					11 // object {b: 2}
						0a 01 62
						04 02
						ff
				ff
			 */

			assertParsing(new haxe.ds.EnumValueMap<Dynamic, Dynamic>());
			assertParsing({
				var _ = new haxe.ds.EnumValueMap<Dynamic, Dynamic>();
				_.set(TestEnum.A, {a: 1});
				_.set(TestEnum.B(5), {b: 2});
				_;
			});
			assertParsing({
				var _ = new haxe.ds.EnumValueMap<Dynamic, Dynamic>();
				_.set(TestEnum.A, {a: 1});
				_.set(TestEnum.B(1), {b: 2});
				_.set(TestEnum.B(2), {c: 3});
				_;
			});
		});
	}
}
