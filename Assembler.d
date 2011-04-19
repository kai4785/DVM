// CS-4380 Virtual Machine Project 1

module Assembler;

import std.stdio;    // For STDIN, STDOUT, STDERR
import std.conv;
import std.string;

import Utilities;

class Assembler {
private:
  this() {
    writeln("Default constructor. You did something wrong.");
  }
  string filename;
  uint symbol_table[string];
  ByteCode program[];
  Valid_OpCodes valid_opcodes;
  Valid_Directives valid_directives;
  Valid_Registers valid_registers;
  uint line_num;
  // Amount of memory required to store program plus constant data
  AssemblyHeader header;
  uint code_size;
  uint code_pos;
  uint data_size;
  uint data_pos;

  void pass1() {
    debug(pass1) stderr.writeln("pass1: Opening ", filename, " for reading in pass1.");
    line_num = 0;
    //code_size = header.data.sizeof;
    code_size = 0;
    data_size = 0;
    string line;
    string[string] tokens;
    uint data_symbols[string];
    File infile = File(filename, "r");
    while(infile.readln(line)) {
      line = chomp(line);
      line_num++;
      tokens = parseln(line);
      if(("type" in tokens) != null) {
        if ((tokens["label"] in symbol_table) != null) {
          throw (new Exception(to!(string)(line_num) ~ ": Duplicate Label detected " ~ tokens["label"] ));
        }
        if(tokens["type"] == "opcode") {
          if(tokens["label"] != "") {
            symbol_table[tokens["label"]] = code_size;
            debug(pass1) stderr.writef("%d: Found Op Label : %s at %d\n", line_num, tokens["label"], code_size);
          }
          //writeln(line_num, ": Found Opcode    : ", tokens["opcode"]);
          code_size += Instruction.sizeof;
        } else if (tokens["type"] == "directive") {
          if(tokens["label"] != "") {
            debug(pass1) stderr.writefln("pass1: Found Data symbol: %s", tokens["label"]);
            symbol_table[tokens["label"]] = data_size;
            data_symbols[tokens["label"]] = data_size;
          }
          //writeln(line_num, ": Found Directive : ", tokens["directive"]);
          data_size += valid_directives.to_Directive[tokens["directive"]];
        } else {
          writeln(line_num, ": Unknown operation: ", tokens["type"]);
        }
      }
    }
    debug(pass1) stderr.writeln("pass1: Program will have ", code_size, " Bytes for code and ", data_size, " Bytes for static data.");
    debug(pass1) stderr.writeln("pass1: Symbols found during pass1:");
    // Adjust all labels for data_symbols
    foreach(key, value; data_symbols) {
      debug(pass1) stderr.writefln("pass1: Updating Data Symbol %s to be at location %d", key, symbol_table[key]);
      symbol_table[key] += code_size;
    }
    debug(pass1) stderr.writef("pass1: List of symbols and their addresses:\n");
    debug(pass1) foreach(i, a; symbol_table) {
      stderr.writefln("pass1: %s = %d", i, symbol_table[i]);
    }
  }

  void pass2() {
    debug(pass2) stderr.writeln("pass2: Opening ", filename, " for reading in pass2.");
    program.length = header.data.sizeof + code_size + data_size; // Set the size of the static data for the program
    code_pos = header.data.sizeof;
    data_pos = header.data.sizeof + code_size;
    header.data[0] = program.length - header.data.sizeof;
    header.data[1] = 0;
    header.data[2] = 0;
    debug(pass2)
        stderr.writef("Assembler Header: %s\n", header.data);
    for(int i = 0; i < header.data.length; i++) {
        to_ByteCode!(typeof(header.data[0])) bytes;
        bytes.data = header.data[i];
        program[i * bytes.bytes.length..(i + 1) * bytes.bytes.length] = bytes.bytes[0..$];
    }
    string line;
    string[string] tokens;
    line_num = 0;
    Instruction inst;
    File infile = File(filename, "r");
    ByteCode[] bytes;
    while(infile.readln(line)) {
      line = chomp(line);
      line_num++;
      tokens = parseln(line);
      if(("type" in tokens) != null) {
        if(tokens["type"] == "opcode") {
          inst = to_Instruction(tokens);
          debug(pass2) stderr.writef("Copying new instruction into bytes %d -> %d\n", code_pos, code_pos + inst.bytes.length - 1);
          program[code_pos..code_pos + inst.bytes.length] = inst.bytes[0..$];
          code_pos += inst.bytes.length;
        } else if (tokens["type"] == "directive") {
          // Since we store everything in an Instruction struct, we need to convert this to a ubyte array
          // The to_ByteCode struct is simply a Templated Union that blasts the data into a char[]
          if(tokens["directive"] == ".BYT") {
            debug(pass2) stderr.writef("pass2: Processing .BYT directive for value %s\n", tokens["value"]);
            to_ByteCode!(Directive_Byte) bytecode;
            bytes.length = bytecode.bytes.length;
            if (auto m = std.regexp.search(tokens["value"], r"^\d+$")) {
              debug(pass2) stderr.writef("pass2: .BYT directive is Numeric\n");
              bytecode.data = to!(ubyte)(parse!(Instruction.storage_type)(tokens["value"]));
            } else if (auto m = std.regexp.search(tokens["value"], r"'?(.)'?$")) {
              debug(pass2) stderr.writef("pass2: .BYT directive is not Numeric\n");
              if(tokens["value"][1] == '\\')
              {
                if(tokens["value"][2] == 'n')
                    bytecode.data = to!(ubyte)('\n');
                if(tokens["value"][2] == 't')
                    bytecode.data = to!(ubyte)('\t');
              }
              else
              {
                bytecode.data = to!(ubyte)(tokens["value"][1]);
              }
            }
            bytes[0..$] = bytecode.bytes[0..$];
          } else if (tokens["directive"] == ".INT") {
            debug(pass2) stderr.writef("pass2: Processing .INT directive for value %s\n", tokens["value"]);
            to_ByteCode!(Directive_Int) bytecode;
            bytes.length = bytecode.bytes.length;
            if(auto m = std.regexp.search(tokens["value"], r"^[+-]?\d+$")) {
              debug(pass2) stderr.writef("pass2: .INT directive is Numeric\n");
              bytecode.data = parse!(Instruction.storage_type)(tokens["value"]);
            } else {
              debug(pass2) stderr.writef("pass2: .INT value is invalid\n");
              throw (new Exception(to!(string)(line_num) ~ ": .INT value is invalid\n" ~ line));
            }
            bytes[0..$] = bytecode.bytes[0..$];
          } else {
            throw (new Exception(to!(string)(line_num) ~ ": Unkown directive that should have been caught in pass1 (" ~ tokens["directive"] ~ ")."));
          }
          debug(pass2) stderr.writef("pass2: Adding bytes to positions (%d,%d), for type %s, value: %d\n", data_pos, data_pos + bytes.length - 1, tokens["directive"], bytes[0..$]);
          program[data_pos..data_pos + valid_directives.to_Directive[tokens["directive"]]] = bytes[0..valid_directives.to_Directive[tokens["directive"]]];
          data_pos += valid_directives.to_Directive[tokens["directive"]];
        } else {
          writeln(line_num, ": Unknown operation: ", tokens["type"]);
        }
      }
    }
    debug(pass2) stderr.writeln("pass2: Finished passed2");
  }

  Instruction to_Instruction(string[string] tokens) {
    Instruction inst;
    int i;
    string s;
    inst.opcode = valid_opcodes.to_OpCode[tokens["opcode"]];
    inst.mode = to!(Instruction.storage_type)(parse!(Instruction.storage_type)(tokens["mode"]));
    inst.op1 = op_from_string(tokens["op1"]);
    if(("op2" in tokens) != null) { //Ignore Comments
      Instruction.storage_type retval = op_from_string(tokens["op2"]);
      inst.op2 = retval;
    }
    if (inst.opcode == 0) {
      throw(new Exception("Invalid Opcode (0) detected during pass2! Something broke\n"));
    }
    return inst;
  }

  // Convert operands from Strings to Symbols or Registers
  // This is where we add Special registers.
  Instruction.storage_type op_from_string(string op) { 
    Instruction.storage_type retval;
    if(is_symbol(op)) {
      debug(info) writefln("info: Resolving Operand symbol %s to %d", op, symbol_table[op]);
      retval = symbol_table[op];
    } else if(valid_registers.is_valid(op)) {
      debug(info) writefln("info: Resolving Operand %s to %d", op, valid_registers.to_Register[op]);
      retval = valid_registers.to_Register[op];
    } else {
      debug(info) writefln("info: Reading Operand \"%s\" on line %d", op, line_num);
      retval = parse!(Instruction.storage_type)(op);
    }
    //debug(info) writef("info: All done with op_from_string, returning %d\n", retval);
    return retval;
  }

  string[string] parseln (string line) {
    string[string] tokens_assoc;
    /*
    Directive Syntax (4 cases)
    	.INT	2
    ARR	.BYT	10
    	.INT	3 ;Comment
    ARR	.BYT	3 ;Comment
    OpCode with 2 Operands Syntax (4 cases)
    		LDR	R0,	R1
    LABEL	LDR	R0,	R1
    		LDR	R0,	R1 ;Comment
    LABEL	LDR	R0,	R1 ;Comment
    OpCode with 1 Operand Syntax (4 cases)
    		TRP	3
    LABEL	TRP	3
    		TRP	3 ;Comment
    LABEL	TRP	3 ;Comment
    */
    // The order of these shouldn't make a big difference, but I haven't tested that out. Better leave them be for now
    // Of the 12 cases above, I was able to encapsulate them into 6 regexps, 
    //   because I can ignore or catch the comment, cutting 12 in half to 6.

    // Example: writef("%s[%s]%s", m.pre, m.match(0), m.post); 
    // Directive Syntax no label
    if (auto m = std.regexp.search(line, r"^\s*(\.\w+)\s+('?[+-]?\d+'?|'?..?'?)\s*([^;]*)($|;.*$)")) {
      debug(parseln) writef("parseln: %3d: DN: %s[%s][%s][%s][%s]%s -> ",line_num, m.pre, m.match(1), m.match(2), m.match(3), m.match(4), ""); 
      debug(parseln) writef("parseln: Label: '%s', Directive: '%s', OP1: '%s', Extra: '%s', Comments: '%s'\n", "", m.match(1), m.match(2), m.match(3), m.match(4));
      tokens_assoc["type"]      = "directive";
      tokens_assoc["label"]     = "";
      tokens_assoc["directive"] = m.match(1);
      tokens_assoc["value"]     = m.match(2);
      tokens_assoc["extra"]     = m.match(3);
      tokens_assoc["comment"]   = m.match(4);
    }
    // Directive Syntax with label
    else if (auto m = std.regexp.search(line, r"^\s*(\w+)\s+(\.\w+)\s+('?[+-]?\d+'?|'?..?'?)\s*([^;]*)($|;.*$)")) {
      debug(parseln) writef("parseln: %3d: DL: %s[%s][%s][%s][%s][%s]%s -> ",line_num, m.pre, m.match(1), m.match(2), m.match(3), m.match(4), m.match(5), ""); 
      debug(parseln) writef("parseln: Label: '%s', Directive: '%s', OP1: '%s', Extra: '%s', Comments: '%s'\n", m.match(1), m.match(2), m.match(3), m.match(4), m.match(5));
      tokens_assoc["type"]      = "directive";
      tokens_assoc["label"]     = m.match(1);
      tokens_assoc["directive"] = m.match(2);
      tokens_assoc["value"]     = m.match(3);
      tokens_assoc["extra"]     = m.match(4);
      tokens_assoc["comment"]   = m.match(5);
    }
    // OpCode with out Label and 2 operands
    else if (auto m = std.regexp.search(line, r"^\s*(\w+)\s+(\w+)\s*,\s*(\w+|[+-]?\d+)\s*([^;]*)($|;.*$)")) {
      debug(parseln) writef("parseln: %3d: ON2 %s[%s][%s][%s][%s][%s]%s -> ",line_num, m.pre, m.match(1), m.match(2), m.match(3), m.match(4), m.match(5), ""); 
      debug(parseln) writef("parseln: Label: '%s', OpCode: '%s', OP1: '%s', OP2: '%s', Extra: '%s', Comments: '%s'\n", "", m.match(1), m.match(2), m.match(3), m.match(4), m.match(5));
      tokens_assoc["type"]    = "opcode";
      tokens_assoc["label"]   = "";
      tokens_assoc["opcode"]  = m.match(1);
      tokens_assoc["op1"]     = m.match(2);
      tokens_assoc["op2"]     = m.match(3);
      tokens_assoc["extra"]   = m.match(4);
      tokens_assoc["comment"] = m.match(5);
    }
    // OpCode with Label and 2 operands
    else if (auto m = std.regexp.search(line, r"^\s*(\w+)\s+(\w+)\s+(\w+)\s*,\s*(\w+|[+-]?\d+)\s*([^;]*)($|;.*$)")) {
      debug(parseln) writef("parseln: %3d: OL2 %s[%s][%s][%s][%s][%s][%s]%s -> ",line_num, m.pre, m.match(1), m.match(2), m.match(3), m.match(4), m.match(5), m.match(6), ""); 
      debug(parseln) writef("parseln: Label: '%s', OpCode: '%s', OP1: '%s', OP2: '%s', Extra: '%s', Comments: '%s'\n", m.match(1), m.match(2), m.match(3), m.match(4), m.match(5), m.match(6));
      tokens_assoc["type"]    = "opcode";
      tokens_assoc["label"]   = m.match(1);
      tokens_assoc["opcode"]  = m.match(2);
      tokens_assoc["op1"]     = m.match(3);
      tokens_assoc["op2"]     = m.match(4);
      tokens_assoc["extra"]   = m.match(5);
      tokens_assoc["comment"] = m.match(6);
    }
    // OpCode with Label and 1 operand
    else if (auto m = std.regexp.search(line, r"^\s*(\w+)\s+(\w+)\s+(\w+)\s*([^;]*)($|;.*$)")) {
      debug(parseln) writef("parseln: %3d: OL1 %s[%s][%s][%s][%s][%s]%s -> ",line_num, m.pre, m.match(1), m.match(2), m.match(3), m.match(4), m.match(5), ""); 
      debug(parseln) writef("parseln: Label: '%s', OpCode: '%s', OP1: '%s', Extra: '%s', Comments: '%s'\n", m.match(1), m.match(2), m.match(3), m.match(4), m.match(5));
      tokens_assoc["type"]    = "opcode";
      tokens_assoc["label"]   = m.match(1);
      tokens_assoc["opcode"]  = m.match(2);
      tokens_assoc["op1"]     = m.match(3);
      tokens_assoc["extra"]   = m.match(4);
      tokens_assoc["comment"] = m.match(5);
    }
    // OpCode with out Label and 1 operand
    else if (auto m = std.regexp.search(line, r"^\s*(\w+)\s+(\w+)\s*([^;]*)($|;.*$)")) {
      debug(parseln) writef("parseln: %3d: ON1 %s[%s][%s][%s][%s]%s -> ",line_num, m.pre, m.match(1), m.match(2), m.match(3), m.match(4), ""); 
      debug(parseln) writef("parseln: Label: '%s', OpCode: '%s', OP1: '%s', Extra: '%s', Comments: '%s'\n", "", m.match(1), m.match(2), m.match(3), m.match(4));
      tokens_assoc["type"]    = "opcode";
      tokens_assoc["label"]   = "";
      tokens_assoc["opcode"]  = m.match(1);
      tokens_assoc["op1"]     = m.match(2);
      tokens_assoc["extra"]   = m.match(3);
      tokens_assoc["comment"] = m.match(4);
    }
    // Let's just throw for funsies here
    else if (auto m = std.regexp.search(line, r"^\s*")) {
      debug(parseln) writef("parseln: [%3d]: empty line\n", line_num);
    }
    else {
      throw(new Exception("parseln: line [" ~ to!(string)(line_num) ~ "]: unable to parse '" ~ line ~ "'\n"));
    }

    // Opcode must be valid
    if (("opcode" in tokens_assoc) != null && (tokens_assoc["opcode"] in valid_opcodes.to_OpCode) == null)
      throw (new Exception(to!(string)(line_num) ~ ": Syntax error. OpCode(" ~ tokens_assoc["opcode"] ~ ") is no a valid opcode\n"));

    // OP1 can be a register, but it can't be a read only register, like PC
    if (("op1" in tokens_assoc) != null && (tokens_assoc["op1"] in valid_registers.to_Register) != null && (tokens_assoc["op1"] in valid_registers.read_only) != null) {
      //throw (new Exception(to!(string)(line_num) ~ ": Syntax error. OP1(" ~ tokens_assoc["op1"] ~ ") cannot be a read only register (ie: PC).\n"));
      stderr.writef("%d: Warning, read-only Register(%s) in use. Assembler has not implemented write protection. Use at your own risk.\n", line_num, tokens_assoc["op1"]);
    }

    // Set Addressing Mode to Register Indirect if the destination is a Register.
    // Currently only used by LDR, LDB, STR, STB
    tokens_assoc["mode"] = "0";
    string* destination = ("op2" in tokens_assoc);
    if (destination != null) { // op2 exists
      debug(parseln) writef("parseln: op2 exists (%s)\n", *destination);
      if ((*destination in valid_registers.to_Register) != null) // op2 is a Register
        tokens_assoc["mode"] = "1";
    }

    // Found extra code before a comment
    if (("extra" in tokens_assoc) != null && tokens_assoc["extra"] != "") {
      throw (new Exception(to!(string)(line_num) ~ ": Syntax error (" ~ tokens_assoc["extra"] ~ ") is extra.\n" ~ line));
    }
    return tokens_assoc;
  }

  bool is_symbol(string symbol) {
    auto sym = (symbol in symbol_table);
    return sym != null;
  }

  ByteCode[] get_program() {
    return program;
  }

  uint[string] get_symbols() {
    return symbol_table;
  }

public:
  this(string f) {
    header.data[1] = 0;
    valid_opcodes = new Valid_OpCodes();
    valid_directives = new Valid_Directives();
    valid_registers = new Valid_Registers();
    filename = f;
  }

  void write(string out_file) {
    File of;
    of.open(out_file, "w");
    of.rawWrite(program);
  }
  void assemble() {
    pass1();
    pass2();
  }

}

