package binserializer;

typedef ByteInt = #if cpp cpp.Int8 #else Int #end;
typedef ByteUInt = #if cpp cpp.UInt8 #else UInt #end;
typedef ShortInt = #if cpp cpp.Int16 #else Int #end;
typedef ShortUInt = #if cpp cpp.UInt16 #else UInt #end;

// The data is stored in little endian

enum abstract SerializedFormat(ByteUInt) from ByteUInt to ByteUInt {
	var NULL = 0x00;
	var TRUE = 0x01;
	var FALSE = 0x02;
	var ZERO = 0x03;
	var INT8 = 0x04;
	var INT16 = 0x05;
	var INT32 = 0x06;
	var INT64 = 0x07;
	var FLOAT = 0x08;
	var SINGLE = 0x09;
	var STRING_8 = 0x0a;
	var STRING_16 = 0x0b;
	var STRING_32 = 0x0c;
	var NAN = 0x0d;
	var POSITIVE_INFINITY = 0x0e;
	var NEGATIVE_INFINITY = 0x0f;
	var ARRAY = 0x10;
	var OBJECT = 0x11;
	var OBJECT_REF_8 = 0x12;
	var OBJECT_REF_16 = 0x13;
	var OBJECT_REF_32 = 0x14;
	var STRING_REF_8 = 0x15;
	var STRING_REF_16 = 0x16;
	var STRING_REF_32 = 0x17;
	var EXCEPTION = 0x18;
	var CLASS_INSTANCE = 0x19;
	var ENUM_INSTANCE = 0x1a;
	var LIST = 0x1b;
	var STRING_MAP = 0x1c;
	var INT_MAP = 0x1d;
	var OBJECT_MAP = 0x1e;
	var ENUM_MAP = 0x1f; // Custom for this serializer
	var DATE = 0x20;
	var BYTES = 0x21;
	// No custom class parsing
	var CLASS_TYPE = 0x22;
	var ENUM_TYPE = 0x23;
	var NEG_ONE = 0x24;
	var PI = 0x25;
	var NEG_INT8 = 0x26;
	var NEG_INT16 = 0x27;

	var EMPTY_SPACE_8 = 0xFC;
	var EMPTY_SPACE_16 = 0xFD;
	var EMPTY_SPACE_32 = 0xFE;
	var END = 0xFF;
}
