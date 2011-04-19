// UVU Operating System Project for CS-4510, depends on VM Project

import std.stdio;    // For STDIN, STDOUT, STDERR
import std.file;
import std.string;   // For strings
import std.getopt;   // For getting options from the commandline

import OperatingSystem;

void main(string args[]) {
    OperatingSystem os = new OperatingSystem();
    if(args.length > 1 && exists(args[1]) && isfile(args[1]))
    {
        File instream = File(args[1], "r");
        os.shell(instream, true);
    }
    else
    {
        os.shell(std.stdio.stdin);
    }
}
