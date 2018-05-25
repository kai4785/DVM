// FileSystem for OS project

module FileSystem;

static import std.stdio;
import std.stdio : stdin, stdout, stderr;
import std.file;
import std.conv;
import std.string;
import std.exception;
import std.bitmanip; // For BitArray and Unions http://www.digitalmars.com/d/2.0/phobos/std_bitmanip.html
import std.array : popBack, Appender, appender;
import std.datetime;

import Utilities;

//debug = Directory;
//debug = File;
//debug = KFSFilerawWrite;
//debug = KFSFilerawWrite1;
//debug = KFSFilerawRead;
//debug = KFSFilerawRead1;
//debug = KFSFilereadln;
//debug = debugFileCompat;
//debug = debugKFSFile;

enum KFStype {file, dir};
enum KFS {name_size = 16, block_size = 512, bitmap_block = 0, root_block = 1};
CWD cwd;
DiskDevice DISK;
alias ByteCode[KFS.block_size] BLOCK;

string getcwd()
{
    return cwd.path;
}

struct DiskDevice
{
private:
    std.stdio.File _DISK;
    //size_t rawWrite_count;
    //size_t rawRead_count;
    //size_t seek_count;
public:
    this(std.stdio.File disk)
    {
        _DISK = disk;
    }
    @property int error() { return _DISK.error; }
    void opAssign(std.stdio.File disk)
    {
        _DISK = disk;
        assert(!_DISK.error);
    }
    void seek(size_t pos)
    in 
    { 
        assert(pos % KFS.block_size == 0); 
        if(!(pos % KFS.block_size == 0))
            throw(new Exception(format("Can't seek to position [%d] in the disk file, since it is not the beginning of a block.", pos)));
        assert(!_DISK.error);
        if(_DISK.error)
            throw(new Exception(format("Can't seek to position [%d] in the disk file. The disk file has an error.", pos)));
        assert(_DISK.isOpen);
        if(!_DISK.isOpen)
            throw(new Exception(format("Can't seek to position [%d] in the disk file. The disk file is closed.", pos)));
    }
    body
    {
        //stderr.writef("seek_count = [%d]\n", ++seek_count);
        //pos = pos/KFS.block_size;
        if(pos >= 1048576)
        {
            stderr.writef("Going past the end of the filesystem: [%d:%d/1048576]\n", pos, pos/KFS.block_size);
        }
        _DISK.seek(pos);
    }
    void rawWrite(ByteCode[] bytes)
    in 
    { 
        assert(bytes.length == KFS.block_size);
        if(!(bytes.length == KFS.block_size))
            throw(new Exception(format("Can't read [%d] bytes, must ask for [%d] bytes from the disk.", bytes.length, KFS.block_size)));
        assert(!_DISK.error);
        if(_DISK.error)
            throw(new Exception(format("Can't read the disk file. The disk file has an error.")));
        assert(_DISK.isOpen);
        if(!_DISK.isOpen)
            throw(new Exception(format("Can't read the disk file. The disk file is closed.")));
    }
    body
    {
        //stderr.writef("rawWrite_count = [%d]\n", ++rawWrite_count);
        _DISK.rawWrite(bytes);
    }
    ByteCode[] rawRead(ByteCode[] bytes)
    in 
    { 
        assert(bytes.length == KFS.block_size);
        if(!(bytes.length == KFS.block_size))
            throw(new Exception(format("Can't write [%d] bytes, must ask for [%d] bytes from the disk.", bytes.length, KFS.block_size)));
        assert(!_DISK.error);
        if(_DISK.error)
            throw(new Exception(format("Can't write to the disk file. The disk file has an error.")));
        assert(_DISK.isOpen);
        if(!_DISK.isOpen)
            throw(new Exception(format("Can't write to the disk file. The disk file is closed.")));
    }
    body
    {
        //stderr.writef("rawRead_count = [%d]\n", ++rawRead_count);
        _DISK.rawRead(bytes);
        return bytes;
    }
    void close()
    {
        _DISK.close();
    }
}
BLOCK to_block(T)(T data)
{
    to_ByteCode!(T) bytes;
    bytes.data = data;
    BLOCK retval;
    //retval.length = KFS.block_size;
    retval[0..bytes.bytes.length] = bytes.bytes[0..$];
    return retval;
}

T from_block(T)(BLOCK bytes)
{
    to_ByteCode!(T) data;
    data.bytes[0..$] = bytes[0..data.bytes.length];
    return data.data;
}

void mkfs(size_t fs_size)
{
    // Create the empty file, KFS.block_size bytes at a time
    ByteCode[] zeros;
    zeros.length = KFS.block_size;
    zeros[0..$] = '\0';
    DISK.seek(0);
    for(size_t i = 0; i <= fs_size; i+= KFS.block_size)
        DISK.rawWrite(zeros);

    // Setup bitmap
    DiskManagement!(ulong[32]) bitmap;
    bitmap.block_size = KFS.block_size;
    bitmap.used = fs_size / KFS.block_size;
    //stderr.writef("mkfs: bitmap.sizeof[%d]\n", bitmap.sizeof);
    //stderr.writef("mkfs: bitmap with [%d] usable bits, using [%d] for file system of size [%d]K\n", bitmap.max_used, bitmap.used, fs_size / 1024);
    bitmap.set(KFS.bitmap_block * KFS.block_size);
    bitmap.set(KFS.root_block * KFS.block_size);
    //stderr.writef("mkfs: I have bitmap[%s]\n", bitmap);

    // Create "/" or root directory
    KFSDirectory rootdir = KFSDirectory(true);
    DISK.seek(KFS.root_block * KFS.block_size);
    DISK.rawWrite(to_block(rootdir));
    bitmap.set(KFS.root_block * KFS.block_size);

    // Store bitmap
    DISK.seek(KFS.bitmap_block * KFS.block_size);
    DISK.rawWrite(to_block(bitmap));

}

struct CWD
{
    string path;
    KFSDirectory dir;
    size_t block;
    this(string _path, KFSDirectory _dir, size_t _block)
    {
        path  = _path;
        dir   = _dir;
        block = _block;
    }
}

enum SpanMode { shallow };
alias DirEntry[] DirIterator;

DirIterator dirEntries(string path = cwd.path, SpanMode mode = SpanMode.shallow)
{
    CWD old_cwd = cwd;
    scope(exit) chdir(old_cwd.path);
    chdir(path);
    //stderr.writef("dirEntries: path[%s]\n", path);
    DirIterator retval = cwd.dir.entries();
    return retval;
}

KFSDirectory get_root()
in
{
    // TODO: Ensure that DISK is open
    assert(!DISK.error);
}
body
{
    BLOCK bytes;
    DISK.seek(KFS.root_block * KFS.block_size);
    DISK.rawRead(bytes);
    KFSDirectory root = from_block!(KFSDirectory)(bytes);
    return root;
}

BLOCK get_entry_block(string path)
{
    BLOCK retval;
    path = absolute_path(path);
    CWD old_cwd = cwd;
    scope(exit) chdir(old_cwd.path);
    if(path == "/")
    {
        retval = to_block(get_root());
    }
    else
    {
        string[] split = path.split("/");
        chdir(path, 1); // Cut 1 off the path, which should be the parent holding the entry
        DirEntry dirent = cwd.dir.entry_by_name(split[$-1]);
        if(dirent.name == split[$-1])
        {
            DISK.seek(dirent.block * KFS.block_size);
            DISK.rawRead(retval);
        }
        else
        {
            throw(new Exception(format("get_entry_block: File %s doesn't exist.", path)));
        }
    }
    return retval;
}

void set_entry_block(string path, BLOCK block)
{
    path = absolute_path(path);
    CWD old_cwd = cwd;
    scope(exit) chdir(old_cwd.path);
    if(path == "/")
    {
        DISK.seek(KFS.root_block * KFS.block_size);
        DISK.rawWrite(block);
    }
    else
    {
        string[] split = path.split("/");
        chdir(path, 1); // Cut 1 off the path, which should be the entry
        DirEntry dirent = cwd.dir.entry_by_name(split[$-1]);
        if(dirent.name == split[$-1])
        {
            DISK.seek(dirent.block * KFS.block_size);
            DISK.rawWrite(block);
        }
        else
        {
            throw(new Exception(format("set_entry_block: Successfully moved to parent directory of [%s], but [%s] wasn't there.", path, split[$-1])));
        }
    }
}

bool isDir(string path)
{
    BLOCK bytes = get_entry_block(path);
    KFSBlockHeader header = from_block!(KFSBlockHeader)(bytes);
    return (header.used && header.isDir);
}

bool isFile(string path)
{
    BLOCK bytes = get_entry_block(path);
    KFSBlockHeader header = from_block!(KFSBlockHeader)(bytes);
    return (header.used && header.isFile);
}

bool exists(string path)
{
    //stderr.writef("FileSystem.exists(%s)\n", path);
    bool retval;
    try
    {
        BLOCK bytes = get_entry_block(path);
        retval = true;
    }
    catch
    {
        retval = false;
    }
    return retval;
}

ulong getSize(string path)
{
    BLOCK bytes = get_entry_block(path);
    KFSBlockHeader header = from_block!(KFSBlockHeader)(bytes);
    if(header.isFile)
    {
        KFSFileEntry fileent = from_block!(KFSFileEntry)(bytes);
        return fileent.size;
    }
    else
    {
        return 0;
    }
}

void chdir(string path, size_t parent = 0)
in
{
    // TODO: Ensure that DISK is open
    assert(!DISK.error);
}
body
{
    // Update path to be absolute
    //stderr.writef("chdir: path [%s]\n", path);
    path = absolute_path(path);
    //if(path == cwd.path)
        //return;
    //stderr.writef("chdir: Absolute path [%s]\n", path);
    // Create a new CWD struct starting at /
    CWD new_cwd = CWD("/", get_root(), KFS.root_block);
    //CWD new_cwd;
    // Need bytes to read from the DISK
    BLOCK bytes;
    // Need to be able to check the entry
    to_ByteCode!(KFSBlockHeader) header;
    // Need to be able to read the dir
    to_ByteCode!(KFSDirectory) dir;
    // Need to be able to get the entry from the directory
    DirEntry dirent;

    string[] split = path.split("/");
    foreach(i; 1..split.length - parent)
    {
        if(split[i].length)
        {
            // Get the entry from the CWD that matches the current path element
            dirent = new_cwd.dir.entry_by_name(split[i]);
            // If it exists
            //stderr.writef("chdir: hoping that %s == %s, looking in %s, got %s\n", dirent.name, split[i], new_cwd.path, new_cwd.dir.entries());
            if(dirent.name == split[i])
            {
                //, and is a directory, update CWD to be the new directory, otherwise throw an exception
                DISK.seek(dirent.block * KFS.block_size);
                DISK.rawRead(bytes);
                header.bytes[0..$] = bytes[0..header.bytes.length];
                //stderr.writef("KFSBlockHeader for %s: [%s](%d)(%d)\n",  split[0..i + 1].join("/"), header.data, bytes[0], header.data.attributes);
                if(!header.data.used || !header.data.isDir)
                {
                    throw(new Exception(format("%s is not a directory in %s\n", split[i], split[0..i])));
                }
                dir.bytes[0..$] = bytes[0..dir.bytes.length];
                new_cwd = CWD(split[0..i + 1].join("/"), dir.data, dirent.block);
                //stderr.writef("isDir: %s is a directory\n", split[0..i + 1]);
            }
            else
            {
                throw(new Exception(format("%s/%s does not exist.", absolute_path(split[0..i].join("/")), split[i])));
            }
        }
    }
    cwd = new_cwd;
}

void mkdir(string path)
{
    //stderr.writef("mkdir: path %s\n", path);
    path = absolute_path(path);
    CWD old_cwd = cwd;
    scope(exit) chdir(old_cwd.path);
    if(!exists(path))
    {
        //stderr.writef("mkdir: absolute_path %s\n", path);
        string[] split = path.split("/");
        // Since we want to use cwd for our work, let's keep a hold of where we were, so we can go back.
        // chdir to the parent
        chdir(split[0..$-1].join("/"));
        chdir(path, 1); // Cut one off the path and chdir there
        // Need a container to read and write a KFSDirectory to the disk
        KFSDirectory dir;

        // Create new entry in the parent
        size_t new_block = allocate_block();
        //stderr.writef("mkdir: got new block[%d]\n", new_block);
        cwd.dir.add_entry(split[$-1], new_block);
        //stderr.writef("mkdir: path[%s], entries[%s]\n", cwd.path, cwd.dir.entries());

        // Write new folder out to disk
        dir = KFSDirectory(true);
        dir.header.createTime = to!(size_t)(Clock.currTime().toUnixTime());
        dir.header.lastWriteTime = 0;
        DISK.seek(new_block * KFS.block_size);
        DISK.rawWrite(to_block(dir));

        // Write folder out to disk with new entry
        dir = cwd.dir;
        DISK.seek(cwd.block * KFS.block_size);
        DISK.rawWrite(to_block(dir));
        assert(exists(path));
        assert(isDir(path));
        //stderr.writef("mkdir: isDir %s\n", path);
        chdir(path);
        //stderr.writef("mkdir: chdir %s\n", path);

        // Go back where we started
    }
    else
    {
        throw(new Exception(format("%s already exists", path)));
    }
}

void touch(string path)
{
    //stderr.writef("touch: path %s\n", path);
    path = absolute_path(path);
    //stderr.writef("touch: absolute_path %s\n", path);
    string[] split = path.split("/");
    // Since we want to use cwd for our work, let's keep a hold of where we were, so we can go back.
    CWD old_cwd = cwd;
    scope(exit) chdir(old_cwd.path);
    // chdir to the parent
    //chdir(split[0..$-1].join("/"));
    chdir(path, 1);
    // Need a container to read and write a KFSDirectory to the disk
    KFSDirectory dir;
    KFSFileEntry file;
    DirEntry dirent = cwd.dir.entry_by_name(split[$-1]);

    if(dirent.name != split[$-1])
    {
        // Create new entry in the parent
        size_t new_block = allocate_block();
        //stderr.writef("touch: got new block[%d]\n", new_block);
        cwd.dir.add_entry(split[$-1], new_block);
        //stderr.writef("touch: creating file %s in %s at block %d\n", split[$-1], cwd.path, new_block);

        // Write new folder out to disk
        //dir = KFSDirectory(true);
        file = KFSFileEntry(true);
        file.header.createTime = to!(size_t)(Clock.currTime().toUnixTime());
        file.header.lastWriteTime = 0;
        DISK.seek(new_block * KFS.block_size);
        DISK.rawWrite(to_block(file));

        // Write folder out to disk with new entry
        dir = cwd.dir;
        DISK.seek(cwd.block * KFS.block_size);
        DISK.rawWrite(to_block(dir));
    }
    else
    {
        stderr.writef("Touching file that exists\n");
    }
    assert(exists(path));
    //stderr.writef("touch: %s entries()[%s]\n", cwd.path, cwd.dir.entries());
    assert(isFile(path));
}

void copy(string src_path, string dst_path)
{
    //stderr.writef("copy: src_path %s, dst_path %s\n", src_path, dst_path);
    src_path = absolute_path(src_path);
    dst_path = absolute_path(dst_path);
    //stderr.writef("copy: src_path %s, dst_path %s\n", src_path, dst_path);


    // TODO: Make this work for really large files
    FileCompat src_file = new FileCompat(File(src_path, "r"));
    // BUG: There is a bug where the following FileCompat causes the src_file's size to get set to 0 somewhere if src_file is created by a hard link to a file that was subsequently deleted. 
    // ie: 
    //   ln orig.txt orig.link
    //   rm orig.txt
    //   cp orig.link orig.copy
    //
    //FileCompat dst_file = new FileCompat(File(dst_path, "w"));
    ByteCode[] buffer;
    src_file.rawRead(buffer);
    src_file.close();

    // BUG: cont...
    // So I moved it down here.
    FileCompat dst_file = new FileCompat(File(dst_path, "w"));
    if(buffer.length)
        dst_file.rawWrite(buffer);
    dst_file.close();

    assert(exists(src_path));
    assert(exists(dst_path));
}

void remove(string path)
{
    //stderr.writef("remove: path %s\n", path);
    path = absolute_path(path);
    //stderr.writef("remove: absolute_path %s\n", path);
    string[] split = path.split("/");
    // Since we want to use cwd for our work, let's keep a hold of where we were, so we can go back.
    CWD old_cwd = cwd;
    scope(exit) chdir(old_cwd.path);
    // chdir to the parent
    //chdir(split[0..$-1].join("/"));
    chdir(path, 1);
    // Need a container to read and write a KFSDirectory to the disk
    KFSDirectory dir;
    KFSFileEntry file;
    DirEntry dirent = cwd.dir.entry_by_name(split[$-1]);

    if(dirent.exists)
    {
        //stderr.writef("Need to remove entry %s\n", dirent.name);
        // if file
        if(dirent.isFile)
        {
            // free all data blocks
            KFSFileEntry deleteme = from_block!(KFSFileEntry)(dirent.entry_block);
            size_t num_blocks = (deleteme.size + KFS.block_size - 1) / KFS.block_size;
            //stderr.writef("It's a file of size[%d] and number of blocks[%d]\n", dirent.size, num_blocks);
            deleteme.header.ref_count = deleteme.header.ref_count - 1;
            if(deleteme.header.ref_count == 0)
            {
                foreach(i; 0..(deleteme.size + KFS.block_size - 1) / KFS.block_size)
                {
                    //stderr.writef("Deleting block[%d][%d]\n", i, deleteme.blocks[i]);
                    free_block(deleteme.blocks[i]);
                }
            }
        }
        // if dir
        else if(dirent.isDir)
        {
            // if used_blocks == 0 error
            KFSDirectory deleteme = from_block!(KFSDirectory)(dirent.entry_block);
            //stderr.writef("It's a dir with [%d] used_blocks\n", deleteme.used_blocks);
            if(deleteme.used_blocks > 0)
            {
                throw(new Exception(format("Can't remove non-empty folder %s", path)));
            }
        }
        else
        {
            stderr.writef("I don't know how to remove [%s] at block[%d]\n", dirent.name, dirent.block);
        }
        // free dirent.block
        free_block(dirent.block);

        // Remove the entry from the folder
        cwd.dir.del_entry(dirent.name);
        // Write folder out to disk with new entry
        dir = cwd.dir;
        DISK.seek(cwd.block * KFS.block_size);
        DISK.rawWrite(to_block(dir));
    }
    else
    {
        throw(new Exception(format("remove: File %s doesn't exist", path)));
    }
}

void rename(string src_path, string dst_path)
{
    //stderr.writef("rename: src_path %s, dst_path %s\n", src_path, dst_path);
    src_path = absolute_path(src_path);
    dst_path = absolute_path(dst_path);
    //stderr.writef("rename: src_path %s, dst_path %s\n", src_path, dst_path);
    string[] src_split = src_path.split("/");
    string[] dst_split = dst_path.split("/");

    CWD old_cwd = cwd;
    scope(exit) chdir(old_cwd.path);

    chdir(src_path, 1);
    DirEntry src_dirent = cwd.dir.entry_by_name(src_split[$-1]);
    if(src_dirent.exists)
    {
        // src exists
        CWD src_cwd = cwd;
        // Check if destination exists
        chdir(dst_path, 1);
        DirEntry dst_dirent = cwd.dir.entry_by_name(dst_split[$-1]);
        if(!dst_dirent.exists)
        {
            //stderr.writef("Adding %s to %s\n", dst_split[$-1], cwd.path);
            cwd.dir.add_entry(dst_split[$-1], src_dirent.block);
            // write dir out to disk
            DISK.seek(cwd.block * KFS.block_size);
            DISK.rawWrite(to_block(cwd.dir));
        }
        else
        {
            throw(new Exception(format("rename: destination exists [%s]", dst_path)));
            // TODO: Support the case when this is a directory
        }

        // Go back to src_cwd and remove entry
        chdir(src_cwd.path);
        cwd.dir.del_entry(src_dirent.name);
        // write dir out to disk
        DISK.seek(cwd.block * KFS.block_size);
        DISK.rawWrite(to_block(cwd.dir));
    }
    else
    {
        throw(new Exception(format("rename: source does not exist [%s]", dst_path)));
    }
}

void link(string src_path, string dst_path)
{
    //stderr.writef("link: src_path %s, dst_path %s\n", src_path, dst_path);
    src_path = absolute_path(src_path);
    dst_path = absolute_path(dst_path);
    //stderr.writef("link: src_path %s, dst_path %s\n", src_path, dst_path);
    string[] src_split = src_path.split("/");
    string[] dst_split = dst_path.split("/");

    CWD old_cwd = cwd;
    scope(exit) chdir(old_cwd.path);

    chdir(src_path, 1);
    DirEntry src_dirent = cwd.dir.entry_by_name(src_split[$-1]);
    if(src_dirent.exists)
    {
        // src exists
        CWD src_cwd = cwd;
        // Check if destination exists
        chdir(dst_path, 1);
        DirEntry dst_dirent = cwd.dir.entry_by_name(dst_split[$-1]);
        if(!dst_dirent.exists)
        {
            //stderr.writef("Adding %s to %s\n", dst_split[$-1], cwd.path);
            cwd.dir.add_entry(dst_split[$-1], src_dirent.block);
            // write dir out to disk
            DISK.seek(cwd.block * KFS.block_size);
            DISK.rawWrite(to_block(cwd.dir));

            // Update Link count in the KFSFileEntry
            BLOCK fileentry_block;
            DISK.seek(src_dirent.block * KFS.block_size);
            DISK.rawRead(fileentry_block);
            KFSFileEntry fileentry = from_block!(KFSFileEntry)(fileentry_block);
            fileentry.header.ref_count = fileentry.header.ref_count + 1;
            fileentry.header.lastWriteTime = to!(size_t)(Clock.currTime().toUnixTime());
            fileentry_block = to_block(fileentry);
            DISK.seek(src_dirent.block * KFS.block_size);
            DISK.rawWrite(fileentry_block);
        }
        else
        {
            throw(new Exception(format("link: destination exists [%s]", dst_path)));
            // TODO: Support the case when this is a directory
        }

        // Go back to src_cwd and remove entry
        //chdir(src_cwd.path);
        //cwd.dir.del_entry(src_dirent.name);
        // write dir out to disk
        //DISK.seek(cwd.block * KFS.block_size);
        //DISK.rawWrite(to_block(cwd.dir));
    }
    else
    {
        throw(new Exception(format("link: source does not exist [%s]", dst_path)));
    }
}

//bool[uint] blocks_allocated;
size_t allocate_block()
{
    size_t retval = 0;
    // Read in the Bitmap
    BLOCK bytes;
    DISK.seek(KFS.bitmap_block * KFS.block_size);
    DISK.rawRead(bytes);
    DiskManagement!(ulong[32]) bitmap = from_block!(DiskManagement!(ulong[32]))(bytes);
    // Allocate a block
    //stderr.writef("mkfs: I have bitmap used[%d / %d]\n", bitmap.count(true), bitmap.max_used);
    try
    {
        retval = bitmap.allocate(KFS.block_size) / KFS.block_size;
    }
    catch(Exception e)
    {
        stderr.writef("Unable to allocate in the bitmap: %s\n", e.msg);
        throw(e);
    }
    //stderr.writef("allocate_block:I have bitmap used[%d / %d]\n", bitmap.count(true), bitmap.max_used);
    // Write the bitmap back out to disk
    bytes = to_block(bitmap);
    DISK.seek(KFS.bitmap_block * KFS.block_size);
    DISK.rawWrite(bytes);
    //stderr.writef("allocate_block: returning block [%d]\n", retval);
    //enforce(!blocks_allocated.get(retval, false), format("Already allocated %d\n", retval));
    //blocks_allocated[retval] = true;
    return retval;
}

void free_block(size_t block)
{
    // Read in the Bitmap
    BLOCK bytes;
    DISK.seek(KFS.bitmap_block * KFS.block_size);
    DISK.rawRead(bytes);
    DiskManagement!(ulong[32]) bitmap = from_block!(DiskManagement!(ulong[32]))(bytes);
    // Free a block
    //stderr.writef("mkfs: I have bitmap used[%d / %d]\n", bitmap.count(true), bitmap.max_used);
    bitmap.free(KFS.block_size, block * KFS.block_size);
    //stderr.writef("mkfs: I have bitmap used[%d / %d]\n", bitmap.count(true), bitmap.max_used);
    // Write the bitmap back out to disk
    bytes = to_block(bitmap);
    DISK.seek(KFS.bitmap_block * KFS.block_size);
    DISK.rawWrite(bytes);
}

string absolute_path(string path)
{
    // Don't need trailing slash, which emptys the string if it is just "/"
    path = chomp(path);
    // If the path is not empty, and does not begin with a slash, put the cwd.path infront
    if(path.length && path[0] != '/')
        path = cwd.path ~ "/" ~ path;
    string[] retval;
    foreach(p; path.split("/"))
    {
        if(p == "..")
            retval.popBack;
        else if (p.length && p != ".")
            retval ~= p;
    }
    return "/" ~ retval.join("/");
}

unittest
{
    CWD old_cwd = cwd;
    cwd.path = "/home";
    assert(absolute_path("/") == "/");
    assert(absolute_path(".") == cwd.path);
    assert(absolute_path("./home") == cwd.path ~ "/home");
    assert(absolute_path("..") == "/");
    assert(absolute_path("/foo") == "/foo");
    assert(absolute_path("/foo/") == "/foo");
    assert(absolute_path("/foo/..") == "/");
    assert(absolute_path("/foo/../") == "/");
    assert(absolute_path("/foo/bar/") == "/foo/bar");
    assert(absolute_path("/foo/bar/..") == "/foo");
    assert(absolute_path("/foo/bar/../") == "/foo");
    assert(absolute_path("/./foo/") == "/foo");
    assert(absolute_path("/foo/./") == "/foo");
    assert(absolute_path("/foo/./bar") == "/foo/bar");
    assert(absolute_path("/foo/./bar/") == "/foo/bar");
    cwd = old_cwd;
}




struct KFSBlockHeader
{
    // We could put permissions here
    union
    {
        ubyte attributes;
        mixin(bitfields!(
            size_t, "createTime", 35,
            size_t, "lastWriteTime", 18,
            size_t, "ref_count", 8,
            bool, "used",   1,
            bool, "isDir",  1,
            bool, "isFile", 1,
            )
        );
    }
    string toString()
    {
        return format("%s %s %s", used, isDir, isFile);
    }
}

//struct KFSInode
struct KFSFileEntry
{
private:
public:
    KFSBlockHeader header;
    size_t size;
    size_t[(KFS.block_size - header.sizeof - size_t.sizeof) / size_t.sizeof] blocks;
    this(bool used)
    {
        header.attributes = 0;
        header.used = used;
        header.isFile = true;
        header.ref_count = 1;
    }
}

struct KFSDataEntry
{
private:
public:
    KFSBlockHeader header;
    ByteCode[KFS.block_size - header.sizeof] data;
    this(bool used)
    {
        header.attributes = 0;
        header.used = used;
        header.isFile = true;
    }
}

// This is the IO struct that does the actual transaction with the disk.
struct File
{
private:
    KFSFileEntry entry;
    size_t pos;
    string name;
    union
    {
        ubyte modes;
        mixin(bitfields!(
            bool, "mode_read",   1,
            bool, "mode_write",  1,
            bool, "mode_append", 1,
            bool, "",            5,
            )
        );
    }
    union
    {
        ubyte status;
        mixin(bitfields!(
            bool, "_eof",    1,
            bool, "_error",  1,
            bool, "_opened", 1,
            bool, "",       5,
            )
        );
    }
public:
    this(string _name, string mode)
    in { assert(mode.length); }
    body
    {
        debug(debugKFSFile) stderr.writef("KFSFile.this(%s, %s)\n", _name, mode);
        name = _name;
        pos = 0;
        modes = 0;
        if(mode[0] == 'r')
            mode_read = true;
        if(mode[0] == 'w')
        {
            mode_write = true;
            touch(name);
        }
        if(mode[0] == 'a')
        {
            mode_append = true;
            touch(name);
        }
        if(mode.length > 1)
        {
            foreach(c; mode[1..$])
            {
                if(c == '+')
                {
                    if(mode_read)
                        mode_write = true;
                    if(mode_write || mode_append)
                        mode_read = true;
                }
            }
        }
        status = 0;
        _opened = true;
        entry = from_block!(KFSFileEntry)(get_entry_block(name));
        if(mode[0] == 'w')
        {
            //stderr.writef("Setting entry.size to 0 for %s\n", name);
            entry.size = 0;
        }
    }
    this(File f)
    {
        entry = f.entry;
        modes = f.modes;
        pos = f.pos;
    }

    T[] rawRead(T)(ref T[] buffer)
    in {assert (pos <= entry.size);}
    out {assert (pos <= entry.size);}
    body
    {
        entry = from_block!(KFSFileEntry)(get_entry_block(name));
        size_t read_so_far = 0;
        KFSDataEntry data_block;
        debug(KFSFilerawRead) stderr.writef("KFSFile.rawRead: pos[%d], entry.size[%d], buffer.length[%d]\n", pos, entry.size, buffer.length);
        debug(KFSFilerawRead) stderr.writef("KFSFile.rawRead: read_so_far[%d] < buffer.length[%d] && pos[%d] < entry.size[%d]\n", read_so_far, buffer.length, pos, entry.size);
        if(!buffer.length)
            buffer.length = entry.size - pos;
        while(read_so_far < buffer.length && pos < entry.size)
        {
            // Which block do I need to read in?
            size_t block_i = pos / data_block.data.length;
            size_t DISK_block = entry.blocks[block_i];
            size_t block_offset = pos % data_block.data.length;
            debug(KFSFilerawRead) stderr.writef("KFSFile.rawRead: block_i[%d] DISK_block[%d], block_offset[%d]\n", block_i, DISK_block, block_offset);
            // Read the block of data
            BLOCK bytes;
            DISK.seek(DISK_block * KFS.block_size);
            DISK.rawRead(bytes);
            debug(KFSFilerawRead1) stderr.writef("KFSFile.rawRead: Read in block [%d] with contents %s\n", DISK_block, bytes);
            // Stuff block into KFSDataEntry
            data_block = from_block!(KFSDataEntry)(bytes);
            // Copy the blocks to the return value
            // How many bytes to copy? Start in data_block.data at block_offset, and go until you reach the end of data_block.data, or you reach the end of buffer.
            // Of data_block.data, we need block_offset -> min(data_block.data.length, buffer.length);
            debug(KFSFilerawRead) stderr.writef("KFSFile.rawRead: data_block.data.length[%d] < block_offset[%d] + buffer.length[%d] - read_so_far[%d] = [%d]\n", 
                data_block.data.length,
                block_offset,
                buffer.length,
                read_so_far,
                block_offset + buffer.length - read_so_far
            );
            if(data_block.data.length < block_offset + buffer.length - read_so_far)
            {
                debug(KFSFilerawRead) stderr.writef("KFSFile.rawRead: read to end of data_block: buffer[%d..%d] = data_block.data[%d..%d]\n", 
                    read_so_far,
                    read_so_far + data_block.data.length - block_offset,
                    block_offset,
                    data_block.data.length
                );
                buffer[read_so_far..read_so_far + data_block.data.length - block_offset] = data_block.data[block_offset..$];
                // Update counters
                pos += data_block.data.length - block_offset;
                read_so_far += data_block.data.length - block_offset;
            }
            else
            {
                debug(KFSFilerawRead) stderr.writef("KFSFile.rawRead: read to end of buffer: buffer[%d..%d] = data_block.data[%d..%d]\n", 
                    read_so_far,
                    buffer.length,
                    block_offset,
                    block_offset + buffer.length - read_so_far,
                    //data_block.data[block_offset..block_offset + buffer.length - read_so_far]
                );
                buffer[read_so_far..$] = data_block.data[block_offset..block_offset + buffer.length - read_so_far];
                // Update counters
                pos += buffer.length - read_so_far;
                read_so_far += buffer.length - read_so_far;
            }
            debug(KFSFilerawRead) stderr.writef("KFSFile.rawRead: loop, read_so_far[%d]\n", read_so_far);
        }
        // Check to see if we need to set eof
        if(pos == entry.size)
            _eof = true;
        else
            _eof = false;
        debug(KFSFilerawRead) stderr.writef("KFSFile.rawRead: buffer: %s\n", buffer);
        debug(KFSFilerawRead) stderr.writef("KFSFile.rawRead: pos[%d], entry.size[%d]\n", pos, entry.size);
        return buffer;
    }

    void rawWrite(T)(T[] buffer)
    in {assert (pos <= entry.size);}
    out { assert (pos <= entry.size); }
    body
    {
        entry = from_block!(KFSFileEntry)(get_entry_block(name));
        if(mode_append)
            pos = entry.size;
        size_t written_so_far = 0;
        KFSDataEntry data_block;
        debug(KFSFilerawWrite) stderr.writef("KFSFile.rawWrite: pos[%d], entry.size[%d], buffer.length[%d]\n", pos, entry.size, buffer.length);
        // If we are writing past the end of size (pos + buffer.length > entry.size)
        debug(KFSFilerawWrite) stderr.writef("KFSFile.rawWrite: (pos[%d] + buffer.length[%d] - 1) / %d + 1 = [%d] > (entry.size[%d] - 1) / %d = [%d] || (entry.size[%d] == 0 && pos[%d] + buffer.length[%d] = > 0) == [%s]\n",
            pos, 
            buffer.length, 
            data_block.data.length,
            (pos + buffer.length - 1) / data_block.data.length + 1,
            entry.size,
            data_block.data.length,
            (entry.size + data_block.data.length - 1) / data_block.data.length,
            entry.size,
            pos,
            buffer.length,
            (entry.size == 0 && pos + buffer.length > 0)
        );
        if((pos + buffer.length + data_block.data.length - 1) / data_block.data.length > (entry.size + data_block.data.length - 1) / data_block.data.length || (entry.size == 0 && pos + buffer.length > 0))
        {
            // Allocate blocks needed (it's ok if they aren't sequential, but they will be if we iterate)
            size_t block_i = (pos + buffer.length) / data_block.data.length;
            debug(KFSFilerawWrite) 
            {
                stderr.writef("KFSFile.rawWrite: I have [%d] blocks allocated, and I need to have a total of %d\n", 
                    (entry.size + data_block.data.length - 1) / data_block.data.length, 
                    (pos + buffer.length + data_block.data.length - 1) / data_block.data.length
                );
            }
            enforce((pos + buffer.length + data_block.data.length - 1) / data_block.data.length < entry.blocks.length,
                format("Unable to allocate a new block file I/O (file is too big) [%d/%d]. %d bytes will not be written.", 
                    (pos + buffer.length + data_block.data.length - 1) / data_block.data.length, 
                    entry.blocks.length,
                    buffer.length
                    )
                );
            foreach(i; (entry.size + data_block.data.length - 1) / data_block.data.length..(pos + buffer.length + data_block.data.length - 1) / data_block.data.length)
            {
                enforce(i < entry.blocks.length, format("Unable to allocate a new block file I/O (file is too big) [%d/%d]", i, entry.blocks.length));
                entry.blocks[i] = allocate_block();
                debug(KFSFilerawWrite) stderr.writef("KFSFile.rawWrite: allocated block[%d] = [%d]\n", i, entry.blocks[block_i]);
            }
        }
        if(pos + buffer.length > entry.size)
            entry.size = pos + buffer.length;
        debug(KFSFilerawWrite) stderr.writef("KFSFile.rawWrite: written_so_far[%d] < buffer.length[%d] && pos[%d] < entry.size[%d]\n", written_so_far, buffer.length, pos, entry.size);
        while(written_so_far < buffer.length && pos < entry.size)
        {
            // Which block do I need to write in, starting where?
            size_t block_i = pos / data_block.data.length;
            size_t DISK_block = entry.blocks[block_i];
            size_t block_offset = pos % data_block.data.length;
            debug(KFSFilerawWrite) stderr.writef("KFSFile.rawWrite: block_i[%d], DISK_block[%d], block_offset[%d], pos[%d], written_so_far[%d]\n", block_i, DISK_block, block_offset, pos, written_so_far);
            assert(DISK_block != KFS.root_block && DISK_block != KFS.bitmap_block);
            // Read the block of data
            BLOCK bytes;
            DISK.seek(DISK_block * KFS.block_size);
            DISK.rawRead(bytes);
            // Stuff block into KFSDataEntry
            data_block = from_block!(KFSDataEntry)(bytes);
            // Copy the blocks to the return value
            // How many bytes to copy? Start in buffer at written_so_far, and go to either the end of buffer or the end of data_block
            // Of buffer, we need written_so_far -> min(buffer.length, data_block.data.length);
            debug(KFSFilerawWrite) stderr.writef("KFSFile.rawWrite: data_block.data.length[%d] - block_offset[%d] < buffer.length[%d] - written_so_far[%d]\n", data_block.data.length, block_offset, buffer.length, written_so_far);
            if(data_block.data.length - block_offset < buffer.length - written_so_far)
            {
                debug(KFSFilerawWrite) stderr.writef("KFSFile.rawWrite: writing to the end of a block. data_block.data[%d..%d] = buffer[%d..%d]\n",
                    block_offset,
                    data_block.data.length,
                    written_so_far,
                    written_so_far + data_block.data.length - block_offset
                );
                data_block.data[block_offset..$] = buffer[written_so_far..written_so_far + data_block.data.length - block_offset];
                // Update counters
                pos += data_block.data.length - block_offset;
                written_so_far += data_block.data.length - block_offset;
            }
            else
            {
                debug(KFSFilerawWrite) stderr.writef("KFSFile.rawWrite: writing a partial block. data_block.data[%d..%d] = buffer[%d..%d]\n",
                    block_offset,
                    block_offset + buffer.length - written_so_far,
                    written_so_far,
                    buffer.length
                );
                data_block.data[block_offset..block_offset + buffer.length - written_so_far] = buffer[written_so_far..$];
                // Update counters
                pos += buffer.length - written_so_far;
                written_so_far += buffer.length - written_so_far;
            }
            // Read the block of data
            bytes = to_block!(KFSDataEntry)(data_block);
            DISK.seek(DISK_block * KFS.block_size);
            DISK.rawWrite(bytes);
            debug(KFSFilerawWrite1) stderr.writef("KFSFile.rawWrite: Wrote block[%d] with %s\n", DISK_block, data_block.data);
            DISK.seek(DISK_block * KFS.block_size);
            DISK.rawRead(bytes);
            debug(KFSFilerawWrite1) stderr.writef("KFSFile.rawWrite: Read block[%d] with %s\n", DISK_block, data_block.data);
        }
        // Check to see if we need to set eof
        if(pos == entry.size)
            _eof = true;
        else
            _eof = false;
        debug(KFSFilerawWrite) stderr.writef("KFSFile.rawWrite: pos[%d], entry.size[%d]\n", pos, entry.size);
        entry.header.lastWriteTime = to!(size_t)(Clock.currTime().toUnixTime()) - entry.header.createTime;
        set_entry_block(name, to_block(entry));
    }
    string readln()
    in {assert (pos <= entry.size);}
    out {assert (pos <= entry.size);}
    body
    {
        entry = from_block!(KFSFileEntry)(get_entry_block(name));
        Appender!(string) retval = appender!(string)();
        ByteCode[] bytes;
        bytes.length = entry.size - pos;

        debug(KFSFilereadln) stderr.writef("KFSFile.readln: reading [%d] bytes for readln\n", bytes.length);
        rawRead(bytes);
        foreach(b; bytes)
        {
            retval.put(to!(char)(b));
            if(to!(char)(b) == '\n')
                break;
        }

        pos -= bytes.length - retval.data.length;
        if(pos == entry.size)
            _eof = true;
        else
            _eof = false;

        return retval.data;
    }
    void write(T)(T t)
    in {assert (pos <= entry.size);}
    out {assert (pos <= entry.size);}
    body
    {
        debug(KFSFilerawWrite) stderr.writef("KFSFile.write(%s %s)\n", T.stringof, t);
        string writer = format("%s", t);
        ByteCode[] bytes;
        bytes.length = writer.length;
        foreach(i; 0..writer.length)
        {
            bytes[i] = cast(ByteCode)(writer[i]);
        }
        rawWrite(bytes);
    }
    void close()
    {
        // Write out the entry
        debug(KFSFilerawWrite) stderr.writef("KFSFile.close: Writing entry block out for [%s] of size [%d], block[0][%d], pos[%d]\n", name, entry.size, entry.blocks[0], pos);
        // set opened to false
        _opened = false;
    }
    void seek(size_t new_pos)
    in {assert (pos <= entry.size);}
    out {assert (pos <= entry.size);}
    body
    {
        if(new_pos <= entry.size)
            pos = new_pos;
        else
            throw(new Exception(format("KFSFile: Unable to seek to byte [%d], which is beyond the size of the file[%d]", new_pos, entry.size)));
    }

    @property
    {
        bool eof() { return _eof; }
        bool isOpen() { return _opened; }
        bool error() { return _error; }
    }
}

struct DirEntry
{
private:
    ulong _size;
    string path;
    bool didstat;    // Lazy evaluation, hurray!
public:
    KFSEntry entry;
    KFSBlockHeader header;
    BLOCK entry_block;
    this(KFSEntry _entry, string p = "")
    {
        path = p;
        entry = _entry;
    }

    bool isDir()
    {
        ensureStatDone();
        return header.isDir;
    }

    bool isFile()
    {
        ensureStatDone();
        return header.isFile;
    }
    
    ulong size()
    {
        ensureStatDone();
        return _size;
    }

    bool exists()
    {
        ensureStatDone();
        return(name != "/");
    }

    @property SysTime timeLastModified()
    {
        ensureStatDone();
        return SysTime(unixTimeToStdTime(header.createTime + header.lastWriteTime));
    }

    @property SysTime timeCreated()
    {
        ensureStatDone();
        return SysTime(unixTimeToStdTime(header.createTime));
    }

    void ensureStatDone()
    {
        if(!didstat)
        {
            didstat = true;
            DISK.seek(entry.block * KFS.block_size);
            DISK.rawRead(entry_block);
            header = from_block!(KFSBlockHeader)(entry_block);
            if(header.isFile)
            {
                KFSFileEntry file = from_block!(KFSFileEntry)(entry_block);
                _size = file.size;
            }
        }
    }

    @property string name()
    {
        //stderr.writef("path[%s], cwd.path[%s]\n", path, cwd.path);
        if(cwd.path == path)
            return entry.name;
        else
            return path ~ "/" ~ entry.name;
    }
    @property size_t block()
    {
        return entry.block;
    }
}

struct KFSEntry
{
private:
    char[KFS.name_size] _name;
public:
    size_t block;
    this(char[KFS.name_size] new_name, size_t new_block)
    {
        _name = new_name;
        block = new_block;
    }

    this(string new_name, size_t new_block)
    {
        name = new_name;
        block = new_block;
    }

    string toString()
    {
        return format("%s : %d", name, block);
    }

    void deallocate()
    {
        _name[0..$] = char.max;
    }

    @property
    {
        string name() 
        { 
            Appender!(string) retval = appender!(string)();
            size_t i = 0;
            while(_name[i] != char.max && i < _name.length - 1)
            {
                retval.put(_name[i++]);
            }
            return retval.data;
        }
        void name(string new_name) {
            if(new_name.length >= KFS.name_size)
            {
                stderr.writef("Unsupported name length of [%d]. Limit names to size [%d]\n", new_name.length, KFS.name_size);
                return;
            }
            _name[0..new_name.length] = new_name[0..$];
            _name[new_name.length..$] = char.max;
        }
    }
}

struct KFSDirectory
{
private:
public:
    KFSBlockHeader header;
    KFSEntry[(KFS.block_size - header.sizeof) / KFSEntry.sizeof] nameblocks;

    this(bool used)
    {
        header.used = used;
        header.isDir = true;
    }

    void add_entry(string name, size_t block)
    {
        debug(Directory) stderr.writef("add_entry: [%s] [%d]\n", name, block);
        if(used_blocks >= file_limit)
        {
            throw(new Exception(format("Unable to add file with name [%s]: Directory is full [%d/%d]\n", name, used_blocks, file_limit)));
        }
        if(name.length > KFS.name_size)
        {
            throw(new Exception(format("Unable to add file with name [%s]: Length is more than [%d]\n", name, KFS.name_size)));
        }
        foreach(i; 0..file_limit)
        {
            if(nameblocks[i].name == "")
            {
                debug(Directory) stderr.writef("add_entry: Allocating nameblock[%d]\n", i);
                nameblocks[i] = KFSEntry(name, block);
                debug(Directory) stderr.writef("add_entry: Added block: [%d/%d] [%s]\n", i, file_limit, nameblocks[i]);
                break;
            }
        }
    }

    void del_entry(string name)
    {
        debug(Directory) stderr.writef("del_entry: [%s]\n", name);
        if(name.length > KFS.name_size)
            throw(new Exception(format("Unable to del file with name [%s]: Length is more than [%d]\n", name, KFS.name_size)));
        foreach(i; 0..nameblocks.length)
        {
            if(nameblocks[i].name == name)
            {
                nameblocks[i].deallocate();
                break;
            }
        }
    }

    //DirEntry[] entries()
    DirIterator entries()
    {
        //DirEntry[] retval;
        DirIterator retval;
        foreach(i; 0..nameblocks.length)
        {
            debug(Directory) stderr.writef("entries: Checking [%s][%d]\n", nameblocks[i].name, nameblocks[i].block);
            if(nameblocks[i].name.length)
            {
                debug(Directory) stderr.writef("entries: Adding [%s] to list of entries\n", nameblocks[i].name);
                retval ~= DirEntry(nameblocks[i], cwd.path);
            }
        }
        debug(Directory) stderr.writef("entries:returning %s\n", retval);
        return retval;
    }

    DirEntry entry_by_name(string name)
    {
        DirEntry retval;
        foreach(i; 0..nameblocks.length)
        {
            if(nameblocks[i].name == name)
            {
                retval = DirEntry(nameblocks[i], cwd.path);
                break;
            }
        }
        return retval;
    }

    @property
    {
        size_t file_limit() { return KFS.block_size / KFSEntry.sizeof; }
        size_t unused_blocks() { return KFS.block_size - (KFS.block_size / file_limit * file_limit); }
        size_t used_blocks() 
        { 
            size_t retval;
            foreach(i; 0..nameblocks.length)
            {
                if(nameblocks[i].name.length)
                {
                    retval++;
                }
            }
            return retval; 
        }
    }

    unittest
    {
        KFSDirectory cwd_test = KFSDirectory();
        //DirEntry[] entries;
        DirIterator entries;
        cwd_test.add_entry("entry1", 0);
        entries = cwd_test.entries();
        assert(entries.length == 1 && cwd_test.used_blocks == 1);
        cwd_test.add_entry("entry2", 0);
        entries = cwd_test.entries();
        assert(entries.length == 2 && cwd_test.used_blocks == 2);
        cwd_test.add_entry("entry3", 0);
        entries = cwd_test.entries();
        assert(entries.length == 3 && cwd_test.used_blocks == 3);
        cwd_test.del_entry("entry3");
        entries = cwd_test.entries();
        assert(entries.length == 2 && cwd_test.used_blocks == 2);
        try
        {
            cwd_test.add_entry("123456789012345678901234567890", 0);
            assert(false);
        }
        catch
        {
            entries = cwd_test.entries();
            assert(entries.length == 2 && cwd_test.used_blocks == 2);
        }
    }
}

//class FileCompat
//{
//private:
//public:
//    //T[] rawRead(T)(T[]);
//    //void rawWrite(T)(T[]);
//    //string readln();
//    //void write(T)(T t);
//    //void close();
//    //void seek(size_t);
//    this() {}
//    this(File) {}
//    this(KFSFile) {}
//    T[] rawRead(T)(T[] bytes) 
//    { 
//        return bytes;
//    }
//    void rawWrite(T)(T[] bytes) 
//    {
//        stderr.writef("FileCompat.rawWrite\n");
//    }
//    string readln() { return ""; }
//    void write(T)(T t) {}
//    void close() {}
//    void seek(size_t pos) {}
//}

//class STDFileCompat : FileCompat
class FileCompat
{
private:
    bool is_File;
    std.stdio.File file;
    File kfsfile;
public:
    this()
    {
    }
    this(std.stdio.File f)
    {
        debug(debugFileCompat) stderr.writef("FileCompat.this(std.stdio.File):\n");
        file = f;
        is_File = true;
    }
    this(File f)
    {
        debug(debugFileCompat) stderr.writef("FileCompat.this(KFS.File):\n");
        kfsfile = f;
        is_File = false;
    }
    ~this()
    {
        close();
    }
    void opAssign(std.stdio.File f)
    {
        if(kfsfile.isOpen)
            kfsfile.close();
        file = f;
    }
    void opAssign(File f)
    {
        if(file.isOpen)
            file.close();
        kfsfile = f;
    }
    T[] rawRead(T)(T[] bytes)
    {
        if(is_File)
            return file.rawRead(bytes);
        else
            return kfsfile.rawRead(bytes);
    }
    void rawWrite(T)(T[] bytes)
    {
        if(is_File)
            return file.rawWrite(bytes);
        else
            return kfsfile.rawWrite(bytes);
    }
    string readln()
    {
        if(is_File)
            return file.readln();
        else
            return kfsfile.readln();
    }
    void write(T)(T t)
    {
        if(is_File)
        {
            enforce(file.isOpen && !file.error);
            return file.write(t);
        }
        else
            return kfsfile.write(t);
    }
    void writef(T...)(T t)
    {
        if(is_File)
        {
            return file.writef(t);
        }
        else
            throw(new Exception("KFS File does not support writef\n"));
    }
    void close()
    out { enforce(std.stdio.stdin.isOpen && std.stdio.stdout.isOpen && std.stdio.stderr.isOpen); }
    body
    {
        if(is_File)
        {
            if(file != std.stdio.stdin && file != std.stdio.stdout && file != std.stdio.stderr)
            {
                return file.close();
            }
        }
        else
            return kfsfile.close();
    }
    void seek(size_t pos)
    {
        if(is_File)
            return file.seek(pos);
        else
            return kfsfile.seek(pos);
    }
    @property bool isOpen()
    {
        if(is_File)
            return file.isOpen;
        else
            return kfsfile.isOpen;
    }
    @property bool eof()
    {
        if(is_File)
            return file.eof;
        else
            return kfsfile.eof;
    }
}

unittest
{
    // Write out a new file and test access
    DISK = std.stdio.File.tmpfile();
    // test mkfs
    mkfs(100 * KFS.block_size);
    // Test directory functions
    assert(isDir("/"));
    chdir("/");
    mkdir("/home");
    assert(exists("/home"));
    assert(isDir("/home"));
    mkdir("/home/kai/");
    assert(exists("/home/kai"));
    assert(isDir("/home/kai"));
    mkdir("/home/kai/school");
    assert(exists("/home/kai/school"));
    assert(isDir("/home/kai/school"));
    mkdir("/home/kai/school/VM");
    assert(exists("/home/kai/school/VM"));
    assert(isDir("/home/kai/school/VM"));

    // Test touch
    touch("/test.txt");
    assert(exists("/test.txt"));
    assert(isFile("/test.txt"));
    touch("/home/test.txt");
    assert(exists("/home/test.txt"));
    assert(isFile("/home/test.txt"));
    touch("/home/kai/test1.txt");
    assert(exists("/home/kai/test1.txt"));
    assert(isFile("/home/kai/test1.txt"));
    touch("/home/kai/test.txt");
    assert(exists("/home/kai/test.txt"));
    assert(isFile("/home/kai/test.txt"));

    // Test Writing and file size
    size_t file_size = 0;
    FileCompat test_file1 = new FileCompat(File("/home/kai/test.txt", "w+b"));
    ByteCode[] data1;
    foreach(i; 0..500)
    {
        ubyte b = cast(ubyte)(i);
        data1 = [cast(ubyte)(0 + b), cast(ubyte)(1 + b), cast(ubyte)(2 + b), cast(ubyte)(3 + b), cast(ubyte)(4 + b)];
        test_file1.rawWrite(data1[0..$]);
        file_size += 5;
    }
    test_file1.close;
    assert(getSize("/home/kai/test.txt") == file_size);

    // Test reading
    test_file1 = File("/home/kai/test.txt", "r");
    ByteCode[] data2;
    data2.length = data1.length;
    FileCompat test_file2 = new FileCompat(File("/home/kai/test.txt", "r"));
    test_file1.seek(0);
    test_file2.seek(0);
    foreach(i; 0..500)
    {
        ubyte b = cast(ubyte)(i);
        data1 = [cast(ubyte)(0 + b), cast(ubyte)(1 + b), cast(ubyte)(2 + b), cast(ubyte)(3 + b), cast(ubyte)(4 + b)];
        test_file1.rawRead(data2[0..$]);
        //stderr.writef("[%d] %s %s\n", i, data1, data2);
        assert(data2[0] == cast(ubyte)(0 + b));
        assert(data2[1] == cast(ubyte)(1 + b));
        assert(data2[2] == cast(ubyte)(2 + b));
        assert(data2[3] == cast(ubyte)(3 + b));
        assert(data2[4] == cast(ubyte)(4 + b));
        test_file2.rawRead(data2[0..$]);
        //stderr.writef("[%d] %s %s [%d]\n", i, data1, data2, test_file1.entry.size);
        assert(data2[0] == cast(ubyte)(0 + b));
        assert(data2[1] == cast(ubyte)(1 + b));
        assert(data2[2] == cast(ubyte)(2 + b));
        assert(data2[3] == cast(ubyte)(3 + b));
        assert(data2[4] == cast(ubyte)(4 + b));
    }
    test_file1.close;
    test_file2.close;

    // Test DirIterator and dirEntries (for ls)
    DirIterator entries = dirEntries("/home/kai", SpanMode.shallow);
    foreach (DirEntry e; entries) 
    {
        if(e.isDir())
            std.stdio.writef("%-20s/%10.2fK\n", e.name, cast(float)e.size / 1024);
        else
            std.stdio.writef("%-20s%10.2fK\n", e.name, cast(float)e.size / 1024);
    }

    chdir("/home/kai");
    DirEntry[] entries2 = dirEntries(".", SpanMode.shallow);
    foreach (DirEntry e; entries2) 
        stderr.writef("lstest: %s\n", e.name);
    assert(entries2[0].name == "school");
    assert(entries2[1].name == "test1.txt");
    assert(entries2[2].name == "test.txt");
    chdir("/");

    // Test remove
    remove("/home/kai/test1.txt");
    assert(!exists("/home/kai/test1.txt"));
    try remove("/home/kai/");
    catch {}
    assert(exists("/home/kai/"));
    assert(isDir("/home/kai/"));
    remove("/home/kai/test.txt");
    assert(!exists("/home/kai/test.txt"));

    // Test rename
    chdir("/");
    mkdir("/rename");
    touch("/rename/file1.txt");
    touch("/rename/file2.txt");
    rename("/rename/file1.txt", "/rename/file3.txt");
    assert(!exists("/rename/file1.txt"));
    assert(isFile("/rename/file3.txt"));
    mkdir("/rename2");
    rename("/rename/file2.txt", "/rename2/file2.txt");
    rename("/rename/file3.txt", "/rename2/file3.txt");
    assert(!exists("/rename/file2.txt"));
    assert(isFile("/rename2/file2.txt"));
    assert(!exists("/rename/file3.txt"));
    assert(isFile("/rename2/file3.txt"));
    rename("/rename2/file2.txt", "/file2.txt");
    assert(!exists("/rename2/file2.txt"));
    assert(isFile("/file2.txt"));
    remove("/rename");
    rename("/rename2", "/rename");
    assert(!exists("/rename2"));
    assert(isDir("/rename"));

    // Test copy
    chdir("/");
    mkdir("/copy");
    // write a file
    test_file1 = File("/copy/copy1.txt", "w");
    test_file1.write("Hello World!\n");
    test_file1.close;
    assert(getSize("/copy/copy1.txt") == 13);
    // Copy the file
    copy("/copy/copy1.txt", "/copy/copy2.txt");
    assert(getSize("/copy/copy1.txt") == 13);
    assert(getSize("/copy/copy2.txt") == 13);
    // Update the first file
    test_file1 = File("/copy/copy1.txt", "a");
    test_file1.write("Again!\n");
    test_file1.close;
    assert(getSize("/copy/copy1.txt") == 20);
    assert(getSize("/copy/copy2.txt") == 13);

    // Test link
    chdir("/");
    mkdir("/link");
    // write a file
    test_file1 = File("/link/link1.txt", "w");
    test_file1.write("Hello World!\n");
    test_file1.close;
    assert(getSize("/link/link1.txt") == 13);
    // Copy the file
    link("/link/link1.txt", "/link/link2.txt");
    assert(getSize("/link/link1.txt") == 13);
    assert(getSize("/link/link2.txt") == 13);
    // Update the first file
    test_file1 = File("/link/link2.txt", "a");
    test_file1.write("Again!\n");
    test_file1.close;
    assert(getSize("/link/link1.txt") == 20);
    assert(getSize("/link/link2.txt") == 20);
    // Update the second file
    test_file1 = File("/link/link2.txt", "a");
    test_file1.write("Twice!\n");
    test_file1.close;
    assert(getSize("/link/link1.txt") == 27);
    assert(getSize("/link/link2.txt") == 27);

    DISK.close();
}

