#pragma author Ne_Eo
#pragma description Haxe Binary Serializer
#pragma magic [43 4e 45 53 41 56 45 76 31 3a] @ 0x00
#pragma endian little

import std.math;
import std.core;
import type.time;
import type.magic;

using SerializedFormat;

// TODO:
// - Show date as human readable
// - Show the format of refs as the actual value

enum Type : u8 {
	Null             = 0x00,
	True             = 0x01,
	False            = 0x02,
	Zero             = 0x03,
	Int8             = 0x04,
	Int16            = 0x05,
	Int32            = 0x06,
	Int64            = 0x07,
	Float            = 0x08,
	Single           = 0x09,
	NaN              = 0x0A,
	PositiveInfinity = 0x0B,
	NegativeInfinity = 0x0C,
	PI               = 0x0D,
	String8          = 0x0E,
	String16         = 0x0F,
	String32         = 0x10,
	Array            = 0x11,
	Object           = 0x12,
	ObjectRef8       = 0x13,
	ObjectRef16      = 0x14,
	ObjectRef32      = 0x15,
	StringRef8       = 0x16,
	StringRef16      = 0x17,
	StringRef32      = 0x18,
	Exception        = 0x19,
	ClassInstance    = 0x1A,
	EnumInstance     = 0x1B,
	List             = 0x1C,
	StringMap        = 0x1D,
	IntMap           = 0x1E,
	ObjectMap        = 0x1F,
	EnumMap          = 0x20,
	Date             = 0x21,
	Bytes            = 0x22,
	ClassType        = 0x23,
	EnumType         = 0x24,
	NegOne           = 0x25,
	NegInt8          = 0x26,
	NegInt16         = 0x27,
	EmptySpace8      = 0xFC,
	EmptySpace16     = 0xFD,
	EmptySpace32     = 0xFE,
	End              = 0xFF,
};

struct Int {
	Type type;

	if (type == Type::Int8) {
		u8 int;
	}
	else if (type == Type::Int16) {
		u16 int;
	}
	else if (type == Type::Int32) {
		u32 int;
	}
	//else if (type == Type::Int64) {
	//    Int64 int;
	//}
};

u8 indent = 0;

fn print_indent(u32 indent, auto dd) {
	str indent_string = " " * indent;
	std::print(indent_string + string(dd));
};

fn string(auto dd) {
	return std::format("{}", dd);
};

struct String8 {
	u8 length [[hidden]];
	char value[length];

	print_indent(indent, std::format("STRING {}", value));
} [[sealed, format("format_string")]];

struct String16 {
	u16 length [[hidden]];
	char value[length];

	print_indent(indent, std::format("STRING16"));
} [[sealed, format("format_string")]];

struct String32 {
	u32 length [[hidden]];
	char value[length];

	print_indent(indent, std::format("STRING32"));
} [[sealed, format("format_string")]];

struct String {
	Type type;

	if (type == Type::String8) {
		String8 string;
	}
	else if (type == Type::String16) {
		String16 string;
	}
	else if (type == Type::String32) {
		String32 string;
	}
};

using StringRef;

union StringUnion {
	String _str;
	StringRef _ref;
} [[ format("format_string_union") ]];

fn format_string(auto string) {
	return string.value;
};
fn format_string2(auto string) {
	return string._str.string.value;
};

fn format_string_union(auto string) {
	if (string._str.type == Type::String8) {
		return string._str.string;
	}
	else if (string._str.type == Type::String16) {
		return string._str.string;
	}
	else if (string._str.type == Type::String32) {
		return string._str.string;
	}
	else {
		return format_ref(string._ref.reference);
	}
};

struct Array {
	SerializedFormat data[while($[$] != Type::End)] [[inline]];
	$ += 1; // skip END
};

fn format_field(auto field) {
	return std::format("{}: {}", field.key, field.value);
};

struct FieldListing {
	StringUnion key [[sealed, format("format_string_union")]];
	SerializedFormat value;
} [[format("format_field")]];


struct Object {
	FieldListing data[while($[$] != Type::End)] [[inline]];
	$ += 1; // skip END
};

fn format_ref(auto reference) {
	return std::format("REF({})", reference.index);
};

struct ObjectRef8 {
	u8 index;
} [[sealed, format("format_ref")]];

struct ObjectRef16 {
	u16 index;
} [[sealed, format("format_ref")]];

struct ObjectRef32 {
	u32 index;
} [[sealed, format("format_ref")]];

struct StringRef8 {
	u8 index;
};

struct StringRef16 {
	u16 index;
};

struct StringRef32 {
	u32 index;
};

struct StringRef {
	Type type;

	if (type == Type::StringRef8) {
		StringRef8 reference;
	}
	else if (type == Type::StringRef16) {
		StringRef16 reference;
	}
	else if (type == Type::StringRef32) {
		StringRef32 reference;
	}
};

struct ClassInstance {
	StringUnion name [[sealed, format("format_string2")]];
	FieldListing data[while($[$] != Type::End)];
	$ += 1; // skip END
};

struct EnumInstance {
	StringUnion name [[sealed, format("format_string2")]];
	StringUnion tag [[sealed, format("format_string2")]];
	SerializedFormat data[while($[$] != Type::End)];
	$ += 1; // skip END
};

struct List {
	SerializedFormat data[while($[$] != Type::End)] [[inline]];
	$ += 1; // skip END
};

struct StringMapEntry {
	StringUnion key [[sealed, format("format_string2")]];
	SerializedFormat value;
};

struct StringMap {
	StringMapEntry data[while($[$] != Type::End)] [[inline]];
	$ += 1; // skip END
};

struct IntMapEntry {
	Int key;
	SerializedFormat value;
};

struct IntMap {
	IntMapEntry data[while($[$] != Type::End)] [[inline]];
	$ += 1; // skip END
};

struct ObjectMapEntry {
	SerializedFormat key;
	SerializedFormat value;
};

struct ObjectMap {
	ObjectMapEntry data[while($[$] != Type::End)] [[inline]];
	$ += 1; // skip END
};

struct EnumMapEntry {
	SerializedFormat key;
	SerializedFormat value;
};

struct EnumMap {
	EnumMapEntry data[while($[$] != Type::End)] [[inline]];
	$ += 1; // skip END
};

fn double_to_time (double val){
	return type::impl::format_time_t(val);
};

struct Bytes {
	Int length [[hidden]];
	u8 value[length];
} [[sealed]];

struct SerializedFormat {
	Type type;

	print_indent(indent, type);
	indent += 1;

	if (type == Type::Null) {
		/*Null null;*/
	} else if (type == Type::True) {
		//true;
	} else if (type == Type::False) {
		//false;
	} else if (type == Type::Zero) {
		//0;
	} else if (type == Type::Int8) {
		u8 int;
	} else if (type == Type::Int16) {
		u16 int;
	} else if (type == Type::Int32) {
		u32 int;
	} else if (type == Type::Int64) {
		u64 int;
	} else if (type == Type::Float) {
		double value ;
	} else if (type == Type::Single) {
		float value;
	} else if (type == Type::NaN) {
	} else if (type == Type::PositiveInfinity) {
	} else if (type == Type::NegativeInfinity) {
	} else if (type == Type::PI) {
	} else if (type == Type::String8) {
		String8 string;
	} else if (type == Type::String16) {
		String16 string;
	} else if (type == Type::String32) {
		String32 string;
	} else if (type == Type::Array) {
		Array array;
	} else if (type == Type::Object) {
		Object object;
	} else if (type == Type::ObjectRef8) {
		ObjectRef8 _ref [[inline]];
	} else if (type == Type::ObjectRef16) {
		ObjectRef16 _ref [[inline]];
	} else if (type == Type::ObjectRef32) {
		ObjectRef32 _ref [[inline]];
	} else if (type == Type::StringRef8) {
		StringRef8 _ref [[inline]];
	} else if (type == Type::StringRef16) {
		StringRef16 _ref [[inline]];
	} else if (type == Type::StringRef32) {
		StringRef32 _ref [[inline]];
	} else if (type == Type::Exception) {
		SerializedFormat exception;
	} else if (type == Type::ClassInstance) {
		ClassInstance classInstance;
	} else if (type == Type::EnumInstance) {
		EnumInstance enumInstance;
	} else if (type == Type::List) {
		List list;
	} else if (type == Type::StringMap) {
		StringMap stringMap;
	} else if (type == Type::IntMap) {
		IntMap intMap;
	} else if (type == Type::ObjectMap) {
		ObjectMap objectMap;
	} else if (type == Type::EnumMap) {
		EnumMap enumMap;
	} else if (type == Type::Date) {
		double date; // todo: convert into readable date
	} else if (type == Type::Bytes) {
		Bytes bytes;
	} else if (type == Type::ClassType) {
		StringUnion classType;
	} else if (type == Type::EnumType) {
		StringUnion enumType;
	} else if (type == Type::NegOne) {
		//-1;
	} else if (type == Type::NegInt8) {
		u8 negInt;
	} else if (type == Type::NegInt16) {
		u16 negInt;
	} else if (type == Type::EmptySpace8) {
		u8 emptySpace;
	} else if (type == Type::EmptySpace16) {
		u16 emptySpace;
	} else if (type == Type::EmptySpace32) {
		u32 emptySpace;
	}
	indent -= 1;
};

struct v1magic {
	type::Magic<"CNESAVE"> magic;
	char version[2];
	type::Magic<":"> colon [[hidden]];
};

struct File {
	try {
		v1magic magic;
		SerializedFormat ddd [[inline]];
	} catch {
		SerializedFormat ddd [[inline]];
	}
};

File file @0x00 [[inline]];