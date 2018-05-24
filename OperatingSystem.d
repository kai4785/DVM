// Operating System Module

module OperatingSystem;

version = STDIO;
//version = KaiFS;
//version = TINY;
version = HUGE;
//version = VIRTUALMEMORY;

//debug = readhex;
version(STDIO)
{
    import std.stdio;
    import std.file;
    import FileSystem : FileCompat, CWD, cwd, BLOCK, DISK, KFS, from_block, touch;
    alias std.file.remove remove;
    alias std.file.copy copy;
    private import std.process;
    void link(string source, string dest)
    {
        std.process.system(format("ln %s %s", source, dest));
    }
}
else version(KaiFS)
{
    //import std.stdio : writef, writefln, writeln, stdin, stdout, stderr;
    static import std.file;
    static import std.stdio;
    void writef(T...)(T args)
    {
        stdout.writef(args);
    }
    import FileSystem;
    alias FileSystem.remove remove;
    alias FileSystem.copy copy;
}
FileCompat stdin; 
FileCompat stdout;
FileCompat stderr;

import std.string;
alias std.string.split split; // disambiguate from std.regexp.split
import std.regexp;
import std.conv;
import std.getopt;
import std.algorithm;
import std.array;
import std.datetime;
import std.process : environment;
import std.exception;

import VirtualMachine;
import Utilities;

//debug = instruction;

enum PAGE_SIZE = 512;
version(TINY)
    enum max_procs = 8, proc_size_in_memory = 1024 * 1;
else version(HUGE)
    enum max_procs = 8, proc_size_in_memory = 1024 * 500;
else
    enum max_procs = 256, proc_size_in_memory = 1024 * 50;
string[6] states = ["new", "ready", "waiting", "running", "terminated", "error"];

void ByteCode_from_Hex(string infile, ref AssemblyHeader header, ref ByteCode[] program)
out { assert(header.data[0] == program.length); }
body
{
    ulong prog_size = to!(int)(getSize(infile));
    if(prog_size > 1024 * 1024) {
        string msg = "Program is way too big: [" ~ to!(string)(prog_size) ~ "] bytes.\n";
        msg ~= "Try keeping it under [" ~ to!(string)(1024 * 1024) ~ "] bytes.";
        throw(new Exception(msg));
    } else {
        program.length = to!(uint)(prog_size) - header.sizeof;
    }
    FileCompat hex_file_in = new FileCompat(File(infile, "r"));
    hex_file_in.rawRead(header.bytes[0..$]);
    hex_file_in.rawRead(program[0..$]);
    hex_file_in.close();
    enforce(header.data[0] == program.length, "Invalid header data in program file.");
}

class Process 
{
private:
    string _name;
    StopWatch timer;
    double last_time;
    double this_time;
    size_t _state;
    FileCompat[] fh;
    this() {}
public:
    Register[Valid_Registers.length] R;
    size_t size;
    size_t size_in_memory;
    size_t pid;
    Thread[] active_threads;
    Thread[] available_threads;
    int priority;
    double[string] metrics;
    string buffer;
    this(string name, FileCompat[] STDIO)
    //in  { assert(STDIO.length >= 3); }
    out { assert(fh.length >= 3);    }
    body
    {
        if(!STDIO.length)
            fh = [
            stdin, 
            stdout, 
            stderr
            ];
        timer.start();
        _name = name;
        _state = 0;
        last_time = 0;
        // Initialize timers so we can skip the check for the existing timer in the state property
        foreach(state; states)
            metrics[state] = 0;
        fh = STDIO;
    }
    
    @property 
    {
        string name() {return _name; }
        size_t state() {return _state;}
        void state(size_t new_state) 
        {
            // Every time we change the state, we want to start and stop the timer.
            this_time = timer.peek().usecs;
            metrics[states[state]] = metrics[states[state]] + this_time - last_time;
            last_time = this_time;
            _state = new_state;
        }
        string state_str() {return states[state];}
        FileCompat stdin() {return fh[0]; }
        FileCompat stdout() {return fh[1]; }
        FileCompat stderr() {return fh[2]; }
    }

}

struct ProcessList
{
private:
    Process[size_t] procs;
    size_t next_pid = 0;
public:
    @property size_t length() { return procs.length; }

    void add(Process p)
    {
        if(procs.length == max_procs)
            throw(new Exception("Filled up process list"));
        while(!((next_pid in procs) is null))
        {
            //stderr.writef("%d not available\n", next_pid);
            next_pid = (next_pid + 1) % max_procs;
        }
        p.pid = next_pid;
        procs[next_pid] = p;
    }

    Process opIndex(size_t i)
    {
        return procs.get(i, null);
    }

    Process get(size_t pid, Process p = null)
    {
        return procs.get(pid, p);
    }

    void remove(size_t i)
    {
        procs.remove(i);
    }

    void print()
    {
        writef("%3s %10s %8s %15s %8s %8s\n", "PID", "Name", "Priority", "State", "Start", "End");
        foreach(i, proc; procs) {
            writef("%3d %10s %8d %15s %8d %8d\n    %s\n", i, proc.name, proc.priority, proc.state_str, proc.R[13], proc.R[13] + proc.size_in_memory, proc.metrics);
        }
    }

    Process[] all_active()
    {
        Process[] retval;
        foreach(pid; procs.keys.sort)
            if(procs[pid].state == 0 || procs[pid].state == 1)
                retval ~= procs[pid];
        return retval;
    }
}

class Scheduler
{
private:
    Process[] running_queue;
    VirtualMachine vm;
public:
    this() {}

    this(VirtualMachine vm)
    {
        this.vm = vm;
    }

    void add_procs(Process[] new_procs)
    {
        running_queue ~= new_procs;
        foreach(proc; running_queue)
        {
            debug(sched) stderr.writef("adding pid[%d] with R[] [%s]\n", proc.pid, proc.R);
            proc.state = 1;
        }
    }

    void add_proc(Process proc)
    {
        debug(sched) stderr.writef("adding pid[%d] with R[] [%s]\n", proc.pid, proc.R);
        proc.state = 1;
        running_queue ~= proc;
    }

    void clear()
    {
        running_queue.clear;
    }
    
    void next() {}
    
    @property Process current()
    {
        return null;
    }

    void run()
    {
        if(!running_queue.empty)
        {
            vm.set_registers(running_queue[0].R);
            vm.set_vm_threads(running_queue[0].active_threads, running_queue[0].available_threads);
            //stderr.writef("running pid[%d] with R[] [%s]\n", running_queue[0].pid, running_queue[0].R);
            //vm.dump_registers(format("Running pid [%d]", running_queue[0].pid));
            running_queue[0].state = 3;
            vm.running = true;
            vm.run();
        }
    }
}

class RoundRobin: Scheduler
{
private:
public:
    this() {}

    this(VirtualMachine vm)
    {
        super(vm);
    }

    override void next()
    in
    {
        assert(!running_queue.empty);
    }
    body
    {
        if(running_queue[0].state > 3)
        {
            running_queue.popFront;
        }
        else
        {
            if(running_queue.length > 1) running_queue = running_queue[1..$] ~ running_queue[0];
        }

        if(!running_queue.empty)
        {
            vm.running = true;
        }
    }

    override @property Process current()
    {
        if(running_queue.empty)
            return null;
        else
            return running_queue[0];
    }
}

class FirstComeFirstServe: Scheduler
{
private:
public:
    this() {}
    this(VirtualMachine vm)
    {
        super(vm);
    }

    override void next()
    in
    {
        assert(!running_queue.empty);
    }
    body
    {
        if(running_queue[0].state > 3)
            running_queue.popFront;

        if(!running_queue.empty)
        {
            vm.running = true;
        }
    }

    override @property Process current()
    {
        if(!running_queue.empty)
            return running_queue[0];
        else
            return null;
    }
}

class Priority: Scheduler
{
private:
    Process[][int] running_queue;
    int cur_priority;

    void next_priority()
    {
        cur_priority = int.max;
        foreach(priority, queue; running_queue)
        {
            if(queue.empty)
                running_queue.remove(priority);
            else
                cur_priority = min(cur_priority, priority);
        }
    }
public:
    this() {}
    this(VirtualMachine vm)
    {
        super(vm);
    }


    override void add_procs(Process[] new_procs)
    {
        foreach(proc; new_procs)
        {
            proc.state = 1;
            running_queue[proc.priority] ~= proc;
        }
        next_priority();
        //stderr.writef("add_procs: cur_priority[%d]\n", cur_priority);
    }

    override void add_proc(Process new_proc)
    {
        new_proc.state = 1;
        running_queue[new_proc.priority] ~= new_proc;
        next_priority();
    }

    override void next()
    in
    {
        assert(!running_queue[cur_priority].empty);
    }
    body
    {
        //stderr.writef("next: cur_priority[%d]\n", cur_priority);
        if(running_queue[cur_priority][0].state > 3)
        {
            running_queue[cur_priority].popFront;
            //stderr.writef("Just finished a process in [%d]. Updating cur_priority\n", cur_priority);
            next_priority();
            //stderr.writef("cur_priority is now [%d]\n", cur_priority);
        }
        else
        {
            if(running_queue[cur_priority].length > 1) running_queue[cur_priority] = running_queue[cur_priority][1..$] ~ running_queue[cur_priority][0];
        }

        if(!(running_queue.get(cur_priority, null) is null || running_queue[cur_priority].empty))
        {
            vm.running = true;
        }
    }

    override @property Process current()
    {
        //stderr.writef("current: cur_priority[%d]\n", cur_priority);
        if(running_queue.get(cur_priority, null) is null || running_queue[cur_priority].empty)
            return null;
        else
            return running_queue[cur_priority][0];
    }

    override void run()
    {
        if(running_queue.get(cur_priority, null) !is null && !running_queue[cur_priority].empty)
        {
            vm.set_registers(running_queue[cur_priority][0].R);
            vm.set_vm_threads(running_queue[cur_priority][0].active_threads, running_queue[cur_priority][0].available_threads);
            running_queue[cur_priority][0].state = 3;
            vm.run();
        }
    }
}

struct VirtualMemoryManager
{
    enum offset_bits = 9;
    enum page_bits = (size_t.sizeof * 8) - offset_bits;
    sizediff_t[size_t] pages;
    size_t[size_t] page_used;
    ByteCode[PAGE_SIZE][size_t] swap;
    ByteCode[PAGE_SIZE] delegate(size_t pos) page_out;
    void delegate(size_t pos, ByteCode[PAGE_SIZE]) page_in;
    size_t[string] stats;

    @property
    {
        void size(size_t new_length)
        {
            foreach(num; 0..new_length>>9)
            {
                pages[num] = to!(int)(num * PAGE_SIZE);
                page_used[num] = 0;
            }
            stats["MH"] = 0;
        }
        void virt_size(size_t nvl)
        {
            stderr.writef("Starting at %d, going to %d\n", pages.length, nvl>>9);
            foreach(num; pages.length..nvl>>9)
            {
                pages[num] = -1 - num;
                page_used[num] = 0;
            }
            stats["DA"] = 0;
        }
    }
    size_t least_used_page()
    {
        size_t least_used = size_t.max;
        foreach(key; pages.keys.sort)
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
        foreach(key; pages.keys.sort)
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
            stats["DA"] += 1;
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
            swap[to!(size_t)(pages[unused_swap] * -1)] = page_out(pages[least_used]);
            size_t tmp2 = pages[least_used];
            pages[least_used] = pages[unused_swap];
            // Swap in
            if(need != unused_swap)
            {
                debug(paging)
                    stderr.writef("tmp2[%d] ", tmp2);
                if((to!(size_t)(pages[need] * -1) in swap) !is null)
                {
                    page_in(tmp2, swap[to!(size_t)(pages[need] * -1)]);
                    swap.remove(to!(size_t)(pages[need] * -1));
                }
                pages[unused_swap] = pages[need];
            }
            pages[need] = tmp2;
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
        else
        {
            stats["MH"] += 1;
        }
        return pages[index >> offset_bits] + (index << page_bits >> page_bits);
    }
}


class OperatingSystem 
{
private:
    VirtualMachine vm;
    version(VIRTUALMEMORY)
    {
        VirtualMemoryManager vmm;
    }
    Valid_Registers valid_registers;
    bool alldone;
    void delegate(string)[string] commands;
    void delegate()[string] helps;
    Scheduler[string] schedulers;
    Scheduler cur_scheduler;
    ProcessList process_list;
    Process shell_proc;
    //string buffer;
    Register PC; // Program Counter Register
    Register SL; // Stack Limit Register
    Register SB; // Stack Base Register
    Register SP; // Stack Pointer
    Register FP; // Frame Pointer
    Register OF; // Offset
    Register TC; // Hardware Thread Count
    bool echo = false;

    PerfMetrics metrics;
    class PerfMetrics
    {
    private:
        double[string][string] metrics;
        double[string] sums;
    public:
        this() { }
        size_t switches;
        void harvest(Process proc)
        {
            // Update the current timer
            proc.state = proc.state; 
            foreach(state; states)
            {
                metrics[proc.name][state] += proc.metrics[state];
            }
            metrics[proc.name]["pid"] = proc.pid;
        }
        void print()
        {
            writef("%-10s", "Name");
            foreach(state; states)
            {
                sums[state] = 0;
                writef("%11s", state);
            }
            writef("\n");
            foreach(name; metrics.keys.sort)
            {
                writef("%-10s", name);
                foreach(state; states)
                {
                    sums[state] += metrics[name].get(state,0);
                    writef("%11.2f", metrics[name].get(state,0));
                }
                writef("\n");
            }
            writef("\n%-10s", "Averages");
            foreach(state; states)
            {
                writef("%11.2f", sums.get(state, 0) / metrics.length);
            }
            writef("\n");
            writef("%-10s%11.2f\n", "%CPU", sums["running"] / shell_proc.metrics["waiting"] * 100);
            writef("%-10s%11.2f\n", "%IO", sums["waiting"] / shell_proc.metrics["waiting"] * 100);
            writef("%-10s%11d\n", "Switches", switches);
        }
    }

    void unknown_command(string args) {
        stderr.writef("Unknown command: %s\n", args);
        do_help("");
    }

    void do_load(string args) {
        //stderr.writef("do_load: system_memory before [%s]\n", system_memory);
        FileCompat[] STDIO = [stdin, stdout, stderr];

        uint vm_threads = 1;
        if(RegExp m = std.regexp.search(args, r"\s*--vm_threads\s+(\d+)\s+")) {
            args = m.pre ~ m.post;
            vm_threads = to!(uint)(m.match(1));
        }

        if(RegExp m = std.regexp.search(args, r"\s*<\s*(\S+)\s*$")) {
            //stderr.writef("Redirecting STDIN to read from %s\n", m.match(1));
            args = m.pre ~ m.post;
            STDIO[0] = new FileCompat(File(m.match(1), "r"));
        }
        if(RegExp m = std.regexp.search(args, r"\s*>>\s*(\S+)\s*$")) {
            //stderr.writef("Redirecting STDOUT to append to %s\n", m.match(1));
            args = m.pre ~ m.post;
            STDIO[1] = new FileCompat(File(m.match(1), "a"));
        }
        if(RegExp m = std.regexp.search(args, r"\s*>\s*(\S+)\s*$")) {
            //stderr.writef("Redirecting STDOUT to write to %s\n", m.match(1));
            args = m.pre ~ m.post;
            STDIO[1] = new FileCompat(File(m.match(1), "w"));
        }

        if(exists(args)) 
        {
            if(isfile(args)) 
            {
                // Extract header information for OS class
                Process cur_proc = new Process(args, STDIO);
                ByteCode[] program;
                AssemblyHeader header;
                ByteCode_from_Hex(args, header, program);
                cur_proc.R[TC] = vm_threads;
                cur_proc.size = header.data[0];
                cur_proc.size_in_memory = proc_size_in_memory;
                //cur_proc.R[SP] = cur_proc.size;
                cur_proc.R[PC] = header.data[2];
                //stderr.writef("SB[%d] = cur_proc.size_in_memory[%d] - cur_proc.size[%d]\n", cur_proc.size_in_memory - cur_proc.size, cur_proc.size_in_memory, cur_proc.size);
                enforce(cur_proc.size_in_memory > cur_proc.size, "Process doesn't fit inside the static size of memory (proc_size_in_memory)");
                cur_proc.R[SB] = cur_proc.size_in_memory - cur_proc.size;
                enforce(cur_proc.R[SB] > cur_proc.size, "Process plus stack does not fit inside the static size of memory (proc_size_in_memory)");

                MemoryManagement!(ulong[32]) system_memory = read_memory!(MemoryManagement!(ulong[32]))();
                cur_proc.R[OF] = system_memory.allocate(cur_proc.size_in_memory);

                MemoryManagement!(ulong[4]) proc_memory;
                proc_memory.used = proc_memory.max_used;
                proc_memory.block_size = (cur_proc.R[SB] - cur_proc.size) / proc_memory.max_used;
                proc_memory.allocate(proc_memory.sizeof);
                //stderr.writef("Setting block_size = %d, SL=%d + %d = %d\n", proc_memory.block_size, cur_proc.size, proc_memory.SL_pos, cur_proc.size + proc_memory.SL_pos);
                cur_proc.R[SL] = cur_proc.size + proc_memory.SL_pos;

                //stderr.writef("do_load: writing program at position [%d - %d]\n", cur_proc.R[OF], cur_proc.R[OF] + cur_proc.R[SL] - 1);
                vm.load(program, cur_proc.R[OF]);                         // Load the hex file into memory
                vm.set_registers(cur_proc.R);
                vm.set_vm_threads(cur_proc.active_threads, cur_proc.available_threads);
                vm.validate_registers();
                vm.fetch_registers(cur_proc.R);
                vm.fetch_vm_threads(cur_proc.active_threads, cur_proc.available_threads);
                process_list.add(cur_proc);
                // Once we're sure that everything is safe, we'll allocate memory
                write_memory!(MemoryManagement!(ulong[4]))(proc_memory, cur_proc.R[OF] + cur_proc.size);
                write_memory!(MemoryManagement!(ulong[32]))(system_memory);
            } 
            else if(isdir(args)) 
            {
                stderr.writef("Target is a directory: %s\n", args);
            } 
            else 
            {
                stderr.writef("Target is not a file or directory: %s\n", args);
            }
        } 
        else 
        {
            throw(new Exception(format("No such file or directory: %s", args)));
        }

        //stderr.writef("do_load: system_memory after  [%s]\n", system_memory);
    }

    void do_run(string args) {
        uint pid = to!(uint)(args);
        Process cur_proc = process_list.get(pid, null);
        if(cur_proc !is null)
        {
            if(process_list[pid].state < 4)
            {
                cur_scheduler.add_proc(cur_proc);
                shell_proc.state = 2;
                cur_scheduler.run();
                shell_proc.state = 3;
                cur_scheduler.clear();
            } else {
                stderr.writef("Unable to run pid [%d] in state [%s]\n", pid, process_list[pid].state_str);
            }
        } else {
            stderr.writef("No pid: %d\n", pid);
        }
    }

    void do_runall(string args) {
        cur_scheduler.add_procs(process_list.all_active());
        //Process cur_proc = cur_scheduler.current;
        shell_proc.state = 2;
        cur_scheduler.run();
        shell_proc.state = 3;
        cur_scheduler.clear();
    }

    void do_exit(string args) {
        alldone = true;
    }

    void do_help(string args) {
        if(!args.length) {
            writef("Possible commands are [ %s ]\n", commands.keys().join(" | "));
        } else {
            void delegate() hlp = helps.get(args, null);
            if(hlp is null) {
                unknown_command(args);
            } else {
                hlp();
            }
        }
    }

    void do_mkdir(string arg_str)
    {
        mkdir(arg_str);
    }

    void do_cat(string arg_str)
    {
        FileCompat outfile = new FileCompat(File(arg_str, "r"));
        while(outfile.isOpen && !outfile.eof)
        {
            writef(outfile.readln);
        }
    }

    void do_df(string arg_str)
    {
        BLOCK bytes;
        DISK.seek(KFS.bitmap_block * KFS.block_size);
        DISK.rawRead(bytes);
        DiskManagement!(ulong[32]) bitmap = from_block!(DiskManagement!(ulong[32]))(bytes);
        writef("%dK / %dK (%5.2f%%)\n", bitmap.count(true) * KFS.block_size / 1024, bitmap.max_used * KFS.block_size / 1024, cast(float)bitmap.count(true) * 100 / bitmap.max_used);
    }

    void do_du(string arg_str)
    {
        string[] args = arg_str.split();
        if(!args.length)
            args = ["."];
        foreach(arg; args)
        {
            writef("%10.2fK, %s\n", cast(float)do_du_work(arg) / 1024, arg);
        }
        // foreach entry
        //   if isfile
        //     total += file.size
        //   if isdir
        //     recurse, or add to list of directories
    }

    size_t do_du_work(string arg)
    {
        size_t retval = 0;
        if(isdir(arg)) 
        {
            DirIterator entries = dirEntries(arg, SpanMode.shallow);
            foreach (DirEntry e; entries) 
            {
                if(e.isdir())
                    retval += do_du_work(e.name);
                else
                    retval += e.size;
            }
        } 
        else if (isfile(arg)) 
        {
            retval += getSize(arg);
        }
        return retval;
    }

    void do_ln(string arg_str)
    {
        // TODO: Implement ln
        string[] args = arg_str.split();
        if(args.length != 2)
            throw(new Exception(format("Not exactly 2 arguments to ln: %s", arg_str)));
        link(args[0], args[1]);
    }
    void do_rm(string arg_str)
    {
        // TODO: Figure out how to make this disambiguated
        remove(arg_str);
    }
    void do_mv(string arg_str)
    {
        string[] args = arg_str.split();
        if(args.length != 2)
            throw(new Exception(format("Not exactly 2 arguments to mv: %s", arg_str)));
        rename(args[0], args[1]);
    }
    void do_cp(string arg_str)
    {
        string[] args = arg_str.split();
        if(args.length != 2)
            throw(new Exception(format("Not exactly 2 arguments to mv: %s", arg_str)));
            copy(args[0], args[1]);
    }
    void do_pwd(string arg_str)
    {
        writef("%s\n", getcwd());
    }
    void do_tail(string arg_str)
    {
        string[] lines;
        size_t count = 10;
        string filename;
        string[] args = arg_str.split();
        if(args.length == 1)
        {
            filename = args[0];
        }
        if(args.length == 3)
        {
            if(args[0] == "-n")
            {
                count = to!(size_t)(args[1]);
                filename = args[2];
            }
            else
            {
                throw new Exception(format("Unknown options for tail: '%s'", arg_str));
            }
        }
        FileCompat outfile = new FileCompat(File(filename, "r"));
        while(outfile.isOpen && !outfile.eof)
        {
            if(lines.length == count)
                lines.popFront();
            lines ~= outfile.readln();
        }
        foreach(l; lines)
            writef(l);
    }
    void do_head(string arg_str)
    {
        size_t count = 10;
        string filename;
        string[] args = arg_str.split();
        if(args.length == 1)
        {
            filename = args[0];
        }
        if(args.length == 3)
        {
            if(args[0] == "-n")
            {
                count = to!(size_t)(args[1]);
                filename = args[2];
            }
            else
            {
                throw new Exception(format("Unknown options for tail: '%s'", arg_str));
            }
        }
        FileCompat outfile = new FileCompat(File(filename, "r"));
        while(count > 0 && outfile.isOpen && !outfile.eof)
        {
            writef(outfile.readln());
            count--;
        }
    }
    void do_touch(string arg_str)
    {
        touch(arg_str);
    }

    void do_ls(string arg_str) {
        string[] args = arg_str.split();
        if(args.empty)
            args = ["."];
        foreach(arg; args) {
            if(isdir(arg)) 
            {
                DirIterator entries = dirEntries(arg, SpanMode.shallow);
                writef("%-20s%20s %40s%40s\n", "Name", "Size", "CreateTime", "LastWriteTime");
                foreach (DirEntry e; entries) 
                {
                    if(e.isdir())
                        version(STDIO)
                            writef("%-20s%20.2fK%40d%40d\n", format("%s/",e.name), cast(float)e.size / 1024, e.lastWriteTime, e.lastWriteTime);
                        version(KFS)
                            writef("%-20s%20.2fK%40s%40s\n", format("%s/", e.name), cast(float)e.size / 1024, e.createTime_str, e.lastWriteTime_str);
                    else
                        version(STDIO)
                            writef("%-20s%20.2fK%40d%40d\n", e.name, cast(float)e.size / 1024, e.lastWriteTime, e.lastWriteTime);
                        version(KFS)
                            writef("%-20s%20.2fK%40s%40s\n", e.name, cast(float)e.size / 1024, e.createTime_str, e.lastWriteTime_str);
                }
            } 
            else if (isfile(arg)) 
            {
                writef("%s\n", arg);
            }
        }
    }

    void do_cd(string args) {
        if(!args.length)
            help_real_cd();
        chdir(args);
    }

    void do_ps(string args) {
        process_list.print();
    }

    void do_mem(string args) {
        MemoryManagement!(ulong[32]) memory;
        bool error = false;
        if(!args.length)
        {
            memory = read_memory!(MemoryManagement!(ulong[32]))();
        }
        else
        {
            if(RegExp m = std.regexp.search(args, r"^\s*(\d+)\s*$"))
            {
                uint pid = to!(uint)(m.match(0));
                if((process_list[pid]) is null)
                {
                    error = true;
                    stderr.writef("Pid [%s] is not running\n", pid);
                }
                else
                {
                    memory = read_memory!(MemoryManagement!(ulong[32]))(process_list[pid].R[OF] + process_list[pid].size);
                }
            }
            else
            {
                error = true;
                stderr.writef("Unknown pid [%s]\n", args);
            }
        }
        if(!error)
        {
            writef("%-15s: %d\n",    "Free Memory", memory.count(false) * memory.block_size);
            writef("%-15s: %d\n",    "Used Memory", memory.count(true) * memory.block_size);
            writef("%-15s: %d\n",    "Block Size", memory.block_size);
            writef("%-15s: %s\n",    "Memory Map", memory);
            version(VIRTUALMEMORY)
            {
                writef("%-15s: %d\n",    "Memory Hits", vmm.stats.get("MH", 0));
                writef("%-15s: %d\n",    "Swap Hits", vmm.stats.get("DA", 0));
                double MAT = 0;
                if(vmm.stats.get("MH", 0) > 0 || vmm.stats.get("DA", 0) > 0)
                    MAT = (vmm.stats.get("MH", 0) * 20000 + vmm.stats.get("MH", 0) * 200) / (vmm.stats.get("MH", 0) + vmm.stats.get("DA", 0));
                writef("%-15s: %5.2f μs\n", "Avg MAT", MAT);
            }
        }
    }

    void do_kill(string args) {
        uint pid = to!(uint)(args);
        if(!(process_list[pid] is null)) {
            MemoryManagement!(ulong[32]) system_memory = read_memory!(MemoryManagement!(ulong[32]))(0);
            system_memory.free(process_list.get(pid).size_in_memory, process_list.get(pid).R[OF]);
            write_memory!(MemoryManagement!(ulong[32]))(system_memory);
            process_list.remove(pid);
        } else {
            stderr.writef("No pid: %d\n", pid);
        }
    }

    void do_set(string args)
    {
        if(args == "echo 0")
        {
            echo = false;
        }
        else if (args == "echo 1")
        {
            echo = true;
            writef("set %s\n", args);
        }
    }

    void do_sched(string args)
    {
        Scheduler new_sched = schedulers.get(args, null);
        if(new_sched is null)
        {
            stderr.writef("Unknown scheduler [%s].\n", args);
        }
        else
        {
            stderr.writef("Switching to [%s] scheduler\n", args);
            cur_scheduler = schedulers[args];
        }
    }

    void do_priority(string args)
    {
        string[] args_split = args.split();
        if(args_split.length != 2)
        {
            stderr.writef("Need 2 arguments\n");
            return;
        }
        uint pid = to!(uint)(args_split[0]);
        Process cur_proc = process_list.get(pid, null);
        if(cur_proc is null)
            stderr.writef("Pid [%d] not found\n", pid);
        else
            cur_proc.priority = to!(int)(args_split[1]);
    }

    void do_metrics(string args)
    {
        //metrics.harvest(shell_proc);
        metrics.print();
    }

    void help_load() {
        writef("load [--vm_threads #] progname\n");
        writef("    Copies a program into VM memory.\n");
        writef("    vm_threads is only used when the opcodes 'RUN' are used.\n");
    }

    void help_run() {
        writef("run pid\n");
        writef("    Executes a loaded program.\n");
    }

    void help_exit() {
        writef("[exit | quit]\n");
        writef("    Exits the OS simulator shell.\n");
    }

    void help_help() {
        writef("help [command]\n");
        writef("    Displays help text\n");
    }

    void help_real_ls() {
        writef("!ls [folder | file]\n");
        writef("    Displays file and folder lists.\n");
    }

    void help_real_cd() {
        writef("!cd folder\n");
        writef("    Change CWD to folder.\n");
    }

    void help_ps() {
        writef("ps\n");
        writef("    Displays loaded process information.\n");
    }

    void help_kill() {
        writef("kill pid\n");
        writef("    Removes a loaded program from the process list.\n");
    }

    void help_sched()
    {
        writef("sched [scheduler]\n");
        writef("    Possible Schedulers are [ %s ]\n", schedulers.keys().join(" , "));
    }

    // Exit program
    void TRP_terminate(Instruction I) {
        //Process cur_proc = cur_scheduler.current;
        cur_scheduler.current.state = 4;
        //cur_scheduler.current.buffer.length = 0;
        MemoryManagement!(ulong[32]) system_memory = read_memory!(MemoryManagement!(ulong[32]))(0);
        //stderr.writef("Freeing [%d] system_memory blocks with block_size[%d]\n", cur_scheduler.current.size_in_memory, system_memory.block_size);
        system_memory.free(cur_scheduler.current.size_in_memory, cur_scheduler.current.R[OF]);
        write_memory!(MemoryManagement!(ulong[32]))(system_memory);
        vm.running = false;
    }

    // Write integer to STDOUT Stored in R0
    void TRP_write_int(Instruction I)  {
        cur_scheduler.current.state = 2;
        debug(instruction) stderr.writef("instruction: (%d) Write out int '%d'\n", vm.fetch_register(PC), vm.fetch_register(0));
        cur_scheduler.current.stdout.write(vm.fetch_register(0));            
        cur_scheduler.current.state = 3;
    }

    // Read  integer to STDIN  Stored in R0
    void TRP_read_int(Instruction I) { 
        cur_scheduler.current.state = 2;
        while(!cur_scheduler.current.buffer.length) {
          cur_scheduler.current.buffer = cur_scheduler.current.stdin.readln();
          if(RegExp m = std.regexp.search(cur_scheduler.current.buffer, r"^\s*(\S.*)")) {
            cur_scheduler.current.buffer = m.match(1);
          }
        }
        int i = 0;
        if (RegExp m = std.regexp.search(cur_scheduler.current.buffer, r"^\s*([-+]?\d+)")) {
          i = to!(int)(m.match(1));
          cur_scheduler.current.buffer = m.post;
        } else {
          throw(new Exception("Expected an integer from STDIN, got '" ~ cur_scheduler.current.buffer ~ "'."));
        }
        debug(instruction) stderr.writef("instruction: (%d) Read in int '%d'\n", vm.fetch_register(PC), i);
        vm.set_register(0, i);
        cur_scheduler.current.state = 3;
    }

    // Write char to STDOUT Stored in R0 
    void TRP_write_char(Instruction I) { 
        cur_scheduler.current.state = 2;
        try {
          debug(instruction) {
            if (vm.fetch_register(0) != 10)
              stderr.writef("instruction: (%d) Write out char '%s'\n", vm.fetch_register(PC), to!(char)(to!(ubyte)(vm.fetch_register(0))) );
            else
              stderr.writef("instruction: (%d) Write out char '\\n'\n", vm.fetch_register(0));
          }
          cur_scheduler.current.stdout.write(to!(char)(to!(ubyte)(vm.fetch_register(0)))); 
        } catch (Exception e) {
          stderr.writef("Failed to write to STDOUT: %s\n", e.msg);
          throw(e);
        }
        cur_scheduler.current.state = 3;
    }

    // Read  char    to STDIN  Stored in R0 
    void TRP_read_char(Instruction I) { 
        cur_scheduler.current.state = 2;
        while(!cur_scheduler.current.buffer.length) {
          cur_scheduler.current.buffer = cur_scheduler.current.stdin.readln();
        }
        char c = cur_scheduler.current.buffer[0];
        cur_scheduler.current.buffer = cur_scheduler.current.buffer[1..$];
        debug(instruction) if (c != '\n') stderr.writef("instruction: (%d) Read in char '%1s'\n", vm.fetch_register(PC), c);
        debug(instruction) if (c == '\n') stderr.writef("instruction: (%d) Read in char '\\n'\n", vm.fetch_register(PC));
        vm.set_register(0, to!(ubyte)(c));
        cur_scheduler.current.state = 3;
    }

    // Stack Underflow
    void TRP_stack_underflow(Instruction I) { 
        stderr.writef("Stack Underflow encountered!\n");
        if(vm.active_thread.id == 0)
            vm.running = false; 
        //Process cur_proc = cur_scheduler.current;
        cur_scheduler.current.state = 5;
    }

    // Stack Overflow
    void TRP_stack_overflow(Instruction I) { 
        stderr.writef("Stack Overflow encountered\n");
        if(vm.active_thread.id == 0)
            vm.running = false; 
        //Process cur_proc = cur_scheduler.current;
        cur_scheduler.current.state = 5;
    }

    // new()
    void TRP_new(Instruction I) { 
        cur_scheduler.current.state = 2;
        vm.fetch_registers(cur_scheduler.current.R);
        vm.fetch_vm_threads(cur_scheduler.current.active_threads, cur_scheduler.current.available_threads);
        sizediff_t new_size = vm.fetch_register(I.op2);
        MemoryManagement!(ulong[4]) proc_mem = read_memory!(MemoryManagement!(ulong[4]))(cur_scheduler.current.R[OF] + cur_scheduler.current.size);
        sizediff_t address = cur_scheduler.current.size + proc_mem.allocate(new_size);
        // If allocate returned 0, we're out of memory
        if(address == cur_scheduler.current.size)
        {
            stderr.writef("new: can't allocate %d, not enough memory\n", new_size);
            cur_scheduler.current.R[0] = 0; // Set R0 to null
        }
        // If end of new address is > SP, out of memory, return null
        else if(cur_scheduler.current.size + proc_mem.SL_pos >= cur_scheduler.current.R[SP])
        {
            stderr.writef("new: allocating %d bytes causes Heap overflow\n", new_size);
            cur_scheduler.current.R[0] = 0; // Set R0 to null
            proc_mem.free(new_size, address - cur_scheduler.current.size);
        }
        // If end of new address is < SP, return address
        else
        {
            write_memory!(sizediff_t)(new_size, cur_scheduler.current.R[OF] + address);
            cur_scheduler.current.R[0] = address; // Set R0 to the address allocated
            // If end of new address is > SL need to move SL
            cur_scheduler.current.R[SL] = cur_scheduler.current.size + proc_mem.SL_pos;
        }
        write_memory!(MemoryManagement!(ulong[4]))(proc_mem, cur_scheduler.current.R[OF] + cur_scheduler.current.size);
        vm.set_registers(cur_scheduler.current.R);
        vm.set_vm_threads(cur_scheduler.current.active_threads, cur_scheduler.current.available_threads);
        cur_scheduler.current.state = 3;
    }

    // delete()
    void TRP_delete(Instruction I) { 
        cur_scheduler.current.state = 2;
        vm.fetch_registers(cur_scheduler.current.R);
        vm.fetch_vm_threads(cur_scheduler.current.active_threads, cur_scheduler.current.available_threads);
        sizediff_t address = vm.fetch_register(I.op2);
        MemoryManagement!(ulong[4]) proc_mem = read_memory!(MemoryManagement!(ulong[4]))(cur_scheduler.current.R[OF] + cur_scheduler.current.size);

        int size = read_memory!(int)(cur_scheduler.current.R[OF] + address);
        proc_mem.free(size, address - cur_scheduler.current.size);

        //Set the SL again
        cur_scheduler.current.R[SL] = cur_scheduler.current.size + proc_mem.SL_pos;

        write_memory!(MemoryManagement!(ulong[4]))(proc_mem, cur_scheduler.current.R[OF] + cur_scheduler.current.size);
        vm.set_registers(cur_scheduler.current.R);
        vm.set_vm_threads(cur_scheduler.current.active_threads, cur_scheduler.current.available_threads);
        cur_scheduler.current.state = 3;
    }

    // Yield
    void TRP_yield(Instruction I) { 
        //stderr.writef("Yield called!\n");
        //Process cur_proc = cur_scheduler.current;
        stderr.writef("I should be pausing\n");
        //if(vm.active_thread.id == 0)
            vm.running = false; 
        cur_scheduler.current.state = 1;
    }

    // Scheduler switch
    void SIG_handler_0() 
    in
    {
        assert(cur_scheduler.current !is null);
    }
    body
    { 
        debug(instruction)
            stderr.writef("Ending pid[%d] at PC[%d]\n", cur_scheduler.current.pid, cur_scheduler.current.R[PC]);
        // If the process is done running, remove it from the queue
        if(cur_scheduler.current.state == 4)
        {
            //stderr.writef("Need to remove pid [%d]\n", cur_scheduler.current.pid);
            metrics.harvest(cur_scheduler.current);
            process_list.remove(cur_scheduler.current.pid);
        }
        // If it's not, slurp it's registers back into the PCB, and set the state to waiting
        else
        {
            cur_scheduler.current.state = 1;
            vm.fetch_registers(cur_scheduler.current.R);
            vm.fetch_vm_threads(cur_scheduler.current.active_threads, cur_scheduler.current.available_threads);
        }
        shell_proc.state = 3;
        cur_scheduler.next();
        //cur_scheduler.current = cur_scheduler.next();
        if(cur_scheduler.current !is null)
        {
            debug(instruction)
                stderr.writef("Starting pid[%d] at PC[%d]\n", cur_scheduler.current.pid, cur_scheduler.current.R[PC]);
            vm.set_registers(cur_scheduler.current.R);
            vm.set_vm_threads(cur_scheduler.current.active_threads, cur_scheduler.current.available_threads);
            metrics.switches++;
            cur_scheduler.current.state = 3;
        }
        shell_proc.state = 2;
        //vm.dump_registers(format("Going back to VM for pid[%d]", cur_scheduler.current.pid));
    }

    T read_memory(T)(size_t loc = 0)
    {
        to_ByteCode!(T) data;
        data.bytes[0..$] = vm.read(data.bytes.length, loc);
        return data.data;
    }

    void write_memory(T)(T data, size_t loc = 0)
    {
        to_ByteCode!(T) bytes;
        bytes.data = data;
        vm.load(bytes.bytes, loc);
    }

    @property string prompt()
    {
        return "[Kainix " ~ getcwd() ~ "]# ";
    }

public:
    this(VirtualMachine vm = new VirtualMachine()) {
        this.vm = vm;
        init();
    }

    void init() {
        stdin = new FileCompat(std.stdio.stdin);
        stdout = new FileCompat(std.stdio.stdout);
        stderr = new FileCompat(std.stdio.stderr);
        
        vm.register_TRP_handler(0, &TRP_terminate);
        vm.register_TRP_handler(1, &TRP_write_int);
        vm.register_TRP_handler(2, &TRP_read_int);
        vm.register_TRP_handler(3, &TRP_write_char);
        vm.register_TRP_handler(4, &TRP_read_char);
        vm.register_TRP_handler(5, &TRP_stack_underflow);
        vm.register_TRP_handler(6, &TRP_stack_overflow);
        vm.register_TRP_handler(7, &TRP_new);
        vm.register_TRP_handler(8, &TRP_delete);
        vm.register_TRP_handler(9, &TRP_yield);

        vm.register_SIG_handler(0, &SIG_handler_0);

        MemoryManagement!(ulong[32]) system_memory;
        version(TINY)
        {
            system_memory.block_size = 512;
            system_memory.used = 16;
            //vm.size = 4096;
            //vm.virt_size = 8192;
            vm.size = (system_memory.used * system_memory.block_size) / 2;
            version(VIRTUALMEMORY)
            {
                vm.virt_size = system_memory.used * system_memory.block_size;
                vm.virt2phys = &vmm.virt2phys;
                vmm.page_in = vm.page_in;
                vmm.page_out = vm.page_out;
                vmm.size = (system_memory.used * system_memory.block_size) / 2;
                vmm.virt_size = system_memory.used * system_memory.block_size;
            }
        }
        else version(HUGE)
        {
            system_memory.block_size = KFS.block_size;
            system_memory.used = system_memory.max_used;
            vm.size = (system_memory.used * system_memory.block_size) / 2;
            stderr.writef("Size: %d\n", vm.size);
            //vm.virt_size = system_memory.used * system_memory.block_size;
            stderr.writef("Virt_size: %d\n", vm.size);
        }
        else
        {
            system_memory.block_size = KFS.block_size;
            system_memory.used = system_memory.max_used;
            vm.size = (system_memory.used * system_memory.block_size) / 2;
            stderr.writef("Size: %d\n", vm.size);
            //vm.virt_size = system_memory.used * system_memory.block_size;
            stderr.writef("Virt_size: %d\n", vm.size);
        }
        system_memory.allocate(system_memory.sizeof);
        write_memory!(MemoryManagement!(ulong[32]))(system_memory);
        //writef("System Memory info: vm.size[%d], bits in map[%d], system_memory.block_size[%d]\n", vm.size, system_memory.used, system_memory.block_size);

        alldone = false;

        commands["load"] = &do_load;
        commands["run"]  = &do_run;
        commands["runall"]  = &do_runall;
        commands["exit"] = &do_exit;
        commands["quit"] = &do_exit;
        commands["help"] = &do_help;
        commands["ps"]   = &do_ps;
        commands["mem"]  = &do_mem;
        commands["free"]  = &do_mem;
        commands["kill"]  = &do_kill;
        commands["set"]  = &do_set;
        commands["sched"]  = &do_sched;
        commands["priority"]  = &do_priority;
        commands["metrics"]  = &do_metrics;
        // IO commands
        commands["ls"]    = &do_ls;
        commands["cd"]    = &do_cd;
        commands["mkdir"] = &do_mkdir;
        commands["cat"]   = &do_cat;
        //df, du, ln, rm, pwd, tail, head, mkdir, touch, mv, and cp
        commands["df"]    = &do_df;
        commands["du"]    = &do_du;
        commands["ln"]    = &do_ln;
        commands["rm"]    = &do_rm;
        commands["mv"]    = &do_mv;
        commands["cp"]    = &do_cp;
        commands["pwd"]   = &do_pwd;
        commands["tail"]  = &do_tail;
        commands["head"]  = &do_head;
        commands["touch"] = &do_touch;
        // Help commands
        helps["load"] = &help_load;
        helps["run"]  = &help_run;
        helps["exit"] = &help_exit;
        helps["quit"] = &help_exit;
        helps["help"] = &help_help;
        helps["!ls"]  = &help_real_ls;
        helps["!cd"]  = &help_real_cd;
        helps["ps"]   = &help_ps;
        helps["sched"]= &help_sched;
        valid_registers = new Valid_Registers();
        PC = valid_registers.to_Register["PC"];
        SL = valid_registers.to_Register["SL"];
        SB = valid_registers.to_Register["SB"];
        SP = valid_registers.to_Register["SP"];
        FP = valid_registers.to_Register["FP"];
        OF = valid_registers.to_Register["OF"];
        TC = valid_registers.to_Register["TC"];

        // Setup schedulers
        schedulers["RoundRobin"] = new RoundRobin(vm);
        schedulers["FirstComeFirstServe"] = new FirstComeFirstServe(vm);
        schedulers["Priority"] = new Priority(vm);

        // Set default scheduler
        cur_scheduler = schedulers["RoundRobin"];

        // Create the perf metrics
        metrics = new PerfMetrics;
    }

    void shell(std.stdio.File instream, bool e = false) {
        version(KFS)
            DISK = std.stdio.File("DISK", "r+b");
        try
        {
            chdir(std.file.getcwd());
        }
        catch(Exception e)
        {
            chdir("/");
            stderr.writef("Failed to chdir to host Environment \"PWD\" [%s]: %s\n", std.file.getcwd(), e.msg);
        }
        echo = e;
        shell_proc = new Process("shell", [stdin, stdout, stderr]);
        shell_proc.state = 3;
        shell_proc.pid = max_procs;
        string input;
        while(!alldone && !instream.error && !instream.eof) {
            writef("%s", prompt);
            input = chomp(instream.readln());
            if(input.length > 1 && input[0] == '#') // Discard comments
            {
                input = chomp(instream.readln());
            }
            if(echo)
                writef("%s\n", input);
            if(RegExp m = std.regexp.search(input, r"\s*(\S+)\s*(.*)")) {
                void delegate(string) cmd = commands.get(m.match(1), null);
                if(cmd !is null)
                {
                    try
                    {
                        cmd(m.match(2));
                    }
                    catch(Exception e)
                    {
                        stderr.writef("%s failed: %s\n", m.match(1), e.msg);
                    }
                }
                else
                {
                    unknown_command(input);
                }
            } 
        }
        shell_proc.state = 4;
        version(KFS)
            DISK.close();
    }
}
