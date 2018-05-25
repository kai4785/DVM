// Assembler

// usage: as input.asm [output.hex]

import std.stdio;
import std.getopt;   // For getting options from the commandline

import Assembler;

int main(string[] args) {
    int retval = 0;
    uint offset;
    getopt(args, "offset",  &offset);
    if(args.length != 3) {
        writeln("Sorry, you can't give me more or less than 2 files as an argument.");
        return(1);
    }
    // Execute the assembler
    Assembler assembler = new Assembler(args[1]);
    assembler.assemble();
    assembler.write(args[2]);
    return retval;
}
