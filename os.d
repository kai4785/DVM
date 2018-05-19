// UVU Operating System Project for CS-4510, depends on VM Project

import std.stdio;    // For STDIN, STDOUT, STDERR
import std.file;
import std.string;   // For strings
import std.getopt;   // For getting options from the commandline

import OperatingSystem;

int main(string args[]) {
    string script, disk;
    auto helpInfo = getopt(
        args,
        "script",  "Script to run", &script,
        "disk",    "Disk to open",  &disk,
    );
    if(helpInfo.helpWanted) {
        defaultGetoptPrinter("os: ", helpInfo.options);
        return 0;
    }
    OperatingSystem os = new OperatingSystem();
    if(!disk.empty) {
        os.set_disk(disk);
    }
    if(!script.empty) {
        File instream = File(script, "r");
        return os.shell(instream, true);
    }
    else
    {
        return os.shell(std.stdio.stdin);
    }
    return 0;
}
