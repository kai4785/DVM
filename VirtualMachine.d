// CS-4380 Virtual Machine Project 1

module VirtualMachine;

import std.stdio;    // For STDIN, STDOUT, STDERR
import std.file;
import std.conv;
import std.string;
import std.exception;
import core.stdc.string : memcpy;

import Utilities;
import Assembler;

//debug = instruction;
//debug = run;
//debug = threads;
//debug = memory_access;
//debug = vmemory_access;
//debug = paging;
//debug = load;
version = VIRTUALMEMORY;

class Thread {
private:
    uint _id;
    uint _SL;
    uint _SB;
    this() {}
public:
    this(uint i, uint L, uint a) {
        _id = i;
        _SL = L;
        _SB = a;
        debug(threads) stderr.writef("Adding thread id %d\n", _id);
    }
    @property uint id() { return _id; }
    @property uint SB() { return _SB; }
    @property uint SL() { return _SL; }
    //@property void SB(uint a) { _addr = a ; }
}

struct VirtualMemory
{
    enum PAGE_SIZE = 512;
    enum offset_bits = 9;
    enum page_bits = (size_t.sizeof * 8) - offset_bits;
    ByteCode[] memory;
    size_t _virt_length;
    int[size_t] pages;
    size_t[size_t] page_used;
    ByteCode[PAGE_SIZE][size_t] swap;
    @property 
    {
        size_t length()
        {
            return _virt_length;
        }
        void length(size_t new_length)
        {
            enforce(memory.length == 0, "Memory limit of the VM can only be set once.");
            enforce(new_length % 1024 == 0, "VM memory needs to be a multiple of 1024.");
            memory.length = new_length;
            _virt_length = new_length;
            writef("Number of pages: [%d=%d*%d=%d]\n", new_length, new_length >> 9, PAGE_SIZE, (new_length >> 9) * PAGE_SIZE);
            foreach(num; 0.._virt_length>>9)
            {
                pages[num] = to!(int)(num * PAGE_SIZE);
                page_used[num] = 0;
            }
        }
        size_t virt_length()
        {
            return _virt_length;
        }
        void virt_length(size_t nvl)
        {
            enforce(nvl % 1024 == 0, "Virtual Memory needs to be a multiple of 1024.");
            enforce(nvl >= memory.length, "Can't set virtual memory size less than physical memory.");
            _virt_length = nvl;
            writef("Number of new pages: [%d=%d*%d=%d]\n", nvl - memory.length, (nvl - memory.length) >> 9, PAGE_SIZE, ((nvl - memory.length) >> 9) * PAGE_SIZE);
            stderr.writef("Starting at %d, going to %d\n", pages.length, nvl>>9);
            foreach(num; pages.length..nvl>>9)
            {
                pages[num] = to!(int)(int.max - num);
                page_used[num] = 0;
            }
        }
    }

    size_t least_used_page()
    {
        size_t least_used = size_t.max;
        foreach(key; pages.keys)
        {
            if(pages[key] >= 0)
            {
                if (least_used == size_t.max || page_used[key] < page_used[least_used])
                {
                   least_used = key;
                }
            }
        }
        foreach(key, value; page_used)
        {
            page_used[key] = 0;
        }
        return least_used;
    }

    size_t unused_swapped_page()
    {
        size_t unused_swap = size_t.max;
        foreach(key; pages.keys)
        {
            if(pages[key] < 0)
            {
                if((to!(size_t)(pages[key] * -1) in swap) is null)
                {
                    unused_swap = key;
                    break;
                }
            }
        }
        return unused_swap;
    }

    size_t virt2phys(size_t index)
    {
        // To get the index of the page, we need to shift off the offset bits
        // page_index = index >> offset_bits
        // To get the offset, we can do a bitwise AND with the result of math.pow(2, page_bits) - 1, or we can just do two shifts to knock off those bits
        // offset = index << page_bits >> page_bits;
        page_used[index >> offset_bits] += 1;
        enforce(index >> offset_bits < pages.length, format("Page requested out of bounds: [%d/%d]", index >> offset_bits, pages.length));
        if(pages[index >> offset_bits] < 0)
        {
            stderr.writef("PAGE_FAULT!\n");
            debug(paging)
            {
                stderr.writef("Pages: ");
                foreach(key; pages.keys.sort)
                {
                    stderr.writef("[%s:%s]", key, pages[key]);
                }
                stderr.writef("\n");
                stderr.writef("Page_used: ");
                foreach(key; page_used.keys.sort)
                {
                    stderr.writef("[%s:%s]", key, page_used[key]);
                }
                stderr.writef("\n");
                stderr.writef("Swap_used: ");
                foreach(key; swap.keys.sort)
                {
                    stderr.writef("[%s]", key);
                }
                stderr.writef("\n");
            }
            size_t need = index >> offset_bits;
            debug(paging)
                stderr.writef("PAGE_FAULT: virt[%d] page_needed[%d] swap[%d] ", index, index >> offset_bits, pages[index >> offset_bits]);
            // Find Least Used page
            size_t least_used = least_used_page();
            debug(paging)
                stderr.writef("least_used[%d] phy[%d] ", least_used, pages[least_used]);
            // Find an unused location in Swap
            size_t unused_swap = unused_swapped_page();
            enforce(unused_swap != size_t.max, "Memory manager shouldn't depend on paging to determine if we are out of memory");
            debug(paging)
                stderr.writef("unused_swap[%d](%d) ", unused_swap, pages[unused_swap]);
            // Swap out
            ByteCode[PAGE_SIZE] tmp;
            tmp[0..$] = memory[pages[least_used]..pages[least_used]+PAGE_SIZE];
            swap[to!(size_t)(pages[unused_swap] * -1)] = tmp;
            size_t tmp2 = pages[least_used];
            pages[least_used] = pages[unused_swap];
            // Swap in
            if(need != unused_swap)
            {
                debug(paging)
                    stderr.writef("tmp2[%d] ", tmp2);
                if((to!(size_t)(pages[need] * -1) in swap) !is null)
                {
                    memory[tmp2..tmp2+PAGE_SIZE] = 
                        swap[to!(size_t)(pages[need] * -1)][0..$];
                    swap.remove(to!(size_t)(pages[need] * -1));
                }
                pages[unused_swap] = pages[need];
            }
            pages[need] = to!(int)(tmp2);
            debug(paging)
            {
                stderr.writef("\n");
                stderr.writef("Pages: ");
                foreach(key; pages.keys.sort)
                {
                    stderr.writef("[%s:%s]", key, pages[key]);
                }
                stderr.writef("\n");
                stderr.writef("Page_used: ");
                foreach(key; page_used.keys.sort)
                {
                    stderr.writef("[%s:%s]", key, page_used[key]);
                }
                stderr.writef("\n");
                stderr.writef("Swap_used: ");
                foreach(key; swap.keys.sort)
                {
                    stderr.writef("[%s]", key);
                }
                stderr.writef("\n");
            }
        }
        return pages[index >> offset_bits] + (index << page_bits >> page_bits);
    }
    void opIndexAssign(ByteCode b, size_t index)
    {
        debug(vmemory_access)
            stderr.writef("opIndexAssign: virtual[%d] page[%d] offset[%d] physical[%d]\n", 
                index, index >> offset_bits, index << page_bits >> page_bits, virt2phys(index)
            );
        memory[virt2phys(index)] = b;
    }
    ByteCode opIndex(size_t index)
    {
        debug(vmemory_access)
            stderr.writef("opIndex: virtual[%d] page[%d] offset[%d] physica[%d]\n", 
                index, index >> offset_bits, index << page_bits >> page_bits, virt2phys(index)
            );
        return memory[virt2phys(index)];
    }
    ByteCode[] opSlice(size_t start, size_t end)
    {
        debug(vmemory_access)
            stderr.writef("opSlice: start: virtual[%d] page[%d] offset[%d] phys[%d]\n         end: virtual[%d] page[%d] offset[%d] phys[%d]\n", 
                start, start >> offset_bits, start << page_bits >> page_bits, virt2phys(start),
                end, end >> offset_bits, end << page_bits >> page_bits, virt2phys(end)
            );
        //enforce((end >> offset_bits) - (start >> offset_bits) < 2, "opSlice: Memory access across >2 pages is unimplemented");
        return memory[virt2phys(start)..virt2phys(end)];
    }
    void opSliceAssign(ByteCode b, size_t start, size_t end)
    {
        debug(vmemory_access)
            stderr.writef("opSliceAssign: start: virtual[%d] page[%d] offset[%d] phys[%d]\n         end: virtual[%d] page[%d] offset[%d] phys[%d]\n", 
                start, start >> offset_bits, start << page_bits >> page_bits, virt2phys(start),
                end, end >> offset_bits, end << page_bits >> page_bits, virt2phys(end)
            );
        //enforce((end >> offset_bits) - (start >> offset_bits) < 2, "opSliceAssign: Memory access across >2 pages is unimplemented");
        memory[virt2phys(start)..virt2phys(end)] = b;
    }
    void opSliceAssign(const ByteCode b[], size_t start, size_t end)
    {
        enforce(b.length == end - start, "Array copy sizes don't match");
        debug(vmemory_access)
            stderr.writef("opSliceAssign[]: start: virtual[%d] page[%d] offset[%d] phys[%d]\n         end: virtual[%d] page[%d] offset[%d] phys[%d]\n", 
                start, start >> offset_bits, start << page_bits >> page_bits, virt2phys(start),
                end, end >> offset_bits, end << page_bits >> page_bits, virt2phys(end)
            );
        //enforce((end >> offset_bits) - (start >> offset_bits) < 2, "opSliceAssign[]: Memory access across >2 pages is unimplemented");
        memory[virt2phys(start)..virt2phys(end)] = b[0..$];
    }
    void opSliceAssign(ByteCode b)
    {
        debug(vmemory_access)
            stderr.writef("opSliceAssign[all]\n");
        //enforce(start >> offset_bits == end >> offset_bits, "Memory access across multiple pages is unimplemented\n");
        memory[0..$] = b;
    }
    string toString()
    {
        return format("%s", memory);
    }

}

unittest
{
    VirtualMemory memory;
    memory.length = 10;
    memory[0] = 1;
    writef("%s\n", memory);
    assert(memory[0] == 1);
    memory[0..memory.length] = 1;
    ByteCode[] bytes;
    bytes.length = 10;
    bytes[0..$] = 0;
    memory[0..memory.length] = 0;
    assert(memory[0..memory.length] == bytes[0..$]);
    bytes[5..6] = 1;
    memory[5..10] = bytes[5..10];
    assert(memory[0..memory.length] == bytes[0..$]);
}

class VirtualMachine 
{
private:
    // We are running!
    bool _running = true;
    // Labels for Special Purpose Registers
    uint PC; // Program Counter Register
    uint SL; // Stack Limit Register
    uint SB; // Stack Base Register
    uint SP; // Stack Pointer
    uint FP; // Frame Pointer
    uint OF; // Offset
    uint TC; // Hardware Thread Count
    // All Registers (Including special purpose ones)
    Register[Valid_Registers.length] R;
    // Offset into memory we start at
    // Thread Management variables
    uint switch_num = 3;
    uint sig0_num = 42;
    Thread[] available_threads;
    Thread[] active_threads;
    uint minimum_stack_size;
    // Debug info
    string[uint] symbol_table;
    Valid_OpCodes valid_opcodes;
    Valid_Registers valid_registers;
    // Input file : TODO Update this to be an I/O stream
    string filename;
    // Assembler Object
    Assembler assembler;
    // Actual Bytecode
    version(VIRTUALMEMORY)
        VirtualMemory memory;
    else
        ByteCode[] memory;
    // Associatve array of OpCode functions
    void delegate(Instruction) operations[string];
    // Associatve array of Trap Handler functions
    void delegate(Instruction) TRP_handlers[int];
    void delegate() SIG_handlers[int];

    void init() {
        valid_opcodes = new Valid_OpCodes();
        valid_registers = new Valid_Registers();
        PC = valid_registers.to_Register["PC"];
        R[PC] = 0;
        SL = valid_registers.to_Register["SL"];
        R[SL] = 0;
        SB = valid_registers.to_Register["SB"];
        R[SB] = 0;
        SP = valid_registers.to_Register["SP"];
        R[SP] = 0;
        FP = valid_registers.to_Register["FP"];
        R[FP] = 0;
        OF = valid_registers.to_Register["OF"];
        R[OF] = 0;
        TC = valid_registers.to_Register["TC"];
        R[TC] = 1;
        operations["JMP"] = &do_JMP;
        operations["JMR"] = &do_JMR;
        operations["BNZ"] = &do_BNZ;
        operations["BGT"] = &do_BGT;
        operations["BLT"] = &do_BLT;
        operations["BRZ"] = &do_BRZ;
        operations["MOV"] = &do_MOV;
        operations["LDA"] = &do_LDA;
        operations["STR"] = &do_STR;
        operations["LDR"] = &do_LDR;
        operations["STB"] = &do_STB;
        operations["LDB"] = &do_LDB;
        operations["ADD"] = &do_ADD;
        operations["ADI"] = &do_ADI;
        operations["SUB"] = &do_SUB;
        operations["MUL"] = &do_MUL;
        operations["DIV"] = &do_DIV;
        operations["AND"] = &do_AND;
        operations["OR"]  = &do_OR ;
        operations["CMP"] = &do_CMP;
        operations["TRP"] = &do_TRP;
        operations["RUN"] = &do_RUN;
        operations["END"] = &do_END;
        operations["BLK"] = &do_BLK;
        operations["LCK"] = &do_LCK;
        operations["ULK"] = &do_ULK;
        debug(instruction)
                stderr.writef("End of init\n");
    }

    void write_int(size_t loc, Directive_Int value)
    {
        debug(memory_access)
            stderr.writef("Writing an int at position [%d]\n", loc + R[OF]);
        to_ByteCode!(Directive_Int) bytes;
        bytes.data = value;
        memory[loc + R[OF]..loc + R[OF] + Directive_Int.sizeof] = bytes.bytes[0..$];
    }

    void write_byte(size_t loc, Directive_Byte value)
    {
        debug(memory_access)
            stderr.writef("Writing a byte at position [%d]\n", loc + R[OF]);
        memory[loc + R[OF]] = value;
    }

    Directive_Int read_int(size_t loc)
    {
        debug(memory_access)
            stderr.writef("Reading an int at position [%d]\n", loc + R[OF]);
        to_ByteCode!(Directive_Int) bytes;
        bytes.bytes[0..$] = memory[loc + R[OF]..loc + R[OF] + Directive_Int.sizeof];
        return bytes.data;
    }

    Directive_Byte read_byte(size_t loc)
    {
        debug(memory_access)
            stderr.writef("Reading a byte at position [%d]\n", loc + R[OF]);
        return memory[loc + R[OF]];
    }

    void do_JMP(Instruction I) {
        debug(instruction) {
            string* symbol = (I.op1 in symbol_table);
            if (symbol == null)
                stderr.writef("instruction: [%d] (%d) JMP %d\n", active_threads[0].id, R[PC], I.op1);
            else
                stderr.writef("instruction: [%d] (%d) JMP %d:%s\n", active_threads[0].id, R[PC], I.op1, *symbol);
        }
        // Need to offset by the size of the instruction because the first thing we do after exection is increment PC
        R[PC] = to!(int)(I.op1 - Instruction.sizeof);
    }

    void do_JMR(Instruction I) {
        debug(instruction) {
            string* symbol = (R[I.op1] in symbol_table);
            if (symbol == null)
                stderr.writef("instruction: [%d] (%d) JMR %s(%d)\n", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1]);
            else
                stderr.writef("instruction: [%d] (%d) JMR %s(%d:%s)\n", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], *symbol);
        }
        // Need to offset by the size of the instruction because the first thing we do after exection is increment PC
        R[PC] = to!(int)(R[I.op1] - Instruction.sizeof);
    }
    void do_BNZ(Instruction I) {
        debug(instruction) stderr.writef("instruction: [%d] (%d) BNZ %s(%d), %d\n", 
            active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], I.op2);
        if (R[I.op1]) {
            R[PC] = to!(int)(I.op2 - Instruction.sizeof);
        }
    }
    void do_BGT(Instruction I) {
        debug(instruction) stderr.writef("instruction: [%d] (%d) BGT %s(%d) > 0, %d\n", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], I.op2);
        if (R[I.op1] > 0) {
            R[PC] = to!(int)(I.op2 - Instruction.sizeof);
        }
    }
    void do_BLT(Instruction I) {
        debug(instruction) stderr.writef("instruction: [%d] (%d) BLT %s(%d) < 0, %d\n", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], I.op2);
        if (R[I.op1] < 0) {
            R[PC] = to!(int)(I.op2 - Instruction.sizeof);
        }
    }
    void do_BRZ(Instruction I) {
        debug(instruction) stderr.writef("instruction: [%d] (%d) BRZ %s(%d) == 0, %d\n", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], I.op2);
        if (!R[I.op1]) {
            R[PC] = to!(int)(I.op2 - Instruction.sizeof);
        }
    }
    void do_MOV(Instruction I) {
        debug(instruction) stderr.writefln("instruction: [%d] (%d) MOV %s(%d) = %s(%d)", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], valid_registers.to_string[I.op2], R[I.op2]);
        R[I.op1] = R[I.op2];
    }
    void do_LDA(Instruction I) { 
        debug(instruction) {
            string* symbol = (I.op2 in symbol_table);
            if (symbol == null)
                stderr.writefln("instruction: [%d] (%d) LDA %s = %d", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], I.op2);
            else
                stderr.writefln("instruction: [%d] (%d) LDA %s = %d:%s", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], I.op2, *symbol);
        }
        R[I.op1] = I.op2; 
    }
    void do_STR(Instruction I) {
        debug(instruction) 
            stderr.writef("instruction: [%d] (%d) STR %s(%d) m(%d) => ", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], I.mode);
        if (I.mode == 0) {
            write_int(I.op2, R[I.op1]);
            debug(instruction) {
                string* symbol = (I.op2 in symbol_table);
                if (symbol == null)
                    stderr.writef("%d\n", I.op2);
                else
                    stderr.writef("%d:%s\n", I.op2, *symbol);
            }
        } else if (I.mode == 1) {
            write_int(R[I.op2], R[I.op1]);
            debug(instruction) {
                string* symbol = (R[I.op2] in symbol_table);
                if (symbol == null)
                    stderr.writef("%s(%d)\n", valid_registers.to_string[I.op2], R[I.op2]);
                else
                    stderr.writef("%s(%d:%s)\n", valid_registers.to_string[I.op2], R[I.op2], *symbol);
            }
        }
    }
    void do_LDR(Instruction I) {
        debug(instruction) stderr.writef("instruction: [%d] (%d) LDR %s <= ", active_threads[0].id, R[PC], valid_registers.to_string[I.op1]);
        if(I.mode == 0) {
            R[I.op1] = read_int(I.op2);
            debug(instruction) {
                string* symbol = (I.op2 in symbol_table);
                if (symbol == null)
                    stderr.writef("(%d)(%d)\n", I.op2, read_int(I.op2));
                else
                    stderr.writef("(%d:%s)(%d)\n", I.op2, *symbol, read_int(I.op2));
            }
        } else if (I.mode == 1) {
            R[I.op1] = read_int(R[I.op2]);
            debug(instruction) {
                string* symbol = (R[I.op2] in symbol_table);
                if (symbol == null)
                    stderr.writef("%s(%d)(%d)\n", valid_registers.to_string[I.op2], R[I.op2], read_int(I.op2));
                else
                    stderr.writef("%s(%d:%s)(%d)\n", valid_registers.to_string[I.op2], R[I.op2], *symbol, read_int(I.op2));
            }
        } else {
            throw(new Exception("Unknown adressing mode(" ~ to!(string)(I.mode) ~ ") in LDR statement\n"));
        }
    }
    void do_STB(Instruction I) {
        debug(instruction) {
            if (R[I.op1] != 10)
                stderr.writef("instruction: [%d] (%d) STB %s(%d:'%s') => ", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], to!(char)(to!(ubyte)(R[I.op1])));
            else
                stderr.writef("instruction: [%d] (%d) STB %s(%d:'\\n') => ", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1]);
        }
        if (I.mode == 0) {
            write_byte(I.op2, to!(ubyte)(R[I.op1]));
            debug(instruction) stderr.writef("%d\n", I.op2);
        } else if (I.mode == 1) {
            write_byte(R[I.op2], to!(ubyte)(R[I.op1]));
            debug(instruction) stderr.writef("%s(%d)\n", valid_registers.to_string[I.op2], R[I.op2]);
        }
    }
    void do_LDB(Instruction I) {
        debug(instruction) stderr.writef("instruction: [%d] (%d) LDB %s <= ", active_threads[0].id, R[PC], valid_registers.to_string[I.op1]);
        if (I.mode == 0) {
            R[I.op1] = read_byte(I.op2);
            debug(instruction) {
                //if(memory[I.op2 + R[OF]] != 10) 
                if(read_byte(I.op2) != 10) 
                    stderr.writef("(%d)(%d:'%s')\n", I.op2, memory[I.op2 + R[OF]], to!(char)(memory[I.op2 + R[OF]]));
                else
                    stderr.writef("(%d)(%d:'\\n')\n", I.op2, memory[I.op2 + R[OF]]);
            }
        } else if (I.mode == 1) {
            R[I.op1] = read_byte(R[I.op2]);
            debug(instruction) {
                //if(memory[R[I.op2] + R[OF]] != 10) 
                if(read_byte(R[I.op2]) != 10) 
                    stderr.writef("%s(%d)(%d:'%s')\n", valid_registers.to_string[I.op2], R[I.op2],memory[R[I.op2] + R[OF]], to!(char)(memory[R[I.op2] + R[OF]]));
                else
                    stderr.writef("%s(%d)(%d:'\\n')\n", valid_registers.to_string[I.op2], R[I.op2],memory[R[I.op2] + R[OF]]);
            }
        }
    }
    void do_ADD(Instruction I) {
        debug(instruction) stderr.writefln("instruction: [%d] (%d) ADD %s(%d) += %s(%d) = %d", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], valid_registers.to_string[I.op2], R[I.op2], R[I.op1] + R[I.op2]);
        R[I.op1] += R[I.op2];
    }
    void do_ADI(Instruction I) { 
        debug(instruction) stderr.writef("instruction: [%d] (%d) ADI %s += %d = ", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], I.op2);
        R[I.op1] += I.op2 * Directive_Byte.sizeof; 
        debug(instruction) stderr.writefln("%d", R[I.op1]);
    }
    void do_SUB(Instruction I) {
        debug(instruction) stderr.writefln("instruction: [%d] (%d) SUB %s(%d) -= %s(%d)", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], valid_registers.to_string[I.op2], R[I.op2]);
        R[I.op1] -= R[I.op2];
    }
    void do_MUL(Instruction I) {
        debug(instruction) stderr.writefln("instruction: [%d] (%d) MUL %s(%d) *= %s(%d)", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], valid_registers.to_string[I.op2], R[I.op2]);
        R[I.op1] *= R[I.op2];
    }
    void do_DIV(Instruction I) {
        debug(instruction) stderr.writefln("instruction: [%d] (%d) DIV %s(%d) /= %s(%d)", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], valid_registers.to_string[I.op2], R[I.op2]);
        R[I.op1] /= R[I.op2];
    }
    void do_AND(Instruction I) {}
    void do_OR (Instruction I) {}
    void do_CMP(Instruction I) {
        debug(instruction) stderr.writefln("instruction: [%d] (%d) CMP %s(%d) -= %s(%d)", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], valid_registers.to_string[I.op2], R[I.op2]);
        R[I.op1] -= R[I.op2];
    }

    void do_TRP(Instruction I) {
        debug(instruction) stderr.writefln("instruction: [%d] (%d) TRP: %d %d", active_threads[0].id, R[PC], I.op1, R[0]); 
        void delegate(Instruction) handler = TRP_handlers.get(I.op1,null);
        if(handler)
            handler(I);
        else
            throw(new Exception(format("Undefined Trap handler for TRP[%d]", I.op1)));
    }

// RUN REG, LABEL
// Run signals to the VM to create a new thread.  
// REG will return a unique thread identifier (number) that will be associated with the thread.  The register is to be set by your VM, not by the Programmer calling the RUN instruction.  You can determine what action to perform if all available identifiers are in use (throwing an exception is fine). Running out of identifiers means you have created two many threads and are out of Stack Space.
// The LABEL will be jumped to by the newly created thread.  The current thread will continue execution at the statement following the RUN. 
    void do_RUN(Instruction I) {
        debug(instruction) stderr.writef("instruction: [%d] (%d) RUN %s(%d), %d\n", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], I.op2);
        if (R[TC] < 2) {
            throw(new Exception("OpCode (RUN) encountered in a VM with only 1 thread."));
        }
        R[I.op1] = active_threads[0].id;
        int retval = activate_thread(I.op1, I.op2, R);
        debug(threads) stderr.writef("threads:    Attempted to start a thread, which returned %d\n", retval);
        if(retval == 1) {
            R[PC] -= Instruction.sizeof;
        }
    }
// END
// End will terminate the execution of a non-MAIN thread.  In functionality END is very similar to TRP 0, but only for a non-MAIN thread. END should only be used for non-MAIN threads.  END will have no effect if called in the MAIN Thread.
    void do_END(Instruction I) {
        debug(instruction) stderr.writef("instruction: [%d] (%d) END %s(%d), %d\n", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], I.op2);
        debug(threads) stderr.writef("threads:    Attempting to deactivate a thread with id [%d]\n", active_threads[0].id);
        int retval = deactivate_thread();
        debug(threads) stderr.writef("threads:    Attempt returned [%d] and now running thread [%d]\n", retval, active_threads[0].id);
        if(retval == 0) // If successfull
            // The last thread has yet to increment their PC, and this current thread had it's PC incremented before being stuffed at the back of the queue
            R[PC] -= Instruction.sizeof;
    }
// BLK
// TODO: Changed 'BLK' to 'BLK 0' so I don't have to change my parser right away.
// Block will cause the MAIN thread (the initial thread created when you start executing your Program) to wait for all other threads to terminate (END) before continuing to the next instruction following the block.  Block is only to be used on the MAIN thread. BLK will have no effect if called in a Thread which is not the MAIN thread.
    void do_BLK(Instruction I) {
        debug(instruction) stderr.writef("instruction: [%d] (%d) BLK %s(%d), %d\n", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], I.op2);
        if(active_threads[0].id == 0 && active_threads.length > 1)
            R[PC] -= Instruction.sizeof;
    }
// LCK LABEL
// TODO: Changed 'LCK LABEL' to 'LCK 0 LABEL' so I don't have to change my registers or parser right away. op2 is large enough to hold an address, op1 is smaller
// Lock will be used to implement a blocking mutex lock.  Calling lock will cause a Thread to try to place a lock on the mutex identified by Label. If the mutex is locked the Thread will block until the mutex is unlocked.  The data type for the Label can be .BYT or .INT.  
    void do_LCK(Instruction I) {
        debug(instruction) stderr.writef("instruction: [%d] (%d) LCK %s(%d), %d\n", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], I.op2);
        // Retrieve lock data
        to_ByteCode!(Directive_Int) bytes;
        bytes.bytes[0..$] = memory[I.op2 + R[OF]..I.op2 + R[OF] + Directive_Int.sizeof];
        debug(instruction) stderr.writef("instruction:     Lock contains [%d]\n", bytes.data);
        if(bytes.data == -1) {
            // Write ID to the location in memory called 'LABEL' to claim the lock
            debug(instruction) stderr.writef("instruction:     Lock Aquired!\n");
            write_int(I.op2, active_threads[0].id);
        } else {
            R[PC] -= Instruction.sizeof;
        }
    }
// ULK LABEL
// TODO: Changed 'ULK LABEL' to 'ULK 0 LABEL' so I don't have to change my registers or parser right away.
// Unlock will remove the lock from a mutex.  Unlock should have no effect on a mutex if the Thread did not lock the mutex (a.k.a., only the Thread that locks a mutex should unlock the mutex).
    void do_ULK(Instruction I) {
        debug(instruction) stderr.writef("instruction: [%d] (%d) ULK %s(%d), %d\n", active_threads[0].id, R[PC], valid_registers.to_string[I.op1], R[I.op1], I.op2);
        to_ByteCode!(Directive_Int) bytes;
        bytes.bytes[0..$] = memory[I.op2 + R[OF]..I.op2 + R[OF] + Directive_Int.sizeof];
        debug(instruction) stderr.writef("instruction:     Lock contains [%d]\n", bytes.data);
        if(bytes.data == active_threads[0].id) {
            // Write -1 to the location in memory called 'LABEL' to unlock it
            debug(instruction) stderr.writef("instruction:     UnLock Successfull!\n");
            write_int(I.op2, -1);
        }
        // If we don't own the lock, we're just going to skip over it.
    }

    void init_stack() {
        // Create new main thread (0) stack space and store registers
        //R[SL] = prog_end;
        //prog_end += thread_stack_size;
        uint prog_end = R[SL];

        uint thread_stack_size = (R[SB] - prog_end) / R[TC];
        debug(threads) {
                stderr.writef("  thread: Stack size (%d - %d) / %d = %d\n", prog_end, R[SB], R[TC], thread_stack_size);
                stderr.writef("  thread: Setting thread %d (%d - %d)\n", 0, prog_end, prog_end + thread_stack_size - 1);
        }
        // id, SL, SB
        active_threads ~= new Thread(0, prog_end, prog_end + thread_stack_size);
        // Push the SB and SP back enough to keep a copy of all the Registers
        R[SB] = to!(int)(active_threads[0].SB - (R[0].sizeof * R.length));
        R[SP] = to!(int)(R[SB]);
        store_registers(active_threads[0], R);
        // Create each available thread stack space, and store registers
        debug(threads) stderr.writef("threads: Creating %d available threads\n", R[TC]);
        foreach(i; 1..R[TC]) {
            debug(threads)
                stderr.writef("  thread: Setting thread %d %d %d\n", i, prog_end + i * thread_stack_size, prog_end + ((i + 1) * thread_stack_size - 1));
            available_threads ~= new Thread(i, prog_end + i * thread_stack_size, prog_end + ((i + 1) * thread_stack_size));
            R[SB] = to!(int)(available_threads[$-1].SB - (R[0].sizeof * R.length));
            R[SP] = to!(int)(R[SB]);
            store_registers(available_threads[$-1], R);
        }
        debug(threads) stderr.writef("threads: There are %d available threads\n", R[TC]);
        debug(assembler) stderr.writef("Registers: %s\n", R);
        // Retrieve original main thread's registers for starting the application execution
        read_registers(active_threads[0]);
        debug(assembler) 
            dump_registers("assembler: Registers for Main thread at the end of init_stack():");
        debug(assembler) {
            stderr.writef("Registers: %s\n", R);
            stderr.writef("assembler: SL = %d\n", R[SL]);
            stderr.writef("assembler: SB = %d\n", R[SB]);
            stderr.writef("assembler: Program is now length: %d\n", prog_end);
        }
        debug(instruction) {
            stderr.writef("assembler: SL = %d\n", R[SL]);
            stderr.writef("assembler: SB = %d\n", R[SB]);
            stderr.writef("assembler: Program is now length: %d\n", memory.length);
        }
    }

    void read_registers(Thread thread) {
        debug(threads)
            stderr.writef("threads: pre read_registers: %s [%d]\n", R, R.length);
        ulong thread_SB = thread.SB - R.sizeof;
        foreach(i; 0..R.length)
        {
            R[i] = read_int(thread_SB + i * R[0].sizeof);
        }
        debug(threads)
            stderr.writef("threads: post read_registers: %s [%d] %d %d\n", R, R.length, thread.SB, thread_SB);
    }

    void store_registers(Thread thread, int[Valid_Registers.length] R_copy) {
        debug(threads)
            stderr.writef("threads: pre store_registers: %s [%d]\n", R_copy, R_copy.length);
        // Store bytes into the vm memory
        ulong thread_SB = thread.SB - R_copy.sizeof;
        foreach(i; 0..R_copy.length)
        {
            write_int(thread_SB + i * R_copy[0].sizeof, R_copy[i]);
        }
        debug(threads)
            stderr.writef("threads: post store_registers: [%d-%d/%d]\n", thread_SB + R[OF], thread_SB + R[OF] + R_copy.sizeof - 1, memory.length);
    }

// Activate thread will attempt to pull a thread off the 'available_threads' array, and push it onto the back of the 'active_threads' array
//   Returns:
//     0 if successful
//     1 if not threads available
    int activate_thread(uint THID_R, uint new_PC, int[Valid_Registers.length] R_copy) {
        debug(threads) {
            stderr.writef("threads: Activating new thread at PC: %d\n", new_PC);
            stderr.writef("threads: There are %d threads available\n", available_threads.length);
        }
        int retval = 0;
        if (available_threads.length > 0) {
            active_threads = active_threads ~ available_threads[0];
            available_threads = available_threads[1..$];
            R_copy[PC] = new_PC;
            R_copy[THID_R] = active_threads[$-1].id;
            store_registers(active_threads[$-1], R_copy);
        } else {
            retval = 1;
        }
        return retval;
    }
    
    int switch_thread() {
        debug(threads)
            stderr.writef("threads: Switching to next thread\n"); 
        int retval = 0;
        store_registers(active_threads[0], R);
        active_threads ~= active_threads[0];
        active_threads = active_threads[1..$];
        read_registers(active_threads[0]);
        return retval;
    }
            
// Activate thread will attempt to pull a thread off the 'available_threads' array, and push it onto the back of the 'active_threads' array
//   Returns:
//     0 if successful
//     1 if only thread 0 is running
//     2 if thread 0 was attempted to deactivate
    int deactivate_thread() { 
        debug(threads)
            stderr.writef("threads: Deactivating thread: %d\n", active_threads[0].id);
        int retval = 0; 
        if(active_threads.length == 1) {
            retval = 1;
        } else if(active_threads[0].id == 0) {
            retval = 2;
        } else {
            available_threads = available_threads ~ active_threads[0];
            active_threads = active_threads[1..$];
            read_registers(active_threads[0]);
        }
        return retval;
    }

    void mem_dump(uint start, uint end) {
        stderr.writefln("dump: Memory dump");
        stderr.writef("%4d : ", start);
        for(size_t i = 0; i < end - start; i++) {
            if(i % 64 == 31) {
                stderr.writefln("%02x ",memory[start + i]);
                stderr.writef("%4d : ", start + i + 1);
            } else {
                stderr.writef("%02x ",memory[start + i]);
            }
        }
        writeln();
    }

public:
    this() {
        init();
    }

    this(Assembler a) {
        assembler = a;
        init();
    }

    void validate_registers() {
        // Minimum stack size check
        if (R[PC] < 0) {
            string msg = "pre_run: Attempted to run a program with PC < 0.";
            throw(new Exception(msg));
        }
        if (R[SB] == 0) {
            string msg = "pre_run: Attempted to run a program with SB == 0.";
            throw(new Exception(msg));
        }
        if (R[SL] == 0) {
            string msg = "pre_run: Attempted to run a program with SL == 0.";
            throw(new Exception(msg));
        }
        if ((R[SB] - R[SL]) / R[TC] < minimum_stack_size) {
            string msg = "pre_run: Attempted to run a Program with less than " ~ to!(string)(minimum_stack_size) ~ "] bytes of stack space per hw_thread.";
            msg ~= "Try increasing R[SB] from " ~ to!(string)(R[SB]) ~ "] to " ~ to!(string)(R[SL] + minimum_stack_size * R[TC]) ~ ".";
            throw(new Exception(msg));
        }
        if (R[SL] > R[SB]) {
            string msg = "pre_run: Attempted to run a program with a SB[" ~ to!(string)(R[SB]) ~ "] less than the SL[" ~ to!(string)(R[SL]) ~ "].";
            throw(new Exception(msg));
        }
        if (R[SB] + R[OF] > memory.length) {
            string msg = "pre_run: Attempted to run a Program with SB[" ~ to!(string)(R[SB]) ~ "] beyond the size of the VM[" ~ to!(string)(memory.length) ~ "].";
            throw(new Exception(msg));
        }
        // Doesn't work unless we've got a method to get symbols
        // TODO: Perhaps we need the assembler to dump a separate symbols file.
        //debug(instruction) {
        //  uint symbols[string] = assembler.get_symbols();
        //  foreach(key, value; symbols) {
        //    symbol_table[value] = key;
        //  }
        //  stderr.writef("Symbol Table:\n");
        //  foreach(value; symbols.values.sort) {
        //    stderr.writef("%-5d %s\n", value, symbol_table[value]);
        //  }
        //}
        //dump_registers("before init_stack");
        init_stack();
        //dump_registers("after  init_stack");
        if (R[PC] < 0) {
            string msg = "pre_run: Attempted to run a program with PC[" ~ to!(string)(R[PC]) ~ "] < 0 after init_stack().";
            throw(new Exception(msg));
        }
        if (R[SP] < 0) {
            string msg = "pre_run: Attempted to run a program with SP < 0 after init_stack().";
            throw(new Exception(msg));
        }
        if (R[SB] == 0) {
            string msg = "pre_run: Attempted to run a program with SB == 0 after init_stack().";
            throw(new Exception(msg));
        }
        if (R[SL] == 0) {
            string msg = "pre_run: Attempted to run a program with SL == 0 after init_stack().";
            throw(new Exception(msg));
        }
        if (R[SB] != R[SP]) {
            string msg = "pre_run: Attempted to run a program with SB != SP after init_stack().";
            throw(new Exception(msg));
        }
    }

    @property
    {
        size_t size() { return memory.length; }
        void size(size_t l) { memory.length = l; }
        version(VIRTUALMEMORY)
            void virt_size(size_t l) { memory.virt_length = l; }
        bool running() { return _running; }
        void running(bool b) { _running = b; }
        Thread active_thread() { return active_threads[0]; }
        version(VIRTUALMEMORY) {
            ByteCode[] raw_memory() {return memory.memory;}
        } else {
            ByteCode[] raw_memory() {return memory;}
        }
    }

    void set_vm_threads(Thread[] ac, Thread[] av)
    {
        active_threads = ac;
        available_threads = av;
    }

    void fetch_vm_threads(out Thread[] ac, out Thread[] av)
    {
        ac = active_threads;
        av = available_threads;
    }

    void set_registers(Register[Valid_Registers.length] R_new)
    {
        R = R_new;
    }

    void fetch_registers(out Register[Valid_Registers.length] R_out)
    {
        R_out = R;
    }

    void set_register(string reg, int val) {
        if(valid_registers.is_valid(reg)) {
            R[valid_registers.to_Register[reg]] = val;
        } else {
            throw(new Exception("Tried to set an invalid register! [" ~ reg ~ "]."));
        }
    }

    void set_register(uint reg, int val) {
        if(reg < R.length) {
            R[reg] = val;
        } else {
            throw(new Exception(format("Tried to set an invalid register! [%d].", reg)));
        }
    }

    int fetch_register(string reg) {
        if(valid_registers.is_valid(reg)) {
            return R[valid_registers.to_Register[reg]];
        } else {
            throw(new Exception("Tried to set an invalid register! [" ~ reg ~ "]."));
        }
    }

    int fetch_register(uint reg) {
        if(reg < R.length) {
            return R[reg];
        } else {
            throw(new Exception(format("Tried to set an invalid register! [%d].", reg)));
        }
    }

    void load(in ByteCode[] data, size_t loc) {
        debug(load) 
            stderr.writef("load: Loading [%s] bytes of bytecode into memory at [%d->%d/%d].\n",
                data.length, loc, loc + data.length - 1, memory.length);
        if (loc + data.length > memory.length) {
            string msg = "load: Not enough room to load [" ~ to!(string)(data.length) ~
                "] bytes into memory at position [" ~ to!(string)(loc) ~ "].\n";
            msg       ~= "load: Memory size is [" ~ to!(string)(memory.length) ~ "] bytes.";
            throw(new Exception(msg));
        }
        memory[loc..loc + data.length] = data[0..$];
    }

    ByteCode[] read(size_t size, size_t loc)
    {
        debug(load) 
            stderr.writef("read: Reading [%s] bytes of bytecode memory at [%d->%d/%d].\n", size, loc, loc + size - 1, memory.length);
        return memory[loc..loc + size];
    }

    void zero_registers() 
    {
        R[0..$] = 0;
    }

    int run() {
        debug(instruction) {
            dump_registers("Start of run");
            stderr.writef("memory.length: %d\n", memory.length);
        }
        debug(dump) 
            mem_dump(R[OF], R[OF] + R[SB]);

        // Local variables to be used over and over again;
        Instruction inst;
        uint switcher = 0;
        uint sig0 = 0;
        void delegate(Instruction) operation;
        //debug(dump) _running=false;
        _running = true;
        while(_running) {
            if(R[SP] < 0)
                throw(new Exception(format("R[SP] is < 0 [%d]", R[SP])));
            debug(instruction) 
                stderr.writeln("run: Getting instruction at R[PC]: ", R[PC]);
            if (R[PC] + R[OF] + (Instruction.sizeof / ByteCode.sizeof) >= memory.length) 
            {
                string msg =  format("Attempted to access memory out of range.[%d/%d]", R[PC] + R[OF] + (Instruction.sizeof / ByteCode.sizeof), memory.length);
                throw(new Exception(msg));
            }
            inst.bytes = memory[R[PC] + R[OF]..R[PC] + R[OF] + (Instruction.sizeof / ByteCode.sizeof)];
            debug(run) 
            {
                stderr.writef("run: "); 
                print_Instruction(inst);
            }
            // Retrieve the function pointer to the appropriate operation
            if((inst.opcode in valid_opcodes.to_string) is null) {
                dump_registers("Invalid OpCode");
                string message = format("runtime: Invalid Opcode(%d) encountered at PC %d(%d) by running. ", inst.opcode, R[PC], R[PC] + R[OF]);
                message ~= "This is either a bug in the VM, or a stray JMP into memory.\n";
                //mem_dump(R[OF], R[OF] + R[SB]);
                throw(new Exception(message));
            }
            // Get the function pointer to the current opcode
            operation = operations.get(valid_opcodes.to_string[inst.opcode], null);
            if(operation is null) 
            {
                string message = format("runtime: Invalid operation encountered during runtime (%s). Something is totally busted.", valid_opcodes.to_string[inst.opcode]);
                throw (new Exception(message));
            } 
            else 
            {
                operation(inst);
                R[PC] += inst.sizeof;
            }

            // Hardware threads
            switcher = (switcher + 1) % switch_num;
            debug(threads) {
                stderr.writef("threads: Thread ID [%d], PC [%d]\n", active_threads[0].id, R[PC]);
                stderr.writef("threads: switcher = %d @ %d\n", switcher, R[PC]);
            }
            if (switcher == 0) {
                debug(threads)
                    stderr.writef("threads: Switching Thread!\n");
                if(active_threads.length > 1)
                    switch_thread();
            }

            // SIG 0 is back to scheduler for potential context switch
            sig0 = (sig0 + 1) % sig0_num;
            if (sig0 == 0 || !running)
            {
                if(SIG_handlers.get(0, null) is null)
                    throw(new Exception(format("No SIG 0 handler!")));
                else
                    SIG_handlers[0]();
            }
        }
        debug(dump) 
            mem_dump(R[OF], R[OF] + R[SB]);
        active_threads.length = 0;
        available_threads.length = 0;
        return 1;
    }

    void register_TRP_handler(int i, void delegate(Instruction) new_handler) {
        TRP_handlers[i] = new_handler;
    }

    void register_SIG_handler(int i, void delegate() new_handler) {
        SIG_handlers[i] = new_handler;
    }

    void dump_registers(string msg) {
        stderr.writef("%s\n[\n", msg);
        for(int i = 0; i < R.length; i++) {
            stderr.writef("  %s[%d][%d]\n", valid_registers.to_string[i], R[i], R[i] + R[OF]);
        }
        stderr.writef("]\n");
    }
}

