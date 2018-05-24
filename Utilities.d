// CS-4380 Virtual Machine Project 1

module Utilities;

import std.stdio;    // For STDIN, STDOUT, STDERR
import std.bitmanip; // For BitArray and Unions http://www.digitalmars.com/d/2.0/phobos/std_bitmanip.html
import std.conv;
import std.file;
import std.string;
import std.math;
import std.array;
import std.exception;

// Storage type of the ByteCode array
alias ubyte ByteCode;

// Storage type of the Directives.
alias sizediff_t   Directive;
// We may potentially need to store .INT directives differently than .BYT directives
alias ubyte Directive_Byte;
alias sizediff_t   Directive_Int;

// What data type for the registers?
alias sizediff_t Register;

struct AssemblyHeader {
public:
    // [0] = size
    // [1] = unused
    // [2] = program counter
    union
    {
        uint[3] data;
        ByteCode[3 * uint.sizeof] bytes;
    }
}

// Opcode Data structure. 
// The Union allows me to address the same bits in different ways
struct Instruction {
  // The sizes in the enum here need to add up to the number of bits of the type of 'value' below
  enum opcode_s = 6, mode_s = 2, op1_s = 24, op2_s = 32; 
  // All values should be
  alias ulong instruction_type;
  alias sizediff_t storage_type;
  alias uint opcode_type;
  // Each instruction needs to be stored and retrieved in different ways
  union {
    // Native type to store the data in
    instruction_type value;
    // Chop instructions into the appropriate number of the appropriate size to be stored in a byte array
    ByteCode bytes[instruction_type.sizeof / ByteCode.sizeof];
    // The bitfields are allocated starting from the least significant bit. 
    // i.e. 'op2' occupies the 'op2_s' number least significant bits of the bitfields storage. 
    mixin(bitfields!(
      opcode_type    , "opcode", opcode_s,
      storage_type   ,   "mode",   mode_s,
      storage_type   ,    "op1",    op1_s,
      storage_type   ,    "op2",    op2_s
      )
    );
  }
}

// A union that reinterprets any type T as an array of type ByteCode
union to_ByteCode(T) {
  T data;
  ByteCode bytes[T.sizeof / ByteCode.sizeof];
}

void print_Instruction(Instruction inst) {
  Valid_OpCodes valid_opcodes = new Valid_OpCodes;
  if((inst.opcode in valid_opcodes.to_string) == null)
    stderr.writef("print_Instruction: opcode(%d) %s, mode %d, op1 %d, op2 %d\nprint_Instruction: bytes ", inst.opcode, "", inst.mode, inst.op1, inst.op2);
  else
    stderr.writef("print_Instruction: opcode(%d) %s, mode %d, op1 %d, op2 %d\nprint_Instruction: bytes ", inst.opcode, valid_opcodes.to_string[inst.opcode], inst.mode, inst.op1, inst.op2);
  foreach(i, a; inst.bytes) {
    stderr.writef("%02x:", a);
  }
  stderr.writef("\nprint_Instruction: data %d\n", inst.value);
}

class Valid_Registers {
  //uint to_Register[string];
  // TODO: Verify that size_t is ok for a register size
  size_t to_Register[string];
  string to_string[size_t];
  bool read_only[string];
  const size_t length = 15;
  this() {
    to_Register["R0"] = 0;
    to_Register["R1"] = 1;
    to_Register["R2"] = 2;
    to_Register["R3"] = 3;
    to_Register["R3"] = 3;
    to_Register["R4"] = 4;
    to_Register["R5"] = 5;
    to_Register["R6"] = 6;
    to_Register["R7"] = 7;
    to_Register["PC"] = 8; // Program Counter
    to_Register["SL"] = 9; // Stack Limit
    to_Register["SB"] = 10; // Stack Base
    to_Register["SP"] = 11; // Stack Pointer
    to_Register["FP"] = 12; // Framce Pointer
    to_Register["OF"] = 13; // Offset into Memory
    to_Register["TC"] = 14; // Hardware Thread Count
    foreach(R, i; to_Register) {
      to_string[i] = R;
    }
    read_only["PC"] = true;
    read_only["SB"] = true;
    read_only["OF"] = true;
  }

  bool is_valid(string register) {
    auto reg = (register in to_Register);
    return reg != null;
  }
}

class Valid_OpCodes {
  uint to_OpCode[string];
  string to_string[uint];
  this() {
    // OpCode             // Addressing Mode
    to_OpCode["JMP"] = 1;  // Label
    to_OpCode["JMR"] = 2;  // RS
    to_OpCode["BNZ"] = 3;  // RS, Label
    to_OpCode["BGT"] = 4;  // RS, Label
    to_OpCode["BLT"] = 5;  // RS, Label
    to_OpCode["BRZ"] = 6;  // RS, Label
    to_OpCode["MOV"] = 7;  // RD, RS
    to_OpCode["LDA"] = 8;  // RD, Label
    to_OpCode["STR"] = 9;  // RS, Label
    to_OpCode["LDR"] = 10; // RD, Label
    to_OpCode["STB"] = 11; // RS, Label
    to_OpCode["LDB"] = 12; // RD, Label
    to_OpCode["ADD"] = 13; // RD, RS
    to_OpCode["ADI"] = 14; // RD, IMM
    to_OpCode["SUB"] = 15; // RD, RS
    to_OpCode["MUL"] = 16; // RD, RS
    to_OpCode["DIV"] = 17; // RD, RS
    to_OpCode["AND"] = 18; // RD, RS
    to_OpCode["OR"]  = 19; // RD, RS
    to_OpCode["CMP"] = 20; // RD, RS
    to_OpCode["TRP"] = 21; // IMM
    to_OpCode["RUN"] = 22; // RS, Label
    to_OpCode["END"] = 23; // Like TRP 0 for Threads
    to_OpCode["BLK"] = 24; // Main thread wait
    to_OpCode["LCK"] = 25; // Label
    to_OpCode["ULK"] = 26; // Label
    foreach(op, i; to_OpCode) {
      //writef("    valid_opcodes.to_string[%d] = %s\n", i, op);
      to_string[i] = op;
    }
  }
  bool is_valid(string opcode) {
    uint* op = (opcode in to_OpCode);
    return op != null;
  }
}

class Valid_Directives {
  ubyte to_Directive[string];
  this() {
    to_Directive[".BYT"] = Directive_Byte.sizeof;
    to_Directive[".INT"] = Directive_Int.sizeof;
  }

  bool is_valid(string directive) {
    auto dir = (directive in to_Directive);
    return dir != null;
  }
}

struct BitMap(T)
{
private:
    size_t _used;
    //ulong[32] value;
    T value;
public:
    @property 
    {
        size_t last_set_bit()
        {
            sizediff_t i = _used - 1;
            while(i > 0 && !this[i])
            {
                i--;
            }
            assert(range_check(i + 1, _used, false));
            return i;
        }

        void used(typeof(_used) u)
        {
            if(u <= this.max_used)
                _used = u;
            else
                throw(new Exception(format("Unable to set BitMap used value to [%d]. Maximum is [%d].", u, this.max_used)));
        }

        size_t used()
        {
            return _used;
        }

        size_t max_used()
        {
            return value.sizeof * 8;
        }
    }

    void opIndexAssign(bool v, size_t index)
    {
        if(index >= _used || index < 0)
            throw(new Exception(format("Index out of range [%d] / [%d].", index, _used)));
        ulong p_value = pow(2, to!(ulong)(index % (value[0].sizeof * 8)));
        //stderr.writef("opIndexAssign: %d=> [%d][%d] %s\n", index, index / (value[0].sizeof * 8), index % (value[0].sizeof * 8), v);
        if(v)
            value[index / (value[0].sizeof * 8)] |= p_value; // Set a bit
        else
            value[index / (value[0].sizeof * 8)] &= ~p_value; // Unset a bit
    }

    bool opIndex(size_t index)
    {
        enforce(index / (value[0].sizeof * 8) < value.length, format("Index out of range in bitmap[%d/%d]", index / (value[0].sizeof * 8), value.length));
        ulong p_value = pow(2, to!(ulong)(index % (value[0].sizeof * 8)));
        return ((value[index / (value[0].sizeof * 8)] & p_value) == p_value);
    }

    void opSliceAssign(bool v, size_t start, size_t end)
    {
        if(end >= this.max_used)
            throw(new Exception("Can't assign out of range"));
        //stderr.writef("OpSliceAssign: %d, %d, %s\n", start, end - 1, v);
        foreach(i; start..end)
            this[i] = v;
    }

    void opSliceAssign(bool v)
    {
        //stderr.writef("OpSliceAssign: %d, %d, %s\n", 0, _used - 1, v);
        foreach(i; 0.._used)
            this[i] = v;
    }

    string toString()
    {
        auto app =  appender!string();
        foreach(i; 0.._used) app.put(format("%d", this[i]));
        return app.data;
    }

    bool range_check(size_t start, size_t end, bool v)
    {
        bool retval = true;
        foreach(i; start..end)
            retval = retval && (this[i] == v);
        return retval;
    }
}

alias MemoryManagement DiskManagement;
struct MemoryManagement(T)
{
private:
    BitMap!(T) bitmap;
public:
    size_t _block_size;

    @property
    {
        size_t SL_pos() { 
            return (bitmap.last_set_bit + 1) * block_size; 
        }
        size_t used() { return bitmap.used; }
        void used(size_t u) { bitmap.used = u; }
        size_t max_used() { return bitmap.max_used; }
        size_t block_size() { return _block_size; }
        void block_size(size_t nbs) { _block_size = nbs; enforce(block_size >0, format("Tried to set block_size to %d", nbs)); }
    }

    void set(size_t pos)
    in
    {
        assert (block_size > 0);
        assert (pos % block_size == 0);
    }
    body
    {
        pos = (pos / block_size);
        bitmap[pos] = true;
    }

    //size_t allocate(size_t size)
    size_t allocate(size_t size, string file = __FILE__, int line = __LINE__)
    in
    {
        enforce(block_size > 0, format("[%d] %s: block_size = %d, which is not >0", line, file, block_size));
        assert (block_size > 0);
    }
    body
    {
        // Shrink the size to fit bitmap
        size = (size - 1) / block_size + 1;
        if(size >= bitmap.max_used)
        {
            stderr.writef("allocate: Tried to allocate more bits than can be managed [%d/%d]\n", size, bitmap.max_used);
            return 0;
        }
        size_t pos = 0;
        bool found;
        while(pos < bitmap.max_used - size && !found)
            if(bitmap.range_check(pos, pos + size, false))
                found = true;
            else
                pos++;
        enforce(found, "Bitmap is full!");
        bitmap[pos..pos+size] = true;
        return pos * block_size;
    }

    void free(size_t size, size_t pos)
    in
    {
        assert (block_size > 0);
        assert (pos % block_size == 0);
    }
    body
    {
        //stderr.writef("free: size[%d], pos[%d] block_size[%d].\n", size, pos, block_size);
        //stderr.writef("Free called with size [%d]\n", size);
        //stderr.writef("mod: %d\n", size % block_size);
        size = (size - 1) / block_size + 1;
        pos = (pos / block_size);
        if(pos + size >= bitmap.max_used)
            throw(new Exception(format("Out of bounds (Segfault) during free.\nTried to free [%d] bits at bit [%d] when max is [%d].", size, pos, bitmap.max_used)));
        //stderr.writef("Freeing [%d] bits at [%d].\n", size, pos);
        bitmap[pos..pos+size] = false;
    }

    size_t count(bool v)
    {
        size_t retval = 0;
        foreach(i; 0..bitmap.used)
        {
            if(bitmap[i] == v)
                retval++;
        }
        return retval;
    }

    string toString()
    {
        return format("%s", bitmap);
    }

}
