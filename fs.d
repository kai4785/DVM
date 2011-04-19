// FileSystem utilities

import std.getopt;   // For getting options from the commandline
import std.string;
import std.array;

static import stdio = std.stdio;
static import file = std.file;
static import KFS = FileSystem;

import Utilities;

//debug = mkfs;
//debug = args;

void main(string[] args)
{
    bool mkfs = false;
    string ls_path;
    string ll_path;
    string copy_from;
    string copy_to;
    string mkdir_path;
    string touch_path;
    size_t fs_size;
    string disk;
    debug(args) stderr.writef("args pre-getopt: %s\n", args);
    getopt(args, "mkfs",  &mkfs, "size", &fs_size, "disk", &disk, "ll", &ll_path, "ls", &ls_path, "copy", &copy_from, "to", &copy_to, "mkdir", &mkdir_path, "touch", &touch_path);
    debug(args) stderr.writef("args post-getopt: %s\n", args);
    if(mkfs)
    {
        if(fs_size > 0 && disk.length)
        {
            debug(mkfs) stderr.writef("Creating new filesystem on disk [%s] of size [%d]\n", disk, fs_size);
            if(file.exists(disk))
                throw(new Exception(format("Unwilling to destroy existing file in mkfs: [%s]\n", disk)));
            KFS.DISK = stdio.File(disk, "w+b");
            KFS.mkfs(fs_size);

            KFS.DISK.close();
            //stderr.writef("Closed DISK.name[%s]\n", DISK.name);
        }
        else
        {
            stdio.stderr.writef("Not enough arguments\n");
        }
    }
    else if (ll_path.length)
    {
        stdio.stderr.writef("Listing entries for %s\n", ll_path);
        KFS.DISK = stdio.File(disk, "r+b");
        assert(KFS.isdir("/"));
        KFS.chdir(ll_path);
        foreach(e; KFS.dirEntries())
        {
            stdio.writef("%s %d\n", e.name, e.size);
        }

        KFS.DISK.close();
    }
    else if (mkdir_path.length)
    {
        stdio.stderr.writef("KFS.mkdir: %s: ", mkdir_path);
        KFS.DISK = stdio.File(disk, "r+b");
        try
        {
            KFS.chdir("/");
            KFS.mkdir(mkdir_path);
            assert(KFS.isdir(mkdir_path));
        }
        catch(Exception e)
        {
            stdio.stderr.writef("mkdir %s failed: %s\n", mkdir_path, e.msg);
        }

        KFS.DISK.close();
    }
    else if (touch_path.length)
    {
        stdio.stderr.writef("KFS.touch: %s\n", touch_path);
        KFS.DISK = stdio.File(disk, "r+b");
        KFS.chdir("/");
        KFS.touch(touch_path);
        assert(KFS.isfile(touch_path));

        KFS.DISK.close();
    }
    else if (copy_from.length && copy_to.length)
    {
        stdio.stderr.writef("Copy! %s->%s: ", copy_from, copy_to);

        KFS.DISK = stdio.File(disk, "r+b");
        try
        {
            //stdio.stderr.writef("Opening %s in \"r\" mode\n", copy_from);
            KFS.FileCompat infile = new KFS.FileCompat(stdio.File(copy_from, "r"));
            //stdio.stderr.writef("Opening %s in \"w+\" mode\n", copy_to);
            KFS.FileCompat outfile = new KFS.FileCompat(KFS.File(copy_to, "w+"));
            //stdio.stderr.writef("Done Opening files\n");

            ByteCode[] bytes;
            bytes.length = cast(uint)(std.file.getSize(copy_from));
            if(bytes.length)
            {
                infile.rawRead(bytes);
                outfile.rawWrite(bytes);
            }
            outfile.close();
            infile.close();
        }
        catch(Exception e)
        {
            stdio.stderr.writef("Opening %s failed: %s\n", copy_to, e.msg);
        }


        KFS.DISK.close();
    }
    else
    {
        stdio.stderr.writef("No recognized options\n");
    }
    stdio.stderr.writef("Done\n");
}
