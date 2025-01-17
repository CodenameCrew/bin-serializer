package binserializer;

import binserializer.Format;
import haxe.ds.List;
import haxe.io.Bytes;
import haxe.io.BytesOutput;

class Serializer {
	/**
	 * If the values you are serializing can contain circular references or
	 * objects repetitions, you should set `USE_CACHE` to true to prevent
	 * infinite loops.
	 *
	 * This may also reduce the size of serialization Strings at the expense of
	 * performance.
	 *
	 * This value can be changed for individual instances of `Serializer` by
	 * setting their `useCache` field.
	**/
	public static var USE_CACHE = false;

	var buf:BytesOutput;
	var cache:Array<Dynamic>;
	var shash:haxe.ds.StringMap<Int>;
	var scount:Int;

	/**
	 * The individual cache setting for `this` Serializer instance.
	 *
	 * See `USE_CACHE` for a complete description.
	**/
	public var useCache:Bool;

	/**
	 * Creates a new Serializer instance.
	 *
	 * Subsequent calls to `this.serialize` will append values to the
	 * internal buffer of this String. Once complete, the contents can be
	 * retrieved through a call to `this.toBytes`.
	 *
	 * Each `Serializer` instance maintains its own cache if `this.useCache` is
	 * `true`.
	**/
	public function new() {
		buf = new BytesOutput();
		cache = new Array();
		useCache = USE_CACHE;
		shash = new haxe.ds.StringMap();
		scount = 0;
	}

	/**
	 * Return the String Hex representation of `this` Serializer.
	**/
	public function toString() {
		return buf.getBytes().toHex();
	}

	public function toBytes():Bytes {
		return buf.getBytes();
	}

	inline function writeTag(tag:SerializedFormat) {
		buf.writeByte(tag);
	}

	function writeTagBasedOnSize(size:UInt, int8:SerializedFormat = INT8, int16:SerializedFormat = INT16, int32:SerializedFormat = INT32) {
		if (size <= 0xFF) {
			buf.writeByte(int8);
		}
		else if (size <= 0xFFFF) {
			buf.writeByte(int16);
		}
		else {
			buf.writeByte(int32);
		}
	}

	function writeIntWithoutTag(i:UInt) {
		if (i <= 0xFF) {
			buf.writeByte(i);
		}
		else if (i <= 0xFFFF) {
			buf.writeUInt16(i);
		}
		else {
			buf.writeInt32(i);
		}
	}

	inline function writeInt(i:UInt, int8:SerializedFormat = INT8, int16:SerializedFormat = INT16, int32:SerializedFormat = INT32) {
		writeTagBasedOnSize(i, int8, int16, int32);
		writeIntWithoutTag(i);
	}

	function serializeString(s:String) {
		var x = shash.get(s);
		if (x != null) {
			writeInt(x, STRING_REF_8, STRING_REF_16, STRING_REF_32);
			return;
		}
		shash.set(s, scount++);

		var length = s.length;

		writeInt(length, STRING_8, STRING_16, STRING_32);
		buf.writeString(s);
	}

	function serializeRef(v:Dynamic) {
		#if js
		var vt = js.Syntax.typeof(v);
		#end
		for (i in 0...cache.length) {
			#if js
			var ci = cache[i];
			if (js.Syntax.typeof(ci) == vt && ci == v) {
			#else
			if (cache[i] == v) {
			#end
				writeInt(i, OBJECT_REF_8, OBJECT_REF_16, OBJECT_REF_32);
				return true;
			}
		}
		cache.push(v);
		return false;
	}

	function serializeFields(v:{}) {
		for (f in Reflect.fields(v)) {
			serializeString(f);
			serialize(Reflect.field(v, f));
		}
		writeTag(END);
	}

	/**
	 * 	Serializes `v`.
	 *
	 * 	All haxe-defined values and objects with the exception of functions can
	 * 	be serialized. Serialization of external/native objects is not
	 * 	guaranteed to work.
	 *
	 * 	The values of `this.useCache` and `this.useEnumIndex` may affect
	 * 	serialization output.
	**/
	public function serialize(v:Dynamic) {
		// TODO: Support int64
		switch (Type.typeof(v)) {
			case TNull:
				writeTag(NULL);
			case TInt:
				var v:Int = v;
				if (v == 0) {
					writeTag(ZERO);
					return;
				}
				else if (v == -1) {
					writeTag(NEG_ONE);
					return;
				}
				var isNeg = v < 0;
				var abs = isNeg ? -v : v;
				// >= is due to small edge case with -2147483648
				if (isNeg && abs >= 0 && abs <= 255) {
					writeTag(NEG_INT8);
					writeIntWithoutTag(abs);
				}
				else if (isNeg && abs >= 0 && abs <= 65535) {
					writeTag(NEG_INT16);
					writeIntWithoutTag(abs);
				}
				else {
					writeInt(v, INT8, INT16, INT32);
				}
			case TFloat:
				var v:Float = v;
				if (Math.isNaN(v))
					writeTag(NAN);
				else if (!Math.isFinite(v))
					writeTag(if (v < 0) NEGATIVE_INFINITY else POSITIVE_INFINITY);
				else if (v == Math.PI)
					writeTag(PI);
				else {
					// TODO: check if single precision is enough
					writeTag(FLOAT);
					buf.writeDouble(v);
				}
			case TBool:
				writeTag(if (v) TRUE else FALSE);
			case TClass(String):
				serializeString(v);
			case TClass(_) if (useCache && serializeRef(v)):
				// makes it so we don't need to check if cached in every class case
			case TClass(Array):
				var ucount = 0;
				writeTag(ARRAY);
				var v:Array<Dynamic> = v;
				var l = v.length;
				for (i in 0...l) {
					if (v[i] == null)
						ucount++;
					else {
						if (ucount > 0) {
							if (ucount == 1)
								writeTag(NULL);
							else
								writeInt(ucount, EMPTY_SPACE_8, EMPTY_SPACE_16, EMPTY_SPACE_32);
							ucount = 0;
						}
						serialize(v[i]);
					}
				}
				if (ucount > 0) {
					// size check to make sure its optimized
					// normal   = 00
					// ucount 1 = fc 01
					// normal   = 00 00
					// ucount 2 = fc 02
					// normal   = 00 00 00
					// ucount 3 = fc 03

					if (ucount == 1)
						writeTag(NULL);
					else
						writeInt(ucount, EMPTY_SPACE_8, EMPTY_SPACE_16, EMPTY_SPACE_32);
				}
				writeTag(END);
			case TClass(haxe.ds.List):
				writeTag(LIST);
				var v:List<Dynamic> = v;
				for (i in v)
					serialize(i);
				writeTag(END);
			case TClass(haxe.ds.StringMap):
				writeTag(STRING_MAP);
				var v:haxe.ds.StringMap<Dynamic> = v;
				for (k in v.keys()) {
					serializeString(k);
					serialize(v.get(k));
				}
				writeTag(END);
			case TClass(haxe.ds.IntMap):
				writeTag(INT_MAP);
				var v:haxe.ds.IntMap<Dynamic> = v;
				for (k in v.keys()) {
					serialize(k);
					serialize(v.get(k));
				}
				writeTag(END);
			case TClass(haxe.ds.ObjectMap):
				writeTag(OBJECT_MAP);
				var v:haxe.ds.ObjectMap<Dynamic, Dynamic> = v;
				for (k in v.keys()) {
					#if (js || neko)
					var id = Reflect.field(k, "__id__");
					Reflect.deleteField(k, "__id__");
					serialize(k);
					Reflect.setField(k, "__id__", id);
					#else
					serialize(k);
					#end
					serialize(v.get(k));
				}
				writeTag(END);
			case TClass(haxe.ds.EnumValueMap):
				writeTag(ENUM_MAP);
				var v:haxe.ds.EnumValueMap<Dynamic, Dynamic> = v;
				for (k in v.keys()) {
					#if (js || neko)
					var id = Reflect.field(k, "__id__");
					Reflect.deleteField(k, "__id__");
					serialize(k);
					Reflect.setField(k, "__id__", id);
					#else
					serialize(k);
					#end
					serialize(v.get(k));
				}
				writeTag(END);
			case TClass(Date):
				var d:Date = v;
				writeTag(DATE);
				buf.writeDouble(d.getTime());
			case TClass(haxe.io.Bytes):
				var v:haxe.io.Bytes = v;
				writeTag(BYTES);
				writeInt(v.length);
				buf.write(v);
			#if cpp
			case TClass(cpp.Int64):
				var v:cpp.Int64 = v;
				writeTag(INT64);
				var bytes = Bytes.alloc(8);
				bytes.setInt64(0, v);
				buf.write(bytes);
			#elseif js
			case TClass(c) if (Type.getClassName(c) == "haxe._Int64.___Int64"):
				var v:haxe.Int64 = v;
				writeTag(INT64);
				var bytes = Bytes.alloc(8);
				bytes.setInt64(0, v);
				buf.write(bytes);
			#end
			case TClass(c):
				writeTag(CLASS_INSTANCE);
				serializeString(Type.getClassName(c));
				serializeFields(v);
			case TObject:
				if (Std.isOfType(v, Class)) {
					var className = Type.getClassName(v);
					#if cpp
					// Currently, Enum and Class are the same for flash and cpp.
					//  use resolveEnum to test if it is actually an enum
					if (Type.resolveEnum(className) != null)
						writeTag(ENUM_TYPE);
					else
					#end
					writeTag(CLASS_TYPE);
					serializeString(className);
				}
				else if (Std.isOfType(v, Enum)) {
					writeTag(ENUM_TYPE);
					serializeString(Type.getEnumName(v));
				}
				else {
					if (useCache && serializeRef(v))
						return;
					writeTag(OBJECT);
					serializeFields(v);
				}
			case TEnum(e):
				if (useCache) {
					if (serializeRef(v))
						return;
					cache.pop(); // remove from cache
				}
				writeTag(ENUM_INSTANCE);
				serializeString(Type.getEnumName(e));
				#if neko
				serializeString(new String(v.tag));
				if (v.args != null) {
					var l:Int = untyped __dollar__asize(v.args);
					for (i in 0...l)
						serialize(v.args[i]);
				}
				writeTag(END);
				#elseif cpp
				var enumBase:cpp.EnumBase = v;
				serializeString(enumBase.getTag());
				var len = enumBase.getParamCount();
				for (p in 0...len)
					serialize(enumBase.getParamI(p));
				writeTag(END);
				#elseif php
				serializeString(v.tag);
				var l:Int = php.Syntax.code("count({0})", v.params);
				if (l != 0 && v.params != null) {
					for (i in 0...l)
						serialize(v.params[i]);
				}
				writeTag(END);
				#elseif (java || python || hl || eval)
				serializeString(Type.enumConstructor(v));
				var arr:Array<Dynamic> = Type.enumParameters(v);
				if (arr != null) {
					for (v in arr)
						serialize(v);
				}
				writeTag(END);
				#elseif (js && !js_enums_as_arrays)
				serializeString(Type.enumConstructor(v));
				var params = Type.enumParameters(v);
				for (p in params)
					serialize(p);
				writeTag(END);
				#else
				serializeString(v[0]);
				var l = __getField(v, "length");
				for (i in 2...l)
					serialize(v[i]);
				writeTag(END);
				#end
				if (useCache)
					cache.push(v); // manually add to cache
			case TFunction:
				throw "Cannot serialize function";
			default:
				#if neko
				if (untyped (__i32__kind != null && __dollar__iskind(v, __i32__kind))) {
					writeInt(v);
					return;
				}
				#end
				throw "Cannot serialize " + Std.string(v);
		}
	}

	extern inline function __getField(o:Dynamic, f:String):Dynamic
		return o[cast f];

	public function serializeException(e:Dynamic) {
		writeTag(EXCEPTION);
		#if flash
		if (untyped __is__(e, __global__["Error"])) {
			var e:flash.errors.Error = e;
			var s = e.getStackTrace();
			if (s == null)
				serialize(e.message);
			else
				serialize(s);
			return;
		}
		#end
		serialize(e);
	}

	/**
	 * Serializes `v` and returns the Bytes representation.
	 *
	 * This is a convenience function for creating a new instance of
	 * Serializer, serialize `v` into it and obtain the result through a call
	 * to `toBytes()`.
	**/
	public static function run(v:Dynamic) {
		var s = new Serializer();
		s.serialize(v);
		return s.toBytes();
	}

	public static function runToHex(v:Dynamic):String {
		var s = new Serializer();
		s.serialize(v);
		return s.toString();
	}
}
