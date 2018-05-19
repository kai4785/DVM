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

int main(string[] args)
{
    bool mkfs = false;
    string ls_path;
    string ll_path;
    string[] copy;
    string mkdir_path;
    string touch_path;
    size_t fs_size;
    string disk;
    int retval = 0;
    debug(args) stdio.stderr.writef("args pre-getopt: %s\n", args);
    arraySep = ",";
    getopt(args,
        "mkfs",   &mkfs,
        "size",   &fs_size,
        "disk",   &disk,
        "ll",     &ll_path,
        "ls",     &ls_path,
        "copy",   &copy,
        "mkdir",  &mkdir_path,
        "touch",  &touch_path
    );
    debug(args) stdio.stderr.writef("args post-getopt: %s\n", args);
    if(mkfs && fs_size)
    {
        if(fs_size > 0 && disk.length)
        {
            stdio.stdout.writef("Creating new filesystem on disk [%s] of size [%d]\n", disk, fs_size);
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
    if (ll_path.length)
    {
        stdio.stderr.writef("Listing entries for %s\n", ll_path);
        KFS.DISK = stdio.File(disk, "r+b");
        assert(KFS.isDir("/"));
        KFS.chdir(ll_path);
        foreach(e; KFS.dirEntries())
        {
            stdio.writef("%s %d\n", e.name, e.size);
        }

        KFS.DISK.close();
    }
    if (mkdir_path.length)
    {
        stdio.stderr.writef("KFS.mkdir: %s: ", mkdir_path);
        KFS.DISK = stdio.File(disk, "r+b");
        try
        {
            KFS.chdir("/");
            KFS.mkdir(mkdir_path);
            assert(KFS.isDir(mkdir_path));
        }
        catch(Exception e)
        {
            stdio.stderr.writef("mkdir %s failed: %s\n", mkdir_path, e.msg);
            retval = 1;
        }

        KFS.DISK.close();
    }
    if (touch_path.length)
    {
        stdio.stderr.writef("KFS.touch: %s\n", touch_path);
        KFS.DISK = stdio.File(disk, "r+b");
        KFS.chdir("/");
        KFS.touch(touch_path);
        assert(KFS.isFile(touch_path));

        KFS.DISK.close();
    }
    if (copy.length)
    {
        string copy_dest = "/";
        if(copy.length > 1) {
            copy_dest = copy[$-1];
            copy.length = copy.length - 1;
        }
        KFS.DISK = stdio.File(disk, "r+b");

        foreach(copy_from; copy) {
            string copy_to;
            if(copy_dest[$-1] == '/')
                copy_to = copy_dest ~ copy_from;
            else
                copy_to = copy_dest;
            stdio.stderr.writef("Copy file from host %s->%s\n", copy_from, copy_to);
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
                retval = 1;
            }
        }

        KFS.DISK.close();
    }
    stdio.stderr.writef("Done\n");
    return retval;
}
