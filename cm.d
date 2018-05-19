// Compiler

// usage: cm input.kxi [output.asm]

import std.stdio;
import Compiler;

int main(string[] args) {
    int retval = 0;
    if(args.length < 2) {
        stderr.writef("Need an input file.\n");
        return 1;
    }
    try {
        Tokenizer tokenizer = new Tokenizer(args[1]);
        Compiler compiler = new Compiler(tokenizer);
        compiler.run();
    } catch (Exception e){
        stderr.writef("Exception thrown! : %s\n", e.msg);
        retval = 1;
    }
    return retval;
}
