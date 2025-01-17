package binserializer;

import binserializer.Format;
import haxe.ds.List;
import haxe.io.Bytes;

@:noDoc
typedef TypeResolver = {
	function resolveClass(name:String):Class<Dynamic>;
	function resolveEnum(name:String):Enum<Dynamic>;
}

class Unserializer {
	public static var DEFAULT_RESOLVER:TypeResolver = new DefaultResolver();

	var buf:Bytes;
	var pos:Int;
	var length:Int;
	var cache:Array<Dynamic>;
	var scache:Array<String>;
	var resolver:TypeResolver;
	#if neko
	var upos:Int;
	#end

	/**
		Creates a new Unserializer instance, with its internal buffer
		initialized to `buf`.

		This does not parse `buf` immediately. It is parsed only when calls to
		`this.unserialize` are made.

		Each Unserializer instance maintains its own cache.
	**/
	public function new(buf:Bytes) {
		this.buf = buf;
		length = this.buf.length;
		pos = 0;
		#if neko
		upos = 0;
		#end
		scache = new Array();
		cache = new Array();
		var r = DEFAULT_RESOLVER;
		if (r == null) {
			r = new DefaultResolver();
			DEFAULT_RESOLVER = r;
		}
		resolver = r;
	}

	public inline function getInt16(pos:Int):Int {
		var res = buf.getUInt16(pos);
		if (res > 32767)
			res -= 65536;
		return res;
	}

	/**
		Sets the type resolver of `this` Unserializer instance to `r`.

		If `r` is `null`, a special resolver is used which returns `null` for all
		input values.

		See `DEFAULT_RESOLVER` for more information on type resolvers.
	**/
	public function setResolver(r) {
		if (r == null)
			resolver = NullResolver.instance;
		else
			resolver = r;
	}

	/**
		Gets the type resolver of `this` Unserializer instance.

		See `DEFAULT_RESOLVER` for more information on type resolvers.
	**/
	public function getResolver() {
		return resolver;
	}

	inline function get(p:Int):ByteUInt {
		return buf.get(p);
	}

	function unserializeObject(o:Dynamic) {
		while (true) {
			if (pos >= length)
				throw "Invalid object";
			if (get(pos) == SerializedFormat.END)
				break;
			var k:Dynamic = unserialize();
			if (!Std.isOfType(k, String))
				throw "Invalid object key";
			var v = unserialize();
			Reflect.setField(o, k, v);
		}
		pos++;
	}

	function unserializeEnum<T>(edecl:Enum<T>, tag:String) {
		var args:Array<Dynamic> = [];
		while (true) {
			var byte = get(pos);
			if (byte == SerializedFormat.END) {
				pos++;
				break;
			}
			args.push(unserialize());
		}
		if (args.length == 0)
			return Type.createEnum(edecl, tag);
		return Type.createEnum(edecl, tag, args);
	}

	inline function advanceAndPrev(amt:Int):Int {
		var opos = this.pos;
		this.pos += amt;
		return opos;
	}

	public function getInt():Int {
		return switch (get(pos++)) {
			case INT8: get(pos++);
			case INT16: buf.getUInt16(advanceAndPrev(2));
			case INT32: buf.getInt32(advanceAndPrev(4));
			default: throw "Invalid data, expected int";
		}
	}

	public function getIntCustom(int8:SerializedFormat, int16:SerializedFormat, int32:SerializedFormat):Int {
		var byte = get(pos++);
		if (byte == int8)
			return get(pos++);
		if (byte == int16)
			return buf.getUInt16(advanceAndPrev(2));
		if (byte == int32)
			return buf.getInt32(advanceAndPrev(4));
		throw "Invalid data, expected int";
	}

	/**
		Unserializes the next part of `this` Unserializer instance and returns
		the according value.

		This function may call `this.resolver.resolveClass` to determine a
		Class from a String, and `this.resolver.resolveEnum` to determine an
		Enum from a String.

		If `this` Unserializer instance contains no more or invalid data, an
		exception is thrown.

		This operation may fail on structurally valid data if a type cannot be
		resolved or if a field cannot be set. This can happen when unserializing
		Strings that were serialized on a different Haxe target, in which the
		serialization side has to make sure not to include platform-specific
		data.

		Classes are created from `Type.createEmptyInstance`, which means their
		constructors are not called.
	**/
	public function unserialize():Dynamic {
		var byte:SerializedFormat = get(pos++);
		switch (byte) {
			case NULL:
				return null;
			case TRUE:
				return true;
			case FALSE:
				return false;
			case ZERO:
				return 0;
			case INT8:
				return get(pos++);
			case INT16:
				return buf.getUInt16(advanceAndPrev(2));
			case INT32:
				return buf.getInt32(advanceAndPrev(4));
			case INT64:
				return buf.getInt64(advanceAndPrev(8));
			case FLOAT:
				return buf.getDouble(advanceAndPrev(8));
			case SINGLE:
				return buf.getFloat(advanceAndPrev(4));
			case NEG_INT8:
				return -get(pos++);
			case NEG_INT16:
				return -buf.getUInt16(advanceAndPrev(2));
			case STRING_8 | STRING_16 | STRING_32:
				pos--;
				var len = getIntCustom(STRING_8, STRING_16, STRING_32);
				var buf = buf;
				if (len < 0 || pos + len > length)
					throw "Invalid string length";
				var s = buf.sub(pos, len).toString();
				pos += len;
				scache.push(s);
				return s;
			case NAN:
				return Math.NaN;
			case POSITIVE_INFINITY:
				return Math.POSITIVE_INFINITY;
			case NEGATIVE_INFINITY:
				return Math.NEGATIVE_INFINITY;
			case PI:
				return Math.PI;
			case ARRAY:
				var a = new Array<Dynamic>();
				#if cpp
				var cachePos = cache.length;
				#end
				cache.push(a);
				while (true) {
					var c = get(pos);
					if (c == SerializedFormat.END) {
						pos++;
						break;
					}
					if (pos >= length)
						throw "No END found";
					if (c == SerializedFormat.EMPTY_SPACE_8
						|| c == SerializedFormat.EMPTY_SPACE_16
						|| c == SerializedFormat.EMPTY_SPACE_32) {
						var n = getIntCustom(EMPTY_SPACE_8, EMPTY_SPACE_16, EMPTY_SPACE_32);
						a[a.length + n - 1] = null;
					}
					else {
						var v = unserialize();
						a.push(v);
					}
				}
				#if cpp
				return cache[cachePos] = cpp.NativeArray.resolveVirtualArray(a);
				#else
				return a;
				#end

			case OBJECT:
				var o:Dynamic = {};
				cache.push(o);
				unserializeObject(o);
				return o;

			case OBJECT_REF_8 | OBJECT_REF_16 | OBJECT_REF_32:
				pos--;
				var n = getIntCustom(OBJECT_REF_8, OBJECT_REF_16, OBJECT_REF_32);
				if (n < 0 || n >= cache.length)
					throw "Invalid reference";
				return cache[n];

			case STRING_REF_8 | STRING_REF_16 | STRING_REF_32:
				pos--;
				var n = getIntCustom(STRING_REF_8, STRING_REF_16, STRING_REF_32);
				if (n < 0 || n >= scache.length)
					throw "Invalid string reference";
				return scache[n];

			case EXCEPTION:
				throw unserialize();

			case CLASS_INSTANCE:
				var name = unserialize();
				var cl = resolver.resolveClass(name);
				if (cl == null)
					throw "Class not found " + name;
				var o = Type.createEmptyInstance(cl);
				cache.push(o);
				unserializeObject(o);
				return o;

			case ENUM_INSTANCE:
				var name = unserialize();
				var edecl = resolver.resolveEnum(name);
				if (edecl == null)
					throw "Enum not found " + name;
				var e = unserializeEnum(edecl, unserialize());
				cache.push(e);
				return e;

			case LIST:
				var l = new List();
				cache.push(l);
				var buf = buf;
				while (get(pos) != SerializedFormat.END)
					l.add(unserialize());
				pos++;
				return l;

			case STRING_MAP:
				var h = new haxe.ds.StringMap();
				cache.push(h);
				while (get(pos) != SerializedFormat.END) {
					var s = unserialize();
					var v = unserialize();
					h.set(s, v);
				}
				pos++;
				return h;

			case INT_MAP:
				var h = new haxe.ds.IntMap();
				cache.push(h);
				while (get(pos) != SerializedFormat.END) {
					var s = unserialize();
					var v = unserialize();
					h.set(s, v);
				}
				pos++;
				return h;

			case OBJECT_MAP:
				var h = new haxe.ds.ObjectMap();
				cache.push(h);
				while (get(pos) != SerializedFormat.END) {
					var s = unserialize();
					var v = unserialize();
					h.set(s, v);
				}
				pos++;
				return h;

			case ENUM_MAP:
				var h = new haxe.ds.EnumValueMap<Dynamic, Dynamic>();
				cache.push(h);
				while (get(pos) != SerializedFormat.END) {
					var s = unserialize();
					var v = unserialize();
					h.set(s, v);
				}
				pos++;
				return h;

			case DATE:
				// TODO: figure out a better way
				var d = Date.fromTime(buf.getDouble(advanceAndPrev(8)));
				cache.push(d);
				return d;

			case BYTES:
				var len = getInt();
				var buf = buf;
				if (len < 0 || pos + len > length)
					throw "Invalid bytes length";
				var bytes = buf.sub(pos, len);
				pos += len;
				cache.push(bytes);
				return bytes;
			case CLASS_TYPE:
				var name = unserialize();
				var cl = resolver.resolveClass(name);
				if (cl == null)
					throw "Class not found " + name;
				return cl;

			case ENUM_TYPE:
				var name = unserialize();
				var edecl = resolver.resolveEnum(name);
				if (edecl == null)
					throw "Enum not found " + name;
				return edecl;

			case NEG_ONE:
				return -1;

			// Stuff for parsing
			case EMPTY_SPACE_8:
			case EMPTY_SPACE_16:
			case EMPTY_SPACE_32:
			case END:
		}

		pos--;
		throw("Invalid byte " + StringTools.hex(buf.get(pos), 2) + " at position " + pos);

		/*switch (get(pos++)) {
			case "n".code:
				return null;
			case "t".code:
				return true;
			case "f".code:
				return false;
			case "z".code:
				return 0;
			case "i".code:
				return readDigits();
			case "d".code:
				return readFloat();
			case "y".code:
				var len = readDigits();
				if (get(pos++) != ":".code || length - pos < len)
					throw "Invalid string length";
				var s = buf.fastSubstr(pos, len);
				pos += len;
				s = StringTools.urlDecode(s);
				scache.push(s);
				return s;
			case "k".code:
				return Math.NaN;
			case "m".code:
				return Math.NEGATIVE_INFINITY;
			case "p".code:
				return Math.POSITIVE_INFINITY;
			case "a".code:
				var buf = buf;
				var a = new Array<Dynamic>();
				#if cpp
				var cachePos = cache.length;
				#end
				cache.push(a);
				while (true) {
					var c = get(pos);
					if (c == "h".code) {
						pos++;
						break;
					}
					if (c == "u".code) {
						pos++;
						var n = readDigits();
						a[a.length + n - 1] = null;
					} else
						a.push(unserialize());
				}
				#if cpp
				return cache[cachePos] = cpp.NativeArray.resolveVirtualArray(a);
				#else
				return a;
				#end
			case "o".code:
				var o = {};
				cache.push(o);
				unserializeObject(o);
				return o;
			case "r".code:
				var n = readDigits();
				if (n < 0 || n >= cache.length)
					throw "Invalid reference";
				return cache[n];
			case "R".code:
				var n = readDigits();
				if (n < 0 || n >= scache.length)
					throw "Invalid string reference";
				return scache[n];
			case "x".code:
				throw unserialize();
			case "c".code:
				var name = unserialize();
				var cl = resolver.resolveClass(name);
				if (cl == null)
					throw "Class not found " + name;
				var o = Type.createEmptyInstance(cl);
				cache.push(o);
				unserializeObject(o);
				return o;
			case "w".code:
				var name = unserialize();
				var edecl = resolver.resolveEnum(name);
				if (edecl == null)
					throw "Enum not found " + name;
				var e = unserializeEnum(edecl, unserialize());
				cache.push(e);
				return e;
			case "j".code:
				var name = unserialize();
				var edecl = resolver.resolveEnum(name);
				if (edecl == null)
					throw "Enum not found " + name;
				pos++; // skip ':'
				var index = readDigits();
				var tag = Type.getEnumConstructs(edecl)[index];
				if (tag == null)
					throw "Unknown enum index " + name + "@" + index;
				var e = unserializeEnum(edecl, tag);
				cache.push(e);
				return e;
			case "l".code:
				var l = new List();
				cache.push(l);
				var buf = buf;
				while (get(pos) != "h".code)
					l.add(unserialize());
				pos++;
				return l;
			case "b".code:
				var h = new haxe.ds.StringMap();
				cache.push(h);
				var buf = buf;
				while (get(pos) != "h".code) {
					var s = unserialize();
					h.set(s, unserialize());
				}
				pos++;
				return h;
			case "q".code:
				var h = new haxe.ds.IntMap();
				cache.push(h);
				var buf = buf;
				var c = get(pos++);
				while (c == ":".code) {
					var i = readDigits();
					h.set(i, unserialize());
					c = get(pos++);
				}
				if (c != "h".code)
					throw "Invalid IntMap format";
				return h;
			case "M".code:
				var h = new haxe.ds.ObjectMap();
				cache.push(h);
				var buf = buf;
				while (get(pos) != "h".code) {
					var s = unserialize();
					h.set(s, unserialize());
				}
				pos++;
				return h;
			case "v".code:
				var d;
				if (get(pos) >= '0'.code && get(pos) <= '9'.code && get(pos + 1) >= '0'.code && get(pos + 1) <= '9'.code && get(pos + 2) >= '0'.code
					&& get(pos + 2) <= '9'.code && get(pos + 3) >= '0'.code && get(pos + 3) <= '9'.code && get(pos + 4) == '-'.code) {
					// Included for backwards compatibility
					d = Date.fromString(buf.fastSubstr(pos, 19));
					pos += 19;
				} else
					d = Date.fromTime(readFloat());
				cache.push(d);
				return d;
			case "s".code:
				var len = readDigits();
				var buf = buf;
				if (get(pos++) != ":".code || length - pos < len)
					throw "Invalid bytes length";
				#if neko
				var bytes = haxe.io.Bytes.ofData(base_decode(untyped buf.fastSubstr(pos, len).__s, untyped BASE64.__s));
				#elseif php
				var phpEncoded = php.Global.strtr(buf.fastSubstr(pos, len), '%:', '+/');
				var bytes = haxe.io.Bytes.ofData(php.Global.base64_decode(phpEncoded));
				#else
				var codes = CODES;
				if (codes == null) {
					codes = initCodes();
					CODES = codes;
				}
				var i = pos;
				var rest = len & 3;
				var size = (len >> 2) * 3 + ((rest >= 2) ? rest - 1 : 0);
				var max = i + (len - rest);
				var bytes = haxe.io.Bytes.alloc(size);
				var bpos = 0;
				while (i < max) {
					var c1 = codes[StringTools.fastCodeAt(buf, i++)];
					var c2 = codes[StringTools.fastCodeAt(buf, i++)];
					bytes.set(bpos++, (c1 << 2) | (c2 >> 4));
					var c3 = codes[StringTools.fastCodeAt(buf, i++)];
					bytes.set(bpos++, (c2 << 4) | (c3 >> 2));
					var c4 = codes[StringTools.fastCodeAt(buf, i++)];
					bytes.set(bpos++, (c3 << 6) | c4);
				}
				if (rest >= 2) {
					var c1 = codes[StringTools.fastCodeAt(buf, i++)];
					var c2 = codes[StringTools.fastCodeAt(buf, i++)];
					bytes.set(bpos++, (c1 << 2) | (c2 >> 4));
					if (rest == 3) {
						var c3 = codes[StringTools.fastCodeAt(buf, i++)];
						bytes.set(bpos++, (c2 << 4) | (c3 >> 2));
					}
				}
				#end
				pos += len;
				cache.push(bytes);
				return bytes;
			case "C".code:
				var name = unserialize();
				var cl = resolver.resolveClass(name);
				if (cl == null)
					throw "Class not found " + name;
				var o:Dynamic = Type.createEmptyInstance(cl);
				cache.push(o);
				o.hxUnserialize(this);
				if (get(pos++) != "g".code)
					throw "Invalid custom data";
				return o;
			case "A".code:
				var name = unserialize();
				var cl = resolver.resolveClass(name);
				if (cl == null)
					throw "Class not found " + name;
				return cl;
			case "B".code:
				var name = unserialize();
				var e = resolver.resolveEnum(name);
				if (e == null)
					throw "Enum not found " + name;
				return e;
			default:
		}*/
	}

	/**
		Unserializes `v` and returns the according value.

		This is a convenience function for creating a new instance of
		Unserializer with `v` as buffer and calling its `unserialize()` method
		once.
	**/
	public static function run(v:Bytes):Dynamic {
		return new Unserializer(v).unserialize();
	}
}

private class DefaultResolver {
	public function new() {
	}

	public inline function resolveClass(name:String):Class<Dynamic>
		return Type.resolveClass(name);

	public inline function resolveEnum(name:String):Enum<Dynamic>
		return Type.resolveEnum(name);
}

private class NullResolver {
	function new() {
	}

	public inline function resolveClass(name:String):Class<Dynamic>
		return null;

	public inline function resolveEnum(name:String):Enum<Dynamic>
		return null;

	public static var instance(get, null):NullResolver;

	inline static function get_instance():NullResolver {
		if (instance == null)
			instance = new NullResolver();
		return instance;
	}
}
