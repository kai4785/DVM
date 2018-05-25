import std.stdio;
import std.bitmanip;
import std.string;
import std.exception;
import std.math;
import std.conv;

import Utilities;

ByteCode memory[64];
BitMap bits1;
BitMap bits2;
to_ByteCode!(typeof(bits1)) bytes1;
to_ByteCode!(typeof(bits2)) bytes2;

void main()
{
    // Set up bitmap
    bits1.used = bits1.max_used;
    bits1[0] = true;
    bits1[2] = true;
    bits1[10..100] = true;
    bits1[30..41] = false;
    assert(bits1.range_check(0,1, true));
    assert(bits1.range_check(10,30, true));
    assert(bits1.range_check(30,41, false));
    assert(bits1.range_check(41,100, true));

    //Print first bitmap
    writef("%s\n", "bits1:");
    writef("%s [%s]\n", "bits1:", bits1);

    // To Memory
    bytes1.data = bits1;
    memory[0..bytes1.bytes.length] = bytes1.bytes[0..$];

    // From Memory -- Where the Magic happens
    bytes2.bytes[0..$] = memory[0..bytes2.bytes.length];
    bits2 = bytes2.data;

    // Print second bitmap, should be same as first
    writef("%s [%s]\n", "bits2:", bits2);

    bits1[] = false;
    writef("%s [%s]\n", "bits1:", bits1);
    writef("%s [%s]\n", "bits2:", bits2);
    assert(bits1 != bits2);

    writef("%d %d\n", bits1.sizeof, bits2.sizeof);
    writef("%d %d\n", bits1.max_used, bits2.max_used);

    size_t start;
    start = bits1.allocate(10);
    writef("Allocated 10 at position %d [%s]\n", start, bits1);
    start = bits1.allocate(10);
    writef("Allocated 10 at position %d [%s]\n", start, bits1);
    start = bits1.allocate(10);
    writef("Allocated 10 at position %d [%s]\n", start, bits1);
    bits1.free(5, 10);
    writef("Freed 5 at position 10 [%s]\n", bits1);
    start = bits1.allocate(10);
    writef("Allocated 10 at position %d [%s]\n", start, bits1);
}
