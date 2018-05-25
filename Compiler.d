// Compiler Module

module Compiler;
import Utilities;

import std.stdio;
import std.string;
import std.regex;
import std.conv;
import std.exception;
import std.array;
import std.algorithm;

//debug = log0; // print_symbols
//debug = log1; // Grammar debug
//debug = log2; // Semantic Action Routines debug
//debug = log3; // Semantic Action Routines info
//debug = log4; // Semantic Action Routines verbose info
//debug = log5; // Icode
//debug = log6; // symbol size_of
//debug = log7; // Tcode
//debug = log8; // Tcode extra debug
//debug = log9; // Phases
//debug = SymbolTable; // SymbolTable debug
//debug = Tokenizer;
//debug = tokenizer;
//debug = gen_error;

class Token 
{
private:
    string _lexeme;
    string _type;
    int _line;
    this() {}

public:
    this(string _lexeme, string _type, int _line) 
    {
        this._lexeme = _lexeme;
        this._type = _type;
        this._line = _line;
    }

    override string toString() {
        return format("%d: %s (%s)", _line, _lexeme, _type);
    }

    // Read only properties
    @property string type() { return _type; }
    @property string lexeme() { return _lexeme; }
    @property int line() { return _line; }
}

class Grammar 
{
private:
public:
    // Keep a list of all lexeme regular expressions
    string[string] token_type_regexps;
    // We need to prioritize which types to search for first
    string[] search_type_group_priority;
    string[][string] search_type_priority;
    string comment;
    this() 
    {
        // Which types of tokens get searched first.
        search_type_group_priority = [
            "names_types_literals",
            "unknown",
            ];
        // Preserve the search_type_priority in which to search for token_type_regexps
        search_type_priority["names_types_literals"] = [
            "type",
            "modifier",
            "keyword",
            "class_name",
            "identifier",
            "punctuation",
            //"numeric_literal",
            "character_literal",
            "symbol",
            "number",
            //"printable_ascii",
            //"nonprintable_ascii",
            ];
        search_type_priority["unknown"] = [
            "not_ws",
            ];


        token_type_regexps["comment"] = 
            r"//.*";
        token_type_regexps["keyword"] = 
            r"atoi\b|class\b|cin\b|cout\b|else\b|false\b|if\b|itoa\b|main\b|new\b|null\b|object\b|public\b|private\b|return\b|string\b|this\b|true\b|while\b";
        token_type_regexps["modifier"] = 
            r"public\b|private\b";
        token_type_regexps["class_name"] = 
            r"";
        token_type_regexps["type"] = 
            r"int\b|char\b|bool\b|void\b"; // Or class_name 
        token_type_regexps["printable_ascii"] = 
            r"[\x20-\x7E]"; // ASCII codes 32-126
        token_type_regexps["nonprintable_ascii"] = 
            r"[\x00-\x19\x7F]"; // ASCII codes 0-31 and 127
        token_type_regexps["escaped_chars"] = 
            r"\\n"; // ASCII codes 32-126
        token_type_regexps["character"] = 
            r"(:?" ~ 
            token_type_regexps["printable_ascii"] 
            ~ r"|" ~ 
            token_type_regexps["nonprintable_ascii"]
            ~ r"|" ~ 
            token_type_regexps["escaped_chars"]
            ~ r")"
            ;
        token_type_regexps["character_literal"] = 
            r"'" ~ token_type_regexps["character"] ~ r"'";
        token_type_regexps["number"] =
            r"\d+";


        token_type_regexps["io_operator"] = 
            r"<<|>>";
        token_type_regexps["identifier"] = 
            r"[A-Za-z][A-Za-z_0-9]{0,79}\b"; 
        token_type_regexps["punctuation"] = 
            r"[;,.]";
        token_type_regexps["math_symbol"] = 
            r"[+-/*\^%]";
        token_type_regexps["relational_symbol"] = 
            r"[\<\>!=][=]?";
        token_type_regexps["boolean_operator"] = 
            r"&&|\|\|";
        token_type_regexps["assignment_operator"] = 
            r"=";
        token_type_regexps["array_operator"] = 
            r"[\[\]]";
        token_type_regexps["block_indicator"] = 
            r"[\{\}]";
        token_type_regexps["parenthesis"] = 
            r"[\(\)]";
        token_type_regexps["symbol"] = 
            token_type_regexps["io_operator"]
            ~ r"|" ~ 
            token_type_regexps["math_symbol"]
            ~ r"|" ~ 
            token_type_regexps["relational_symbol"]
            ~ r"|" ~ 
            token_type_regexps["boolean_operator"]
            ~ r"|" ~ 
            token_type_regexps["assignment_operator"]
            ~ r"|" ~ 
            token_type_regexps["array_operator"]
            ~ r"|" ~ 
            token_type_regexps["block_indicator"]
            ~ r"|" ~ 
            token_type_regexps["parenthesis"]
            ;


        token_type_regexps["ws"] = 
            r"\s";
        token_type_regexps["not_ws"] = 
            r"\S"; // Last resort
    }
    
    void add_class(string new_type)
    {
        //stderr.writef("Adding class: %s\n", new_type);
        if(!token_type_regexps.get("class_name", "").length)
        {
            token_type_regexps["class_name"] = new_type ~ r"\b";
        }
        else
        {
            token_type_regexps["class_name"] ~= r"|" ~ new_type;
        }
        //token_type_regexps["type"] ~= r"|" ~ new_type;
    }

    bool is_type(string type)
    {
        bool is_type;
        if(auto m = std.regex.matchFirst(type, token_type_regexps["type"]))
            is_type = true;
        return is_type;
    }

    bool is_class(string type)
    {
        bool is_class;
        if(auto m = std.regex.matchFirst(type, token_type_regexps["class_name"]))
            is_class = true;
        return is_class;
    }
}

class Tokenizer 
{
private:
    Grammar grammar;
    uint _line_num;
    char[] buffer;
    string filename;
    File infile;
    Token[] tokens;
    this() {}
public:
    this(string filename) 
    {
        grammar = new Grammar;
        this.filename = filename;
        infile.open(filename);
        fill_buffer();
        read_token();
    }

    @property uint line_num() { return _line_num; }
    @property Token ct() { return tokens[0]; }

    void rewind()
    {
        _line_num = 0;
        infile.close();
        buffer.length = 0;
        tokens.length = 0;

        infile.open(filename);
        read_token();
    }

    void fill_buffer() 
    {
        // If the buffer is empty, we need to fill it up.
        // We want to continue while the buffer is empty, and while we are reading data from the file
        while(!buffer.length && infile.readln(buffer) > 0) 
        {
            _line_num++;
            // Drop newline at the end of the line, its not important
            buffer = chomp(buffer);
            debug(Tokenizer)
                stderr.writef("%-5d: %s\n", _line_num, buffer);
            // Strip whitespace from the beginning
            if(auto m = std.regex.matchFirst(buffer, r"^(:?" ~ grammar.token_type_regexps["ws"] ~ r")*"))
                buffer = m.post();
            // Strip comments off the end
            if(auto m = std.regex.matchFirst(buffer, r"(:?" ~ grammar.token_type_regexps["comment"] ~ r")$"))
                buffer = m.pre();
            debug(tokenizer)
                stderr.writef("  fill_buffer: Result from read and strip: [%s]\n", buffer);
        }
    }

    void read_token() 
    {
        if(!buffer.length) 
        {
            fill_buffer();
        }
        // If the buffer is empty, we've reached the end of our ability to read the file (ie: all done).
        // So we setup an End of Tokens token
        if(!buffer.length) 
        {
            tokens ~= new Token("EOT", "EOT", _line_num);
            return;
        }
        bool found = false;
        foreach(type_order; grammar.search_type_group_priority) 
        {
            foreach(type; grammar.search_type_priority[type_order]) 
            {
                string search_value = grammar.token_type_regexps.get(type, "error");
                if(search_value.length)
                {
                    if(auto m = std.regex.matchFirst(buffer, r"^(" ~ search_value ~ r")" ~ grammar.token_type_regexps["ws"] ~ r"*")) 
                    {
                        buffer = m.post();
                        debug(tokenizer) stderr.writef("Picked out the token [%s][%s]\n", type, m[1]);
                        tokens ~= new Token(to!(string)(m[1]), type, _line_num);
                        found = true;
                        break;
                    }
                }
            }
            if(found)
                break;
        }
    }

    Token peek(uint count) 
    {
        // Add tokens until there is enough to peek at
        foreach(i; tokens.length..count + 1) 
        {
            read_token();
        }
        // If we have the peeked at value, fine
        // If not, you get the last one (which should be EOT);
        if(count >= tokens.length) 
            return tokens[$-1];
        else
            return tokens[count];
    }

    void nextToken() 
    {
        // If we have tokens, consume one
        if(tokens.length)
            tokens = tokens[1..$];
        // If we're out of tokens, get another one
        if(!tokens.length) 
        {
            read_token();
        }
    }

    void add_current_class()
    {
        //stderr.writef("Adding class: %s\n", tokens[0].lexeme);
        grammar.add_class(tokens[0].lexeme);
    }

    bool is_type(string s)
    {
        return grammar.is_type(s);
    }

    bool is_class(string s)
    {
        return grammar.is_class(s);
    }
}

class Symbol
{
private:
public:
    string[string] info;
    string[string] data;

    this() {}

    void set_info(string[string] info)
    {
        foreach(key, value; info)
        {
            if(!value.length)
                this.info.remove(key);
            else
                this.info[key] = value;
        }
    }

    void set_data(string[string] data)
    {
        foreach(key, value; data)
        {
            if(!value.length)
                this.data.remove(key);
            else
                this.data[key] = value;
        }
    }

    void add_param(string param)
    {
        if(!data.get("Param", "").length)
        {
            data["Param"] = param;
        }
        else
        {
            data["Param"] = param ~ "|" ~ data["Param"];
        }
    }

    override string toString()
    {
        //return format("\n  Scope[%s]\n  Symid[%s]\n  Value[%s]\n  Kind[%s]\n  data[%s]", info.get("Scope", ""), info.get("Symid",""), info.get("Value",""), info.get("Kind",""), data);
        return format("\n  info%s\n  data%s", info, data);
    }
}

class SymbolTable
{
private:
    Symbol[string] symIDsymbols;
    Symbol[][string] scopesymbols;
    uint[string] counts;
    uint count = 100;
    uint tmp_count = 1;
    size_t[string] sizes;
public:
    this() 
    {
        sizes["char"] = 4;
        sizes["bool"] = 4;
        sizes["int"] = 4;
    }

    void add_symbol(ref Symbol s)
    {
        if(s is null)
        {
            throw(new Exception("Tried to add a null symbol\n"));
        }
        debug(SymbolTable) stderr.writef("Adding symbol [%s]\n", s);
        // Keep a count of how many Symbols have been used, and set the new Symbol Symid appropriately
        s.set_info(["Symid":format("%s%03d", s.info.get("Kind","x").toUpper()[0], count++)]);
        if(s.info.get("Value", "") == "")
            s.set_info(["Value":s.info["Symid"]]);
        symIDsymbols[s.info["Symid"]] = s;
        scopesymbols[s.info["Scope"]] ~= s;
        debug(SymbolTable) stderr.writef("Done adding symbol [%s]\n", s);
    }

    void print_symbols()
    {
        //foreach(id; symIDsymbols.byKey())
        //{
        //    writef("[%s] %s\n", id, symIDsymbols[id]);
        //}
        foreach(id; scopesymbols.byKey())
        {
            foreach(symbol; scopesymbols[id])
            {
                stderr.writef("[%s] %s\n", id, symbol);
            }
        }
    }

    Symbol get(string Symid)
    {
        if(Symid.length && Symid[0] == '*')
            return symIDsymbols.get(Symid[1..$], null);
        else
            return symIDsymbols.get(Symid, null);
    }

    Symbol find(string identifier, string[] _scope)
    {
        string[] search_scope = _scope.dup;
        Symbol retval;
        bool found = false;
        debug(SymbolTable) 
            stderr.writef("SymbolTable.find: Identifier[%s], Scope[%s].\n", identifier, search_scope.join("."));
        while(!search_scope.empty)
        {
            foreach(symbol; scopesymbols.get(search_scope.join("."), null))
            {
                debug(SymbolTable)
                    stderr.writef("Inspecting %s.%s == %s\n", search_scope.join("."), symbol.info.get("Value", ""), identifier);
                if(symbol.info.get("Value", "") == identifier)
                {
                    retval = symbol;
                    found = true;
                    break;
                }
            }
            if(found)
                break;
            search_scope.popBack;
        }
        debug(SymbolTable) 
        {
            if(retval !is null) 
                stderr.writef("Found %s[%s]\n", _scope.join("."), retval);
            else 
                stderr.writef("Couldn't find [%s.%s]\n", _scope.join("."), identifier);
        }
        return retval;
    }

    Symbol find(string identifier, string _scope)
    {
        return find(identifier, std.string.split(_scope,(".")));
    }

    string[] find_scope(string identifier, string[] _scope)
    {
        string[] retval;
        string[] search_scope = _scope.dup;
        debug(log3) stderr.writef("SymbolTable.find_scope: Identifier[%s], Scope[%s].\n", identifier, search_scope.join("."));
        while(!search_scope.empty)
        {
            debug(log3) stderr.writef("SymbolTable.find_scope: Need to check if [%s.%s] is a scope\n", search_scope.join("."), identifier);
            if(scopesymbols.get(format("%s.%s", search_scope.join("."), identifier), null) !is null)
            {
                retval = search_scope.dup ~ identifier;
                break;
            }
            search_scope.popBack;
        }
        if(!retval.empty)
        {
            debug(log3) stderr.writef("SymbolTable.find_scope: I think scope [%s] exists\n", retval.join("."));
        }
        return retval;
    }

    Symbol add_global(string type, string value)
    {
        Symbol new_symbol = find(value, ["g"]);
        if(new_symbol is null)
        {
            new_symbol = new Symbol();
            new_symbol.set_info(["Scope":"g", "Kind":"gvar", "Value":value]);
            new_symbol.set_data(["Type":type, "accessMod":"public", "StaticData":value[2..$]]);
            add_symbol(new_symbol);
        }
        return new_symbol;
    }

    Symbol gen_tmp(string[] _scope, string type)
    {
        debug(SymbolTable) 
            stderr.writef("Adding a temporary [%s] in [%s]\n", type, _scope.join("."));
        Symbol new_symbol = new Symbol();
        new_symbol.set_info(["Scope":_scope.join("."), "Kind":"lvar", "Value":format("tmp%s", tmp_count++)]);
        new_symbol.set_data(["Type":type, "accessMod":"private"]);
        add_symbol(new_symbol);
        debug(SymbolTable) 
            stderr.writef("Added temporary [%s] in [%s]\n", new_symbol.info["Symid"], _scope.join("."));
        return new_symbol;
    }

    size_t size_of(string Symid, int line = __LINE__)
    {
        size_t retval;
        Symbol interesting = symIDsymbols.get(Symid, null);
        debug(log6) stderr.writef("[%d] Checking size of %s, %s\n", line, Symid, interesting);
        enforce(interesting !is null, format("Tried to check size of Symid[%s], but it wasn't there", Symid));
        if(interesting.data.get("Type", "--")[0] == '@')
        {
            debug(log6) stderr.writef("Array detected\n");
            retval = to!(int)(sizes.get(interesting.data["Type"][1..$], -1));
            if(retval == -1)
            {
                debug(log6) stderr.writef("Need to calculate size of a %s\n", interesting.data["Type"]);
                retval = 0;
                foreach(symbol; scopesymbols.get("g." ~ interesting.data["Type"][1..$], null))
                {
                    debug(log6) stderr.writef("%s\n", symbol);
                    debug(log6) stderr.writef("Size is %s\n", sizes.get(symbol.data.get("Type", ""), 0));
                    retval += sizes.get(symbol.data.get("Type", ""), 0);
                }
                sizes[interesting.data["Type"][1..$]] = retval;
            }
        }
        else if(interesting.info["Kind"] == "class")
        {
            debug(log6) stderr.writef("Class detected [%s]\n", interesting.info["Scope"] ~ "." ~ interesting.info["Value"]);
            retval = to!(int)(sizes.get(interesting.info["Scope"] ~ "." ~ interesting.info["Value"], int.max));
            if(retval == int.max)
            {
                debug(log6) stderr.writef("Need to calculate size of a %s\n", interesting.info["Scope"] ~ "." ~ interesting.info["Value"]);
                retval = 0;
                foreach(symbol; scopesymbols.get(interesting.info["Scope"] ~ "." ~ interesting.info["Value"], null))
                {
                    if(symbol.info.get("Kind", "UNKNOWN") != "method")
                    {
                        debug(log6) stderr.writef("%s\n", symbol);
                        debug(log6) stderr.writef("Size is: %d\n", sizes.get(symbol.data.get("Type", ""), 4));
                        symbol.data["HeapPos"] = format("+%s", retval);
                        retval += sizes.get(symbol.data.get("Type", ""), 4);
                        //stderr.writef("%s\n", symbol);
                    }
                    else
                    {
                        debug(log6) stderr.writef("Skiping function %s\n", symbol.info["Value"]);
                    }
                }
                sizes[interesting.info["Scope"] ~ "." ~ interesting.info["Value"]] = retval;
            }
            //stderr.writef("Total size: %d\n", retval);
            //enforce(false, "unimplemented size_of for a class");
        }
        else if(interesting.info["Kind"] == "method")
        {
            debug(log6) stderr.writef("Function detected [%s]\n", interesting.info["Scope"] ~ "." ~ interesting.info["Value"]);
            retval = sizes.get(interesting.info["Scope"] ~ "." ~ interesting.info["Value"], -1);
            if(retval == -1)
            {
                debug(log6) stderr.writef("Need to calculate size of a %s\n", interesting.info["Scope"] ~ "." ~ interesting.info["Value"]);
                //stderr.writef("All Symbols: %s\n", scopesymbols.get(interesting.info["Scope"] ~ "." ~ interesting.info["Value"], null));
                // Automatically allocate 4 bytes for the PFP, and 4 bytes for 'this'
                retval = 8;
                foreach(symid; std.string.split(interesting.data.get("Param", ""),"|"))
                {
                    debug(log6) stderr.writef("Need to add this: %s\n", symid);
                    Symbol symbol = get(symid);
                    retval += sizes.get(symbol.data.get("Type", ""), 4);
                    symbol.data["StackPos"] = format("-%s", retval);
                }
                foreach(symbol; scopesymbols.get(interesting.info["Scope"] ~ "." ~ interesting.info["Value"], null))
                {
                    debug(log6) stderr.writef("Encountered this while inspecting the method %s %s\n", symbol.info.get("Kind", "UNKNOWN"), symbol.info["Value"]);
                    if(symbol.info.get("Kind", "UNKNOWN") != "param")
                    {
                        retval += sizes.get(symbol.data.get("Type", ""), 4);
                        symbol.data["StackPos"] = format("-%s", retval);
                    }
                    else
                    {
                        debug(log6) stderr.writef("Skipping %s\n", symbol.info["Value"]);
                    }
                    //debug(log6) stderr.writef("Size of %s is: %d\n", symbol.info.get("Kind", "UNKNOWN"), sizes.get(symbol.data.get("Type", ""), 4));
                    //debug(log6) stderr.writef("%s\n", symbol);
                }
                sizes[interesting.info["Scope"] ~ "." ~ interesting.info["Value"]] = retval;
            }
        }
        else if(interesting.info["Kind"] == "lvar")
        {
            Symbol type_symbol = find(interesting.data["Type"], interesting.info["Scope"]);
            enforce(type_symbol !is null, "Tried to find the type, and failed");
            retval = size_of(type_symbol.info["Symid"]);
        }
        else
        {
            retval = to!(int)(sizes.get(interesting.data["Type"], int.max));
            if(retval == int.max)
            {
                retval = 0;
                debug(log6) stderr.writef("**** Need to calculate size of a %s %s\n", interesting.info["Kind"], interesting.data["Type"]);
                if(interesting.info.get("Kind", "") != "method")
                {
                    debug(log6) stderr.writef("Size is %s\n", sizes.get(interesting.data.get("Type", ""), 4)); 
                    retval += sizes.get(interesting.data.get("Type", ""), 4);
                    sizes[interesting.data["Type"]] = retval;
                }
                else
                {
                    debug(log6) stderr.writef("Size is %s\n", 0);
                }
                //enforce(false, format("Unknown type %s %s", interesting.info["Kind"], interesting.info["Value"]));
            }
        }
        debug(log6) stderr.writef("All sizes: %s\n", sizes);
        return retval;
    }
}

Tcode tcode;
class Tcode
{
    string[4][] data;
    string[size_t] labels;
    Valid_Registers valid_registers;
    string[] unused_registers;
    string[string] symbol_to_register;
    string[][string] register_to_symbols;
    void delegate(string[])[string] quad_ops;
    SymbolTable symbols;
    // State variables
    string result_register;
    string[string] q1;
    string[string] q2;
    File outfile;
    string cur_label;
    int[string] label_count;
    string this_Symid;
    string FP;
    this(string[4][] data, string[size_t] labels, SymbolTable symbols)
    {
        this.data = data;
        this.labels = labels;
        this.symbols = symbols;
        valid_registers = new Valid_Registers();
        quad_ops["FRAME"] = &do_FRAME;
        quad_ops["CALL"]  = &do_CALL;
        quad_ops["PUSH"]  = &do_PUSH;
        quad_ops["POP"]   = &do_POP;
        quad_ops["PEEK"]  = &do_PEEK;
        quad_ops["MOVI"]  = &do_MOVI;
        quad_ops["MOV"]   = &do_MOV;
        quad_ops["JMP"]   = &do_JMP;
        quad_ops["AND"]   = &do_AND;
        quad_ops["OR"]    = &do_OR;
        quad_ops["BF"]    = &do_BF;
        quad_ops["EQ"]    = &do_EQ;
        quad_ops["NE"]    = &do_NE;
        quad_ops["LT"]    = &do_LT;
        quad_ops["GT"]    = &do_GT;
        quad_ops["GE"]    = &do_GE;
        quad_ops["LE"]    = &do_LE;
        quad_ops["WRITE"] = &do_WRITE;
        quad_ops["READ"]  = &do_READ;
        quad_ops["ADD"]   = &do_ADD;
        quad_ops["SUB"]   = &do_SUB;
        quad_ops["MUL"]   = &do_MUL;
        quad_ops["DIV"]   = &do_DIV;
        quad_ops["RTN"]   = &do_RTN;
        quad_ops["RETURN"]= &do_RETURN;
        quad_ops["NEW"]   = &do_NEW;
        quad_ops["NEWI"]  = &do_NEWI;
        quad_ops["REF"]   = &do_REF;
        quad_ops["EOP"]   = &do_EOP;
        quad_ops["NOP"]   = &do_NOP;
        foreach(key; valid_registers.to_Register.keys())
        {
            if(key[0] == 'R' && key[1] != '0') // General purpose registers start with R, special purpose ones don't
            {
                //stderr.writef("%s\n", key);
                unused_registers ~= key;
            }
        }
        FP = "FP";
    }
    string gen_label(string new_label)
    {
        label_count[new_label] = label_count.get(new_label, 0) + 1;
        return format("%s%d", new_label, label_count[new_label]);
    }
    void print_line(string opcode, string op1, string op2 = "", string comment = ";")
    {
        // Print the line, and consume the label
        assert(comment[0] == ';');
        if(op2.empty)
            outfile.writef("%-10s%-8s%-8s%-8s%s\n", cur_label, opcode, op1, op2, comment);
        else
            outfile.writef("%-10s%-8s%-8s%-8s%s\n", cur_label, opcode, format("%s,", op1), op2, comment);
        if(!cur_label.empty)
            cur_label = "";
    }
    void output(File of)
    {
        outfile = of;
        debug(log7) stderr.writef("TCode:\n");
        debug(log8) stderr.writef("List of all scopes: %s\n", symbols.scopesymbols.keys());
        // Dump Global data
        foreach(s; symbols.scopesymbols["g"])
        {
            if("StaticData" in s.data)
            {
                debug(log8) stderr.writef("%s", s);
                if(s.data["Type"] == "int")
                {
                    outfile.writef("%s\t%s\t%s\n", s.info["Symid"], ".INT", s.data["StaticData"]);
                }
                else
                {
                    string staticdata = s.data["StaticData"];
                    if(staticdata == "false")
                        staticdata = "0";
                    else if(staticdata == "true")
                        staticdata = "1";
                    //outfile.writef("%s\n", s);
                    if(s.data.get("Type", "") == "null")
                    {
                        outfile.writef("%s\t%s\t%s\t%s\n", s.info["Symid"], ".BYT", "0", ";null");
                    }
                    else
                    {
                        outfile.writef("%s\t%s\t%s\n", s.info["Symid"], ".BYT", staticdata);
                    }
                }
            }
        }
        // Generate Target Code
        foreach(index, quad; data)
        {
            // Debug output
            debug(log8) 
                stderr.writef("[%5s]%-15s %s\n", index, cur_label, quad);
                outfile.writef(";%5s%-15s %s\n", index, cur_label, quad);
            void delegate(string[]) quad_op = quad_ops.get(quad[0], null);
            enforce(quad_op !is null, format("Unimplemented Quad Op [%s]\n", quad[0]));
            // 1. Save Register Data to Memory if Beginning or End of a Basic Block
            if(labels.get(index, "") != "")
            {
                free_registers();
            }
            cur_label = labels.get(index, "");
            // 2. Use getRegister() to find an unused Register for the result of the operation
            //   a. If no unused Registers then Write Data to Memory to Free up Registers
            //     i. Generate Target Code to Free Registers
            //   b. Repeat Step 2
            if(quad[3] != "")
            {
                // getRegister will generate TCode to Free Registers
                result_register = getRegister(quad[3]);
            }
            // 3. Use getLocation(…) to find memory location of input operands
            //   a. Generate Target Code to get input operands into a Register if necessary
            // 4. Check if a operand must be moved to the result register
            //   a. Converting from three address operand to only two address operand
            //   b. Generate Target Code to move Operand to Result Register
            // 5. Generate Target Code for Operation
            quad_op(quad[1..4]);
            // Paranoid
            free_registers();
        }
    }

    void free_registers(bool save_off = true)
    {
        if(symbol_to_register.length == 0)
        {
            return;
        }
        debug(log8) stderr.writef("Freeing all registers [%s]\n", symbol_to_register);
        outfile.writef("; Freeing all registers [%s]\n", symbol_to_register);
        // Store off all data
        // Sometimes a tmp register is required, so we can't clear registers
        foreach(Symid; symbol_to_register.keys)
        {
            string freetmp = getRegister("freetmp");
            debug(log8) stderr.writef("STORE   %s -> getLocation(%s)\n", symbol_to_register[Symid], Symid);
            if(save_off)
            {
                string type;
                string[string] tmp = getLocation(Symid);
                outfile.writef(";Freeing %s: %s\n", Symid, tmp);
                enforce("R" in tmp, "Not in a register");
                if("S" in tmp)
                {
                    debug(log8) stderr.writef("STORE   %s -> getLocation(%s)\n", symbol_to_register[Symid], tmp);
                    print_line("MOV", freetmp, FP, format(";Freeing %s:%s", symbols.get(Symid).info["Value"], Symid));
                    print_line("ADI", freetmp, tmp["S"]);
                    type = symbols.get(Symid).data["Type"];
                    //stderr.writef("free_register debug *%s %s %s\n", symbols.get(Symid).data.get("Ref", ""), type, symbols.get(Symid));
                    if((type == "char" || type == "bool" || type == "null") && symbols.get(Symid).data.get("Ref", null) is null)
                    {
                        print_line("STB", tmp["R"], freetmp);
                    }
                    else
                    {
                        if("RR" in tmp)
                        {
                            print_line("STR", tmp["RR"], freetmp);
                            if((type == "char" || type == "bool" || type == "null"))
                            {
                                print_line("STB", tmp["R"], tmp["RR"]);
                            }
                            else
                            {
                                print_line("STR", tmp["R"], tmp["RR"]);
                            }
                        }
                        else
                        {
                            print_line("STR", tmp["R"], freetmp);
                        }
                    }
                } 
                else if ("M" in tmp)
                {
                    debug(log8) stderr.writef("STORE   %s -> getLocation(%s)\n", symbol_to_register[Symid], tmp);
                }
                else if ("H" in tmp)
                {
                    debug(log8) stderr.writef("STORE   %s -> getLocation(%s)\n", symbol_to_register[Symid], tmp);
                    string tmp1 = getRegister("tmp1");
                    print_line("MOV", freetmp, FP, format(";free_registers %s:%s", symbols.get(Symid).info["Value"], Symid));
                    print_line("ADI", freetmp, "-8", format(";%s = &&this", freetmp));
                    print_line("LDR", tmp1, freetmp, format(";%s = &this", tmp1));
                    print_line("ADI", tmp1, tmp["H"], format(";%s = &this.%s", tmp1, Symid));
                    type = symbols.symIDsymbols[Symid].data["Type"];
                    if(type == "char" || type == "bool" || type == "null")
                    {
                        print_line("STB", tmp["R"], tmp1);
                    }
                    else
                    {
                        print_line("STR", tmp["R"], tmp1);
                    }
                    //enforce(false, "Heap pointers unimplemented");
                }
            }
        }
        // Clear out keys
        foreach(Symid; symbol_to_register.keys)
        {
            unused_registers ~= symbol_to_register[Symid];
            register_to_symbols.remove(symbol_to_register[Symid]);
            symbol_to_register.remove(Symid);
        }
        //debug(log8) stderr.writef("Freed all registers [%s]\n", symbol_to_register);
        //outfile.writef("; Freed all registers [%s]\n", symbol_to_register);
    }

    // Will return the next available register when invoked.  
    //      It uses register descriptors to determine if a register is free (unused).
    // Register Descriptors keep track of what is currently in each register. 
    //      Not the value, that is only known at run-time.  
    //      What symbol data is currently associated with the register.
    string getRegister(string symbol)
    {
        // Check if it's already somewhere
        // Otherwise, return something with nothing in it.
        string retval = symbol_to_register.get(symbol, "");
        if(retval == "")
        {
            if(unused_registers.empty)
            {
                stderr.writef("Ran out of registers\n");
                free_registers();
                enforce(false, format("Generate TCode to free a register %s", symbol_to_register));
            }
            retval = unused_registers[$-1];
            unused_registers.length -= 1;
            symbol_to_register[symbol] = retval;
            register_to_symbols[retval] = [symbol];
        }
        debug(log8) stderr.writef("getRegister %s->[%s]\n", symbol, retval);
        return retval;
    }

    // Will return the location(s) of where a symbolic data item can be found at run-time.
    // Valid Locations are:
    //      register(register#) – the symbol id is already in a register 
    //      stack(-offset) – the symbol id is located in the current activation record
    //      heap(+offset) – the symbol id is for some attribute allocated by new 
    //      memory(Address) – the symbol id is global
    string[string] getLocation(string Symid)
    {
        string[string] retval;
        if(Symid in symbol_to_register)
        {
            retval["R"] = symbol_to_register[Symid];
        }
        if(Symid in symbols.symIDsymbols)
        {
            if(symbols.symIDsymbols[Symid].info["Scope"] == "g")
            {
                retval["M"] = symbols.symIDsymbols[Symid].info["Symid"];
            }
            else if(symbols.symIDsymbols[Symid].data.get("StackPos", "") != "")
            {
                retval["S"] = symbols.symIDsymbols[Symid].data["StackPos"];
            }
            else if(symbols.symIDsymbols[Symid].data.get("HeapPos", "") != "")
            {
                retval["H"] = symbols.symIDsymbols[Symid].data["HeapPos"];
            }
            if("*" ~ Symid in symbol_to_register)
            {
                //retval["RR"] = retval["R"];
                //retval["R"] = symbol_to_register["*" ~ Symid];
                retval["RR"] = symbol_to_register["*" ~ Symid];
            }
        }
        debug(log8) stderr.writef("getLocation: %s[%s]\n", Symid, retval);
        return retval;
    }

    string[string] load_to_reg(string Symid)
    {
        string[string] retval = getLocation(Symid);
        string type;
        bool is_ref = false;
        if("R" !in retval)
        {
            if(Symid[0] == '*')
            {
                // Reserve a register for the actual value
                getRegister(Symid);
                is_ref = true;
                Symid = Symid[1..$];
            }
            debug(log8) stderr.writef("load_to_reg: %s\n", retval);
            getRegister(Symid);
            retval = getLocation(Symid);
            string tmp0 = getRegister("tmp0");
            type = symbols.get(Symid).data["Type"];
            if("S" in retval)
            {
                string loc = retval.get("RR", retval["R"]);
                print_line("MOV", tmp0, FP, format(";load_to_reg %s:%s", symbols.get(Symid).info["Value"], Symid));
                print_line("ADI", tmp0, retval["S"], ";load_to_reg");
                if(!is_ref && (type == "char" || type == "bool" || type == "null") && symbols.get(Symid).data.get("Ref", null) is null)
                {
                    print_line("LDB", loc, tmp0, ";load_to_reg");
                }
                else
                {
                    print_line("LDR", loc, tmp0, ";load_to_reg");
                }
            }
            else if("M" in retval)
            {
                if(!is_ref && type == "char" || type == "bool" || type == "null")
                {
                    print_line("LDB", retval["R"], retval["M"], format(";load_to_reg %s", Symid));
                }
                else
                {
                    print_line("LDR", retval["R"], retval["M"], format(";load_to_reg %s", Symid));
                }
            }
            else if ("H" in retval)
            {
                string tmp1 = getRegister("tmp1");
                print_line("MOV", tmp0, FP, format(";load_to_reg %s:%s", symbols.get(Symid).info["Value"], Symid));
                print_line("ADI", tmp0, "-8", format(";%s = &&this",tmp0));
                print_line("LDR", tmp1, tmp0, format(";%s = &this", tmp1));
                print_line("ADI", tmp1, retval["H"], format(";%s = &this.%s", tmp1, Symid));
                if(!is_ref && type == "char" || type == "bool" || type == "null")
                {
                    print_line("LDB", retval["R"], tmp1, ";load_to_reg");
                }
                else
                {
                    print_line("LDR", retval["R"], tmp1, ";load_to_reg");
                }
                //enforce(false, "Unimplemented Heap");
            }
            else
            {
                enforce(false, format("load_to_reg failed: %s:%s", retval, symbols.get(Symid)));
            }
            if(is_ref)
            {
                enforce("S" in retval);
                enforce("R" in retval);
                enforce("H" !in retval);
                enforce("M" !in retval);
                debug(log8) stderr.writef("Location for value is in location %s\n%s\n", retval, symbol_to_register);
                enforce(retval["RR"] != retval["R"]);
                if(!is_ref && type == "char" || type == "bool" || type == "null")
                {
                    print_line("LDB", retval["R"], retval["RR"], ";load_to_reg: Register Indirect");
                }
                else
                {
                    print_line("LDR", retval["R"], retval["RR"], ";load_to_reg: Register Indirect");
                }
                //stderr.writef("%s\n", retval);
                //enforce(false, "Unimplemented register indirect");
            }
        }
        return retval;
    }

    void do_FRAME(string[] args)
    {
        debug(log7) stderr.writef("FRAME %s\n", args);
        Symbol func_symbol = symbols.symIDsymbols.get(args[0], null);
        enforce(func_symbol !is null, "Non existant Symbol");
        debug(log8) stderr.writef("func_symbol %s\n", func_symbol);
        enforce(func_symbol.info.get("Kind", "") == "method", "Symbol is not a method");
        debug(log8) stderr.writef("Searching scope: %s\n", func_symbol.info.get("Scope", "UNKNOWN") ~ "." ~ func_symbol.info.get("Value", "UNKNOWN"));
        string func_scope = func_symbol.info.get("Scope", "UNKNOWN") ~ "." ~ func_symbol.info.get("Value", "UNKNOWN");
        foreach(s; symbols.scopesymbols.get(func_scope, null))
        {
            debug(log8) stderr.writef("symbol %s\n", s);
        }
        string tmp1 = getRegister("tmp1");
        string tmp2 = getRegister("tmp2");
        string tmp3 = getRegister("tmp3");
        //MOV     R0,     FP      ;Save FP in R3, this will be the PFP
        print_line("MOV", "R0", FP, ";Save FP, this will be the PFP");
        //        ADI     SP,     -4      ;Adjust Stack Pointer for Return Address
        print_line("ADI", "SP", "-4", ";Adjust Stack Pointer for Return Address");
        //        MOV     FP,     SP      ;Point at Current Activation Record     (FP = SP)       
        print_line("MOV", FP, "SP", ";Point at Current Activation Record     (FP = SP)");
        FP = "R0";
        //        ADI     SP,     -4      ;Adjust Stack Pointer for PFP
        print_line("ADI", "SP", "-4", ";Adjust Stack Pointer for PFP");
        //        STR     R0,     SP      ;PFP to Top of Stack                    (PFP = FP)
        print_line("STR", FP, "SP", ";PFP to Top of Stack                    (PFP = FP)");
        //        MOV     tmp1,     SP      ;Check for Stack Overflow
        print_line("MOV", tmp1, "SP", ";Check for Stack Overflow");
        //        CMP     tmp1,     SL      ;
        print_line("CMP", tmp1, "SL", ";");
        //        BLT     tmp1,     OVERFL  ;
        print_line("BLT", tmp1, "EOP", ";Jump to End of program instead of Stack Overflow!");
        if(args[1] == "this")
        {
            print_line("MOV", tmp2, FP, format(";Fetching \"this\""));
            print_line("ADI", tmp2, "-8", format(";%s = &&this",tmp2));
            print_line("LDR", tmp3, tmp2, format(";%s = &this", tmp3));
            print_line("ADI", "SP", "-4", ";Allocating space for empty \"this\"");
            print_line("STR", tmp3, "SP");
        }
        else
        {
            print_line("ADI", "SP", "-4", ";Allocating space for \"this\"");
            q1 = load_to_reg(args[1]);
            print_line("STR", q1["R"], "SP");
        }
        free_registers(false);
        //cur_label = "EOP";
        //print_line("TRP", "0", "");
        //;END of MAIN Activation Record
        //
        //;Stack Overflow function
        //;Exits the program
        //OVERFL  LDA     R3,     PROVFL  ;Print Overflow!
        //        SUB     R2,     R2      ;
        //        ADI     R2,     10
        //        MOV     R1,     PC      ;PC incremented by 1 instruction
        //        ADI     R1,     24      ;Compute Return Address (always a fixed amount)
        //        JMP     PRINTC
        //        TRP     0
        //PROVFL  .BYT    'O' ;0
        //        .BYT    'v'
        //        .BYT    'e'
        //        .BYT    'r'
        //        .BYT    'f'
        //        .BYT    'l' ;5
        //        .BYT    'o'
        //        .BYT    'w'
        //        .BYT    '!'
        //        .BYT    10  ;9

    }

    void do_MOVI(string[] args)
    {
        debug(log7)stderr.writef("MOVI %s %s <- %s\n", args, q1, q2);
        string tmpR1 = getRegister("tmpR1");
        q1 = load_to_reg(args[0]);
        print_line("SUB", tmpR1, tmpR1, ";MOVI");
        print_line("ADI", tmpR1, args[1], ";MOVI");
        print_line("MOV", q1["R"], tmpR1);
    }

    void do_MOV(string[] args)
    {
        enforce(!args[0].empty && !args[1].empty);
        debug(log7)stderr.writef("MOV %s %s <- %s\n", args, q1, q2);
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[1]);
        print_line("MOV", q1["R"], q2["R"]);
    }
    
    void do_AND(string[] args)
    {
        debug(log7) stderr.writef("AND %s\n", args);
        // IC: AND A, B, C ; A && B  C
        // TC: MOV Rc, Ra
        //     AND Rc, Rb
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[0]);
        print_line("MOV", result_register, q1["R"]);
        print_line("AND", result_register, q2["R"]);
    }
    void do_OR(string[] args)
    {
        debug(log7) stderr.writef("OR %s\n", args);
        // IC: OR  A, B, C ; A || B  C
        // TC: MOV Rc, Ra
        //     OR  Rc, Rb
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[0]);
        print_line("MOV", result_register, q1["R"]);
        print_line("OR", result_register, q2["R"]);
    }
    void do_BF(string[] args)
    {
        debug(log7)stderr.writef("BF %s if(%s == 0) JMP %s\n", args, args[0], args[1]);
        q1 = load_to_reg(args[0]);
        print_line("BRZ", q1["R"], args[1]);
        free_registers(false);
    }
    
    void do_EQ(string[] args)
    {
        debug(log7)stderr.writef("EQ %s %s < %s -> %s\n", args, q1, q2, result_register);
        debug(log8)stderr.writef("EQ %s %s < %s -> %s\n", args, q1["R"], q2["R"], result_register);
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[1]);
        string lhs;
        string rhs;
        //if("RR" in q1)
        //    lhs = q1["RR"];
        //else
            lhs = q1["R"];
        //if("RR" in q2)
        //    rhs = q2["RR"];
        //else
            rhs = q2["R"];
        //IC: EQ  A, B, C ; A < B -> C
        //TC:     MOV Rc, Ra
        //        CMP Rc, Rb
        //        BRZ Rc, L3  ; A < B GOTO L3
        //        MOV Rc, R0  ; Set FALSE
        //        JMP L4
        //    L3: MOV Rc, R1  ; Set TRUE
        //    L4:             ; Next Statement
        string L3 = gen_label("EQ");
        string L4 = gen_label("EQ");
        print_line("MOV", result_register, lhs);
        print_line("CMP", result_register, rhs);
        print_line("BRZ", result_register, L3);
        print_line("SUB", result_register, result_register);
        print_line("JMP", L4, "");
        cur_label = L3;
        print_line("SUB", result_register, result_register);
        print_line("ADI", result_register, "1");
        cur_label = L4;
    }
    
    void do_NE(string[] args)
    {
        debug(log7)stderr.writef("NE %s %s < %s -> %s\n", args, q1, q2, result_register);
        debug(log8)stderr.writef("NE %s %s < %s -> %s\n", args, q1["R"], q2["R"], result_register);
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[1]);
        //IC: NE  A, B, C ; A < B -> C
        //TC:     MOV Rc, Ra
        //        CMP Rc, Rb
        //        BNZ Rc, L3  ; A < B GOTO L3
        //        MOV Rc, R0  ; Set FALSE
        //        JMP L4
        //    L3: MOV Rc, R1  ; Set TRUE
        //    L4:             ; Next Statement
        string L3 = gen_label("NE");
        string L4 = gen_label("NE");
        print_line("MOV", result_register, q1["R"]);
        print_line("CMP", result_register, q2["R"]);
        print_line("BNZ", result_register, L3);
        print_line("SUB", result_register, result_register);
        print_line("JMP", L4, "");
        cur_label = L3;
        print_line("SUB", result_register, result_register);
        print_line("ADI", result_register, "1");
        cur_label = L4;
    }
    
    void do_LT(string[] args)
    {
        debug(log7)stderr.writef("LT %s %s < %s -> %s\n", args, q1, q2, result_register);
        debug(log8)stderr.writef("LT %s %s < %s -> %s\n", args, q1["R"], q2["R"], result_register);
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[1]);
        //IC: LT  A, B, C ; A < B -> C
        //TC:     MOV Rc, Ra
        //        CMP Rc, Rb
        //        BLT Rc, L3  ; A < B GOTO L3
        //        MOV Rc, R0  ; Set FALSE
        //        JMP L4
        //    L3: MOV Rc, R1  ; Set TRUE
        //    L4:             ; Next Statement
        string L3 = gen_label("LT");
        string L4 = gen_label("LT");
        print_line("MOV", result_register, q1["R"], ";Start LT");
        print_line("CMP", result_register, q2["R"]);
        print_line("BLT", result_register, L3);
        print_line("SUB", result_register, result_register);
        print_line("JMP", L4, "");
        cur_label = L3;
        print_line("SUB", result_register, result_register);
        print_line("ADI", result_register, "1");
        cur_label = L4;
    }
    
    void do_GT(string[] args)
    {
        debug(log7)stderr.writef("LT %s %s > %s -> %s\n", args, q1, q2, result_register);
        debug(log8)stderr.writef("LT %s %s > %s -> %s\n", args, q1["R"], q2["R"], result_register);
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[1]);

        //IC:  GT  A, B, C ; A > B  C
        //TC:     MOV Rc, Ra
        //        CMP Rc, Rb
        //        BGT Rc, L3  ; A > B GOTO L3
        //        MOV Rc, R0  ; Set FALSE
        //        JMP L4
        //    L3: MOV Rc, R1  ; Set TRUE
        //    L4:             ; Next Statement
        string L3 = gen_label("GT");
        string L4 = gen_label("GT");
        print_line("MOV", result_register, q1["R"]);
        print_line("CMP", result_register, q2["R"]);
        print_line("BGT", result_register, L3);
        print_line("SUB", result_register, result_register);
        print_line("JMP", L4, "");
        cur_label = L3;
        print_line("SUB", result_register, result_register);
        print_line("ADI", result_register, "1");
        cur_label = L4;
    }
    
    void do_GE(string[] args)
    {
        debug(log7)stderr.writef("LT %s %s > %s -> %s\n", args, q1, q2, result_register);
        debug(log8)stderr.writef("LT %s %s > %s -> %s\n", args, q1["R"], q2["R"], result_register);
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[1]);
        // IC: GE  A, B, C ; A >= B -> C
        // TC:     MOV Rc, Ra  ; Test A > B
        //         CMP Rc, Rb
        //         BGT Rc, L3  ; A > B GOTO L3
        //         MOV Rc, Ra  ; Test A == B
        //         CMP Rc, Rb
        //         BRZ Rc, L3  ; A == B GOTO L3
        //         MOV Rc, R0  ; Set FALSE
        //         JMP L4
        //     L3: MOV Rc, R1  ; Set TRUE
        //     L4:     
        string L3 = gen_label("GE");
        string L4 = gen_label("GE");
        print_line("MOV", result_register, q1["R"]);
        print_line("CMP", result_register, q2["R"]);
        print_line("BGT", result_register, L3);
        print_line("MOV", result_register, q1["R"]);
        print_line("CMP", result_register, q2["R"]);
        print_line("BRZ", result_register, L3);
        print_line("SUB", result_register, result_register);
        print_line("JMP", L4, "");
        cur_label = L3;
        print_line("SUB", result_register, result_register);
        print_line("ADI", result_register, "1");
        cur_label = L4;
    }
    
    void do_LE(string[] args)
    {
        debug(log7)stderr.writef("LT %s %s > %s -> %s\n", args, q1, q2, result_register);
        debug(log8)stderr.writef("LT %s %s > %s -> %s\n", args, q1["R"], q2["R"], result_register);
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[1]);
        // IC: LE  A, B, C ; A <= B -> C
        // TC:     MOV Rc, Ra  ; Test A > B
        //         CMP Rc, Rb
        //         BLT Rc, L3  ; A < B GOTO L3
        //         MOV Rc, Ra  ; Test A == B
        //         CMP Rc, Rb
        //         BRZ Rc, L3  ; A == B GOTO L3
        //         MOV Rc, R0  ; Set FALSE
        //         JMP L4
        //     L3: MOV Rc, R1  ; Set TRUE
        //     L4:     
        string L3 = gen_label("LE");
        string L4 = gen_label("LE");
        print_line("MOV", result_register, q1["R"]);
        print_line("CMP", result_register, q2["R"]);
        print_line("BLT", result_register, L3);
        print_line("MOV", result_register, q1["R"]);
        print_line("CMP", result_register, q2["R"]);
        print_line("BRZ", result_register, L3);
        print_line("SUB", result_register, result_register);
        print_line("JMP", L4, "");
        cur_label = L3;
        print_line("SUB", result_register, result_register);
        print_line("ADI", result_register, "1");
        cur_label = L4;
    }
    
    void do_WRITE(string[] args)
    {
        debug(log7)stderr.writef("WRITE %s\n", args);
        enforce(!args[0].empty);
        q1 = load_to_reg(args[0]);
        string src;
        string type = symbols.get(args[0]).data["Type"];
        //if(args[0][0] == '*')
        //    src = q1["RR"];
        //else
            src = q1["R"];
        print_line("MOV", "R0", src);
        if(type == "char")
        {
            print_line("TRP", "3", "");
        }
        else if (type == "int")
        {
            print_line("TRP", "1", "");
        }
        else
        {
            print_line("TRP", "1", "");
            //enforce(false, "Unprintable type: [" ~ type ~ "," ~ args[0]);
        }
        free_registers(false);
    }

    void do_READ(string[] args)
    {
        debug(log7)stderr.writef("READ %s\n", args);
        enforce(!args[0].empty);
        q1 = load_to_reg(args[0]);
        string dest;
        string type = symbols.get(args[0]).data["Type"];
        //if(args[0][0] == '*')
        //    dest = q1["RR"];
        //else
            dest = q1["R"];
        if(type == "char")
        {
            print_line("TRP", "4", "");
        }
        else if (type == "int")
        {
            print_line("TRP", "2", "");
        }
        else
        {
            enforce(false, "Unreadable type: " ~ type ~ "," ~ args[0]);
        }
        print_line("MOV", dest, "R0");
    }
    
    void do_JMP(string[] args)
    {
        debug(log7)stderr.writef("JMP %s\n", args);
        print_line("JMP", args[0], "");
    }
    
    void do_RTN(string[] args)
    {
        debug(log7)stderr.writef("RTN %s\n", args);
        free_registers();
        string tmpR1 = getRegister("tmp1");
        string tmpR2 = getRegister("tmp2");
        string tmpR3 = getRegister("tmp3");
        print_line("MOV", "SP", FP, ";De-allocate Frame");
        print_line("ADI", "SP", "4", ";De-allocate FP");
        print_line("LDR", tmpR1, FP, ";Keep a copy of FP to jump to");
        print_line("MOV", tmpR2, FP, ";Grab another copy of FP");
        print_line("ADI", tmpR2, "-4", ";Move the pointer to PFP");
            print_line("ADI", tmpR2, "-4", ";Store Return value");
            print_line("LDR", tmpR3, tmpR2, ";Store Return value");
            print_line("STR", tmpR3, FP, ";Store Return value");
            print_line("ADI", tmpR2, "+4", ";Store Return value");
        free_registers(false);
        print_line("LDR", FP, tmpR2, ";Store PFP in FP");
        print_line("JMR", tmpR1, "", ";Return");
    }

    void do_RETURN(string[] args)
    {
        debug(log7)stderr.writef("RETURN %s\n", args);
        free_registers();
        q1 = load_to_reg(args[0]);
        string tmpR1 = getRegister("tmp1");
        string tmpR2 = getRegister("tmp2");
        print_line("MOV", "SP", FP, ";De-allocate Frame");
        print_line("ADI", "SP", "4", ";De-allocate FP");
        print_line("LDR", tmpR1, FP, ";Keep a copy of FP to jump to");
        print_line("MOV", tmpR2, FP, ";Grab another copy of FP");
        print_line("ADI", tmpR2, "-4", ";Move the pointer to PFP");
        string type = symbols.get(args[0]).data["Type"];
        if(type == "char" || type == "bool" || type == "null")
        {
            print_line("STB", q1["R"], FP, ";Store Return value");
        }
        else
        {
            print_line("STR", q1["R"], FP, ";Store Return value");
        }
        free_registers(false);
        print_line("LDR", FP, tmpR2, ";Store PFP in FP");
        print_line("JMR", tmpR1, "", ";Return");
    }

    void do_PUSH(string[] args)
    {
        debug(log7) stderr.writef("PUSH %s\n", args);
        q1 = load_to_reg(args[0]);
        string src;
        //if("RR" in q1)
        //    src = q1["RR"];
        //else
            src = q1["R"];
        //enforce(false, "Unimplemented PUSH");
        // IC: PUSH A       ; Push A on Stack
        // TC: STR Ra, (SP) ; Push A on Stack; A in Ra
        //     ADI SP, #-4  ; Modify Stack Pointer
        print_line("ADI", "SP", "-4");
        print_line("STR", src, "SP");
        free_registers(false);
    }

    void do_POP(string[] args)
    {
        debug(log7) stderr.writef("POP %s\n", args);
        enforce(false, "Unimplemented POP");
        q1 = load_to_reg(args[0]);
        // IC: POP A        ; Pop the top of the Stack into A
        // TC: ADI SP, #4   ; Modify Stack Pointer
        //     LDR Ra, (SP) ; Pop the Stack
        print_line("ADI", "SP", "+4");
        print_line("LDR", q1["R"], "SP");
    }

    void do_PEEK(string[] args)
    {
        debug(log7) stderr.writef("PEEK %s\n", args);
        q1 = load_to_reg(args[0]);
        string tmpR1 = getRegister("tmp1");
        //          MOV     tmpR1,     SP      ;Get Stack Pointer, should be 4 away from the retval of FACT
        print_line("MOV", tmpR1, "SP");
        //          ADI     tmpR1,     -4      ;Adjust to be pointing at the Return Value (I'm expecting an INT)
        print_line("ADI", tmpR1, "-4");
        string type = symbols.get(args[0]).data["Type"];
        if(type == "char" || type == "bool" || type == "null")
        {
            // LDR     R2,     tmpR1      ;R[2] = return value of FACT
            print_line("LDB", q1["R"], tmpR1);
        }
        else
        {
            // LDB     R2,     tmpR1      ;R[2] = return value of FACT
            print_line("LDR", q1["R"], tmpR1);
        }
    }
    
    void do_CALL(string[] args)
    {
        debug(log7) stderr.writef("CALL %s\n", args);
        FP = "FP";
        //        ADI     SP,     symbol.data["Size"]
        print_line("ADI", "SP", format("-%s", symbols.size_of(args[0])), format(";Func %s", symbols.get(args[0]).info["Value"]));
        //        MOV     R1,     PC      ;PC incremented by 1 instruction
        print_line("MOV", "R1", "PC", ";CALL : PC incremented by 1 instruction");
        //        ADI     R1,     32      ;Compute Return Address (always a fixed amount)
        print_line("ADI", "R1", "32", ";Compute Return Address (always a fixed amount)");
        //        STR     R1,     FP      ;Return Address to the Beginning of the Frame
        print_line("STR", "R1", FP, ";Return Address to the Beginning of the Frame");
        //        JMP     MAIN            ;Call Function MAIN
        print_line("JMP", args[0], "", ";Call Function");
        //EOP     TRP     0
    }
    
    void do_EOP(string[] args)
    {
        debug(log7) stderr.writef("EOP %s\n", args);
        print_line("TRP", "0", "");
    }

    void do_NOP(string[] args)
    {
        debug(log7) stderr.writef("NOP %s\n", args);
        print_line("SUB", "R0", "R0");
    }
    
    void do_ADD(string[] args)
    {
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[1]);
        debug(log7)stderr.writef("ADD %s %s + %s -> %s\n", args, q1, q2, result_register);
        debug(log8)stderr.writef("ADD %s %s + %s -> %s\n", args, q1["R"], q2["R"], result_register);
        print_line("MOV", result_register, q1["R"]);
        print_line("ADD", result_register, q2["R"]);
    }
    
    void do_SUB(string[] args)
    {
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[1]);
        debug(log7)stderr.writef("SUB %s %s + %s -> %s\n", args, q1, q2, result_register);
        debug(log8)stderr.writef("SUB %s %s + %s -> %s\n", args, q1["R"], q2["R"], result_register);
        print_line("MOV", result_register, q1["R"]);
        print_line("SUB", result_register, q2["R"]);
    }
    
    void do_MUL(string[] args)
    {
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[1]);
        debug(log7)stderr.writef("MUL %s %s + %s -> %s\n", args, q1, q2, result_register);
        debug(log8)stderr.writef("MUL %s %s + %s -> %s\n", args, q1["R"], q2["R"], result_register);
        print_line("MOV", result_register, q1["R"]);
        print_line("MUL", result_register, q2["R"]);
    }
    
    void do_DIV(string[] args)
    {
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[1]);
        debug(log7)stderr.writef("DIV %s %s + %s -> %s\n", args, q1, q2, result_register);
        debug(log8)stderr.writef("DIV %s %s + %s -> %s\n", args, q1["R"], q2["R"], result_register);
        print_line("MOV", result_register, q1["R"]);
        print_line("DIV", result_register, q2["R"]);
    }
    
    void do_NEW(string[] args)
    {
        q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[1]);
        debug(log7)stderr.writef("NEW %s %s + %s -> %s\n", args, q1, q2, result_register);
        //stderr.writef("%s%s\n", symbols.symIDsymbols[args[0]], symbols.symIDsymbols[args[1]]);
        // IC:  NEW B, A    ; Allocate the number of bytes in
        //                  ; variable B on the heap and
        //                  ; place the starting address in A
        // TC:  LDR Rc, FREE (I already have SL loaded)
        //      MOV Ra, Rc
        print_line("MOV", q2["R"], "SL", ";Store Heap pointer");
        //      ADD Rc, Rb  ; Inc free heap by Rb bytes
        //      STR Rc, FREE
        print_line("ADD", "SL", q1["R"], ";Allocate Heap Space");
    }

    void do_NEWI(string[] args)
    {
        //q1 = load_to_reg(args[0]);
        q2 = load_to_reg(args[1]);
        debug(log7)stderr.writef("NEWI %s %s -> %s\n", args, args[0], q2);
        //stderr.writef("%s%s\n", symbols.symIDsymbols[args[0]], symbols.symIDsymbols[args[1]]);
        // IC: NEWI #, A        ; Allocate # bytes on the heap and 
        //                      ; place the starting address in A
        // TC: LDR Rc, FREE     ; Load address of free heap
        //     MOV Ra, Rc       ; Save address in register Ra
        print_line("MOV", q2["R"], "SL", ";Store Heap pointer");
        //     ADI Rc, #        ; Inc free heap by # bytes
        //     STR Rc, FREE     ; Update FREE
        print_line("ADI", "SL", args[0], ";Allocate Heap Pointer Space");
        //enforce(false);
    }
    void do_REF(string[] args)
    {
        debug(log7)stderr.writef("REF %s\n", args);
        q1 = load_to_reg(args[0]);
        //q2 = load_to_reg(args[1]);
        // IC: REF A, B, C ; Using A as a Base Address add to
        //                 ; it the offset to B and assign
        //                 ; the address to C. 
        // TC: MOV Rc, Ra
        //     ADD Rc, Rb
        string[string] loc1 = getLocation(args[1]);
        print_line("MOV", result_register, q1["R"], format(";REF %s", args));
        print_line("ADI", result_register, loc1["H"]);
        //stderr.writef("REF: %s\n", symbols.get(args[2]));
        //enforce(false);
    }
    
}

class Compiler 
{
private:
    Tokenizer tokenizer;
    this() {}
    string[] _scope;
    SymbolTable symbols;
    Symbol current_symbol;
    Symbol last_method_symbol;
    SemanticAction SA;
    int errors;
    int[string] label_count;

    Icode icode;
    class Icode
    {
        string[4][] data;
        string[size_t] labels;

        void add(string[4] new_data, int line = __LINE__)
        {
            debug(log5){ 
                string[] print_data = [new_data[0]];
                foreach(symid; new_data[1..$])
                {
                    if(!symid.empty)
                    {
                        if(Symbol symbol = symbols.get(symid))
                        {
                            print_data ~= symbol.info["Value"];
                        }
                        else if(Symbol symbol = symbols.get(symid[1..$]))
                        {
                            enforce(symid[0] == '*');
                            print_data ~= "*" ~ symbol.info["Value"];
                            enforce(false, "I think this isn't used anymore.");
                        }
                        else if(symid == "")
                        {
                            print_data ~= "";
                        }
                        else
                        {
                            print_data ~= "*" ~ symid ~ "*";
                        }
                    }
                }
                debug(Tokenizer)
                {
                    stderr.writef("%-5s:[%5d][%5d] %s\n", "", line, data.length, print_data);
                }
                else
                {
                    stderr.writef("%-5d:[%5d][%5d] %s\n", tokenizer.ct.line, line, data.length, print_data);
                }
            }
            data ~= new_data;
        }

        void set_label(string new_label, int line = __LINE__)
        {
            debug(log5)
            {
                stderr.writef("%-5s:[%5d] Adding label [%5d:%s]\n", "", line, data.length, new_label);
            }
            if(labels.get(data.length, null) is null)
            {
                labels[data.length] = new_label;
            }
            else
            {
                debug(log5) stderr.writef("Backpatching %s -> %s\n", labels[data.length], new_label);
                add(["NOP", "", "", ""]);
                //foreach(r; 0..data.length)
                //{
                //    foreach(c; 1..4)
                //    {
                //        if(data[r][c] == labels[data.length])
                //        {
                //            data[r][c] = new_label;
                //        }
                //    }
                //}
                labels[data.length] = new_label;
            }
        }

        string gen_label(string new_label)
        {
            label_count[new_label] = label_count.get(new_label, 0) + 1;
            return format("%s%d", new_label, label_count[new_label]);
        }

        void output(File outfile)
        {
            foreach(i, l; data)
            {
                outfile.writef("%-15s %s\n", labels.get(i, ""), l);
            }
        }
    }


    class SemanticAction
    {
    private:
        void delegate()[string] operations;
        size_t[string] op_precedence;
    public:
        this() 
        {
            op_precedence["^"]  = 5;
            op_precedence["*"]  = 4;
            op_precedence["/"]  = 4;
            op_precedence["+"]  = 3;
            op_precedence["-"]  = 3;
            op_precedence["<="] = 2;
            op_precedence[">="] = 2;
            op_precedence["<"]  = 2;
            op_precedence[">"]  = 2;
            op_precedence["=="] = 2;
            op_precedence["!="] = 2;
            op_precedence["||"] = 1;
            op_precedence["&&"] = 1;
            op_precedence["="]  = 0;
            operations["*"]     = &_op_mult;
            operations["/"]     = &_op_div;
            operations["+"]     = &_op_add;
            operations["-"]     = &_op_sub;
            operations["="]     = &_op_assign;
            operations["<="]    = &_op_le;
            operations[">="]    = &_op_ge;
            operations["<"]     = &_op_lt;
            operations[">"]     = &_op_gt;
            operations["=="]    = &_op_eq;
            operations["!="]    = &_op_ne;
            operations["&&"]    = &_op_and;
            operations["||"]    = &_op_or;
        }

        string ref_check(string Symid)
        {
            Symbol symbol = symbols.get(Symid);
            //stderr.writef("ref_check: %s\n", symbol);
            if(symbol !is null)
            {
                if(symbol.data.get("Ref", null) !is null)
                {
                    Symid = "*" ~ Symid;
                }
            }
            //stderr.writef("ref_check: returning %s\n", Symid);
            return Symid;
        }
    
        // tExist: pop identifier
        void tExist()
        {
            string func = "tExist";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            if(type_sar top_sar = SAS.top!(type_sar)())
            {
                SAS.pop();
                debug(log3) stderr.writef("  *  tExist checking if [%s] is a type or class_name\n", top_sar.identifier);
                if(!tokenizer.is_type(top_sar.identifier) && !tokenizer.is_class(top_sar.identifier))
                {
                    gen_error("tExist", format("Type [%s] does not exist.", top_sar.identifier));
                }
            }
            else
                gen_error("tExist", "Expected type_sar, but didn't get one.");
        }
    
        // TODO: Verify that the cases below are comprehensive
        // rExist: pop identifier && pop type/class, push existing member reference with type (string + bool + string)
        void rExist()
        {
            string func = "rExist";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            // 
            basic_sar member_sar  = SAS.top!(basic_sar)();
            SAS.pop();
            //enforce(member_sar !is null, "member sar is null");
            var_sar reference_sar = SAS.top!(var_sar)();
            SAS.pop();
            //enforce(reference_sar !is null, "reference sar is null");

            Symbol reference_symbol;
            Symbol member_symbol;

            // TODO: Make this nicer
            enforce(reference_sar !is null, "Ref sar is null");
            // Test left hand of the dot and make sure it's something that can be referenced with the "." operator
            // Since the only time we push a ref_sar onto the stack is at the end of rExist, the member reference will never be a ref_sar
            if(ref_sar test_sar = cast(ref_sar)reference_sar)
            {
                debug(log4) stderr.writef("rExist called and got a ref_sar: [%s %s]\n", test_sar.type, test_sar.identifier);
                reference_symbol = symbols.get(test_sar.Symid);
            }
            else if(func_sar test_sar = cast(func_sar)reference_sar)
            {
                debug(log4) stderr.writef("rExist called and got a func_sar: [%s %s]\n", test_sar.type, test_sar.identifier);
                reference_symbol = symbols.get(test_sar.Symid);
            }
            else if(arr_sar test_sar = cast(arr_sar)reference_sar)
            {
                debug(log4) stderr.writef("rExist called and got a arr_sar: [%s]\n", test_sar.identifier);
                reference_symbol = symbols.get(test_sar.Symid);
            }
            else if(var_sar test_sar = cast(var_sar)reference_sar)
            {
                debug(log4) stderr.writef("rExist called and got a var_sar: [%s %s]\n", test_sar.type, test_sar.identifier);
                reference_symbol = symbols.get(test_sar.Symid);
            }
            else
            {
                gen_error(func, format("Expected var_sar, arr_sar, func_sar, or ref_sar for [%s], but didn't get one", reference_sar.identifier));
            }

            // Make sure that the ref_sar has a symbol
            if(reference_symbol is null)
            {
                gen_error(func,format("Undefined reference for %s[%s %s]", reference_sar.Symid, reference_sar.type, reference_sar.identifier));
                return;
            }
            debug(log4) stderr.writef("Looking for %s in %s\n", member_sar.identifier, format("%s.%s", _scope[0..$-1].join("."), reference_symbol.data.get("Type", "")));

            // Test right hand of the dot
            // var_sar and arr_sar should already know their types, but func_sar needs to look it up in the symbol table
            if(func_sar test_sar = cast(func_sar)member_sar)
            {
                member_symbol = symbols.find(member_sar.identifier, format("g.%s", reference_symbol.data.get("Type", "")));
                debug(log4) stderr.writef("rExist called and got a func_sar [%s %s]\n", test_sar.type, test_sar.identifier);
                // Update the func_sar to have the rest of the information.
                if(member_symbol !is null)
                {
                    test_sar.type = member_symbol.data.get("returnType", "UNKNOWN type");
                    test_sar.Symid = member_symbol.info.get("Symid", "UNKNOWN Symid");
                    string[] param_Symids;
                    enforce(!SAS.empty, "Func is a reference, but SAS is empty!");
                    debug(log4) stderr.writef("Need to get the reference from the stack, then resolve to get function signature.");
                    debug(log4) stderr.writef("%s\n", test_sar.identifier);
                    debug(log4) stderr.writef("%s\n", which_sar(SAS.top!(id_sar)));
                    //var_sar ref_sar = SAS.top!(var_sar);
                    debug(log4) stderr.writef("Got reference symbol: %s\n", reference_symbol);
                    debug(log4) stderr.writef("Need to get signature for %s.%s.%s\n", "g", reference_symbol.data["Type"], test_sar.identifier);
                    debug(log4) stderr.writef("Got func symbol: %s\n", symbols.find(test_sar.identifier, format("%s.%s", "g", reference_symbol.data["Type"])));
                    debug(log4) stderr.writef("Got func params: %s\n", std.string.split(symbols.find(test_sar.identifier, format("%s.%s", "g", reference_symbol.data["Type"])).data.get("Param", ""), "|"));
                    param_Symids = std.string.split(symbols.find(test_sar.identifier, format("%s.%s", "g", reference_symbol.data["Type"])).data.get("Param", ""), "|");
                    //Duplicate this to else 
                    //enforce(param_Symids.length == test_sar.args.list.length, "Argument list lengths are wrong");
                    if(param_Symids.length != test_sar.args.list.length)
                    {
                        gen_error(func, format("Argument list lengths don't match: Expected %d, got %d", param_Symids.length, test_sar.args.list.length));
                        enforce(false, "Continuing from this point is pointless");
                    }
                    debug(log4) stderr.writef("Need to compare these:\n");
                    foreach(i; 0..test_sar.args.list.length)
                    {
                        debug(log4) stderr.writef("%s == %s\n", symbols.get(test_sar.args.list[i].Symid).data["Type"], symbols.get(param_Symids[i]).data["Type"]);
                        if(symbols.get(test_sar.args.list[i].Symid).data["Type"] != symbols.get(param_Symids[i]).data["Type"])
                        {
                            gen_error(func, format("Type mismatch in function signature: Got type \"%s\" in the call when function declaration is expecting a \"%s\"", symbols.get(test_sar.args.list[i].Symid).data["Type"], symbols.get(param_Symids[i]).data["Type"]));
                        }
                        //enforce(symbols.get(test_sar.args.list[i].Symid).data["Type"] == symbols.get(param_Symids[i]).data["Type"], "Type mismatch in function signature");
                    }
                    debug(log4) stderr.writef("\n");
                    member_sar = test_sar;
                }
                else
                {
                    var_sar test2_sar = cast(var_sar)(reference_sar);
                    gen_error(func, format("No reference for function member [%s %s].[%s] %s", test2_sar.type, reference_sar.identifier, test_sar.identifier, member_symbol));
                }
            }
            else if(arr_sar test_sar = cast(arr_sar)member_sar)
            {
                debug(log4) stderr.writef("rExist called and got a arr_sar\n");
                member_symbol = symbols.get(test_sar.Symid);
            }
            else if(var_sar test_sar = cast(var_sar)member_sar)
            {
                debug(log4) stderr.writef("rExist called and got a var_sar: [%s %s]\n", test_sar.type, test_sar.identifier);
                member_symbol = symbols.get(test_sar.Symid);
            }
            // TODO: Find a way to make sure we can do var_sar for everything
            else if(id_sar test_sar = cast(id_sar)member_sar)
            {
                debug(log4) stderr.writef("rExist called and got a id_sar\n");
                // Update the id_sar to a var_sar
                member_symbol = symbols.find(member_sar.identifier, format("g.%s", reference_symbol.data.get("Type", "")));
                if(member_symbol !is null)
                {
                    debug(log4) stderr.writef("Need to upgrade id_sar [%s] to a var_sar: %s\n", member_sar.identifier, member_symbol);
                    member_sar = new var_sar(test_sar, member_symbol.data.get("Type", "UNKNOWN type"), member_symbol.info.get("Symid", "UNKNOWN Symid"));
                }
                else
                {
                    gen_error(func, format("No reference for identifier member [%s].[%s]", reference_sar.identifier, test_sar.identifier));
                }
            }
            else
            {
                gen_error(func, format("Expected var_sar, arr_sar, or func_sar for [%s].[%s], but didn't get one. Might be a [%s]", reference_sar.identifier, member_sar.identifier, which_sar(member_sar)));
            }

            debug(log4) stderr.writef("rExist: [%d] Finished, and wound up with %s[%s].%s[%s]\n", tokenizer.ct.line, reference_sar.identifier, which_sar(reference_sar), member_sar.identifier, which_sar(member_sar));

            // If member_sar exists as a public member of the type of the reference_sar, push onto the stack
            // Else error
            if(member_symbol !is null)
            {
                if(member_symbol.data.get("accessMod", "") == "public" || (member_symbol.data.get("accessMod", "") == "private" && member_symbol.info["Scope"] == _scope[0..$-1].join(".")))
                {
                    // If it's a func_sar, we need to frame and call the function
                    // else treat it just like any other variable
                    if(func_sar test_sar = cast(func_sar)(member_sar))
                    {
                        Symbol return_value_symbol = symbols.gen_tmp(_scope, test_sar.type);
                        Symbol func_symbol = symbols.symIDsymbols[test_sar.Symid];
                        //debug(log6) stderr.writef("Looking for size of %s[%d]\n", test_sar.Symid, symbols.size_of(test_sar.Symid));
                        //func_symbol.data["Size"] = format("%s", symbols.size_of(test_sar.Symid));
                        icode.add(["FRAME", test_sar.Symid, reference_sar.Symid, ""]);
                        foreach(l; test_sar.args.list)
                        {
                            icode.add(["PUSH", ref_check(l.Symid), "", ""]);
                        }
                        icode.add(["CALL", test_sar.Symid, "", ""]);
                        icode.add(["PEEK", return_value_symbol.info["Symid"], "", ""]);

                        SAS.push(new var_sar(
                            return_value_symbol.info["Value"],
                            return_value_symbol.data["Type"],
                            return_value_symbol.info["Symid"]));
                    }
                    else if(var_sar test_sar = cast(var_sar)(member_sar))
                    {
                        Symbol ref_symbol = symbols.gen_tmp(_scope, test_sar.type);
                        ref_symbol.data["Ref"] = test_sar.type;
                        icode.add(["REF", reference_sar.Symid, test_sar.Symid, ref_symbol.info["Symid"]]);
                        //stderr.writef("%s\n", ref_symbol);
                        //SAS.push(new ref_sar(cast(var_sar)reference_sar, cast(var_sar)member_sar));
                        SAS.push(new ref_sar(ref_symbol.info["Value"], ref_symbol.data["Type"], ref_symbol.info["Symid"]));
                    }
                }
                else
                {
                    gen_error(func, format("Attempted public access to private variable %s [%s.%s]", member_symbol, reference_sar.identifier, member_sar.identifier));
                }
            }
            else
            {
                gen_error(func, "Couldn't find symbol for RHS of .");
            }
        }
    
        // iExist: pop identifier, push variable
        void iExist()
        {
            string func = "iExist";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            basic_sar top_sar = SAS.top!(basic_sar)();
            SAS.pop();
            if(func_sar test_sar = cast(func_sar)top_sar)
            {
                // TODO: Do something
                debug(log4) stderr.writef("iExist called and got a func_sar [%s]. Stuffing it back onto the SAS as is\n", test_sar.identifier);
                Symbol func_symbol = symbols.find(test_sar.identifier, _scope);
                if(func_symbol is null)
                    gen_error(func, format("Unknown function [%s.%s]\n", _scope.join("."), test_sar.identifier));
                test_sar.type = func_symbol.data.get("Type", "UNKNOWN type");
                test_sar.Symid = func_symbol.info.get("Symid", "UNKNOWN Symid");
                string[] param_Symids;
                debug(log4) stderr.writef("Need to use the scope to find the function signature: ");
                debug(log4) stderr.writef("%s.%s\n", _scope.join("."), test_sar.identifier);
                debug(log4) stderr.writef("Got func symbol: %s\n", symbols.find(test_sar.identifier, _scope));
                debug(log4) stderr.writef("Got func params: %s\n", std.string.split(symbols.find(test_sar.identifier, _scope).data.get("Param", ""), "|"));
                param_Symids = std.string.split(symbols.find(test_sar.identifier, _scope).data.get("Param", ""), "|");
                //enforce(param_Symids.length == args.list.length, "Argument list lengths are wrong");
                if(param_Symids.length != test_sar.args.list.length)
                {
                    gen_error(func, format("Argument list lengths don't match: Expected %d, got %d", param_Symids.length, test_sar.args.list.length));
                    enforce(false, "Continuing from this point is pointless");
                }
                debug(log4) stderr.writef("Need to compare these:\n");
                foreach(i; 0..test_sar.args.list.length)
                {
                    debug(log4) stderr.writef("%s == %s\n", symbols.get(test_sar.args.list[i].Symid).data["Type"], symbols.get(param_Symids[i]).data["Type"]);
                    if(symbols.get(test_sar.args.list[i].Symid).data["Type"] != symbols.get(param_Symids[i]).data["Type"])
                    {
                        gen_error(func, format("Type mismatch in function signature: Got type \"%s\" in the call when function declaration is expecting a \"%s\"", symbols.get(test_sar.args.list[i].Symid).data["Type"], symbols.get(param_Symids[i]).data["Type"]));
                    }
                    //enforce(symbols.get(test_sar.args.list[i].Symid).data["Type"] == symbols.get(param_Symids[i]).data["Type"], "Type mismatch in function signature");
                }
                debug(log4) stderr.writef("\n");
                Symbol return_value_symbol = symbols.gen_tmp(_scope, test_sar.type);
                //stderr.writef("Looking for size of %s[%d]\n", test_sar.Symid, symbols.size_of(test_sar.Symid));
                icode.add(["FRAME", test_sar.Symid, "this", ""]);
                foreach(l; test_sar.args.list)
                {
                    icode.add(["PUSH", ref_check(l.Symid), "", ""]);
                }
                icode.add(["CALL", test_sar.Symid, "", ""]);
                icode.add(["PEEK", return_value_symbol.info["Symid"], "", ""]);
                SAS.push(new var_sar(return_value_symbol.info["Value"], return_value_symbol.data["Type"], return_value_symbol.info["Symid"]));
            }
            else if(arr_sar test_sar = cast(arr_sar)top_sar)
            {
                // TODO: Verify that the index is an "int". Probably doesn't need to be done here.
                debug(log4) stderr.writef("iExist called and got a arr_sar [%s[%s]]. Stuffing it back onto the SAS as is\n", test_sar.identifier, test_sar.index.identifier);
                Symbol offset_symbol = symbols.gen_tmp(_scope, "int");
                Symbol new_symbol = symbols.gen_tmp(_scope, test_sar.type[1..$]);
                new_symbol.data["Ref"] = test_sar.type[1..$];
                //new_symbol.set_info(["Reference":test_sar.type]);
                //stderr.writef("[%d] Created new temp variable: %s %s\n", tokenizer.ct.line, offset_symbol.data["Type"], offset_symbol.info["Value"]);
                //stderr.writef("[%d] Created new temp variable: %s %s\n", tokenizer.ct.line, new_symbol.data["Type"], new_symbol.info["Value"]);
                //icode.add(["MUL", test_sar.index.Symid, "GETSIZE", offset_symbol.info["Symid"]]);
                Symbol size_symbol = symbols.add_global("int", format("GI+%d", symbols.size_of(test_sar.Symid)));
                icode.add(["MUL", test_sar.index.Symid, size_symbol.info["Symid"], offset_symbol.info["Symid"]]);
                icode.add(["ADD", test_sar.Symid, offset_symbol.info["Symid"], new_symbol.info["Symid"]]);
                //stderr.writef("Pushing a var_sar onto the stack: %s, %s, %s, %s\n", new_symbol, new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]);
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
            }
            else if(id_sar test_sar = cast(id_sar)top_sar)
            {
                debug(log4) stderr.writef("iExist called and got a id_sar [%s]\n", test_sar.identifier);
                Symbol existing_symbol = symbols.find(test_sar.identifier, _scope);
                if(existing_symbol !is null)
                {
                    debug(log2) log(func, format("Correct Reference for variable [%s %s] in the scope [%s] on line [%d]", existing_symbol.data.get("Type", ""), test_sar.identifier, _scope.join("."), tokenizer.ct.line));
                    SAS.push(new var_sar(test_sar, existing_symbol.data.get("Type", "UNKNOWN TYPE"), existing_symbol.info.get("Symid", "UNKNOWN Symid")));
                }
                else
                {
                    gen_error(func, format("Reference before declaration for variable [%s] in the scope [%s] on line [%d]", test_sar.identifier, _scope.join("."), tokenizer.ct.line));
                }
            }
            else
            {
                gen_error("iExist", format("Expected id_sar, func_sar, or arr_sar, but got something else [%s]\n", top_sar.identifier));
            }

        }
    
        // tPush: push type (string)
        void tPush()
        {
            string func = "tPush";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            SAS.push(new type_sar(tokenizer.ct.lexeme));
        }
    
        // iPush: push identifier (string)
        void iPush()
        {
            string func = "iPush";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            SAS.push(new id_sar(tokenizer.ct.lexeme));
        }
    
        // lPush: push literal (string)
        void lPush(string sign = "+")
        {
            // I should be creating var_sar here and pushing that on
            string func = "lPush";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            Symbol new_symbol = new Symbol();
            // TODO numeric_literal fix
            if(check_token("number"))
            {
                new_symbol = symbols.add_global("int", "GI" ~ sign ~ tokenizer.ct.lexeme);
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
            }
            else if(check_token("character_literal"))
            {
                new_symbol = symbols.add_global("char", "GC" ~ tokenizer.ct.lexeme);
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
            }
            else if(check_token("keyword", ["true", "false"]))
            {
                new_symbol = symbols.add_global("bool", "GB" ~ tokenizer.ct.lexeme);
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
            }
            else if(check_token("keyword", "null"))
            {
                new_symbol = symbols.add_global("null", "GN" ~ tokenizer.ct.lexeme);
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
            }
            else
            {
                gen_error(func, format("Unknown literal [%s]", tokenizer.ct));
            }
        }
    
        // This one is a big tricky. We need to be able to go back a few tokens to find out what it is
        // Consider:
        //   Cat x;
        //   Cat y = new Cat();
        //   Cat z[] = new Cat[r];
        // In these cases, variables are being defined at the same time they are being declared, but we don't call vPush until ';' or '=' is the current token.
        // As of now, pass2 continues to create new symbols just like pass1, but only pass1 adds them to the symbol table.
        // This is being leveraged to retrieve information about the varible that was just defined. Specifically the name of the symbol so we can retrieve the symbol from pass1
        // vPush: push variable (string + bool)
        void vPush()
        {
            string func = "vPush";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            Symbol existing_symbol = symbols.find(current_symbol.info["Value"], _scope);
            if(existing_symbol !is null && existing_symbol.info.get("Symid","") != "")
            {
                debug(log3) stderr.writef("Added variable with symbol:[%s] %s\n", existing_symbol.info.get("Symid",""), existing_symbol);
                //stderr.writef("new var_sar(%s, %s, %s)\n", existing_symbol.info["Value"], existing_symbol.data["Type"], existing_symbol.info["Symid"]);
                SAS.push(new var_sar(existing_symbol.info["Value"], existing_symbol.data["Type"], existing_symbol.info["Symid"]));
            }
            else
            {
                gen_error(func, format("Couldn't find Symid for [%s]", current_symbol));
            }
        }
    
        // oPush: push operator (string)
        void oPush()
        {
            string func = "oPush";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            string operator;
            void delegate() operation;
            while(!OS.empty() && (tokenizer.ct.lexeme != "(" && op_precedence.get(tokenizer.ct.lexeme, 0) < op_precedence.get(OS.top(), 0))) 
            {
                operator = OS.pop();
                debug(log4) stderr.writef("oPush: OS.pop resulted in [%s]\n", operator);
                operation = operations.get(operator, null);
                if(operation !is null)
                    operation();
                else
                    gen_error(func, format("Unimplemented operator [%s]", operator));
            }
            OS.push(tokenizer.ct.lexeme);
        }
    
        // CD:
        void CD()
        {
            string func = "CD";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            if(_scope[$-1] != tokenizer.ct.lexeme)
                gen_error(func, format("Expected Declaration for Class [%s], and got one for [%s]\n", _scope[$-1], tokenizer.ct.lexeme));
        }
    
        void EOE()
        {
            string func = "EOE";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            string operator;
            void delegate() operation;

            while(!OS.empty)
            {
                operator = OS.pop();
                debug(log4) stderr.writef("EOE: OS.pop resulted in [%s]\n", operator);
                operation = operations.get(operator, null);
                if(operation !is null)
                    operation();
                else
                    gen_error(func, format("Unimplemented operator [%s]", operator));
            }
        }
    
        // TODO: Verify that we'll never use this
        void oParen()
        {
            string func = "oParen";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
        }

        void cParen()
        {
            string func = "cParen";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            while(OS.top() != "(")
            {
                string operator = OS.pop();
                debug(log3) stderr.writef("cParen: Running operation %s\n", operator);
                void delegate() operation = operations.get(operator, null);
                if(operation !is null)
                    operation();
                else
                    gen_error(func, format("Unimplemented operator [%s]", operator));
            }
            string operator = OS.pop();
            assert(operator == "(");
            debug(log4) stderr.writef("Done popping from OS\n");
        }

        // TODO: Verify that we'll never use this
        void oBrack()
        {
            string func = "oBrack";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
        }

        void cBrack()
        {
            string func = "cBrack";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            while(OS.top() != "[")
            {
                string operator = OS.pop();
                debug(log3) stderr.writef("cBrack: Running operation %s\n", operator);
                void delegate() operation = operations.get(operator, null);
                if(operation !is null)
                    operation();
                else
                    gen_error(func, format("Unimplemented operator [%s]", operator));
            }
            string operator = OS.pop();
            assert(operator == "[");
            debug(log4) stderr.writef("cBrack: Done popping from OS\n");
        }

        // TODO: Verify that this works right
        void comma()
        {
            string func = "comma";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            while(OS.top() != "(")
            {
                string operator = OS.pop();
                debug(log3) stderr.writef("comma: Running operation %s\n", operator);
                void delegate() operation = operations.get(operator, null);
                if(operation !is null)
                    operation();
                else
                    gen_error(func, format("Unimplemented operator [%s]", operator));
            }
        }

        // if: pop expression
        void _if(string label = "DEFAULTIF")
        {
            string func = "_if";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            if(var_sar test_val = SAS.top!(var_sar)())
            {
                if(test_val.type != "bool")
                {
                    gen_error(func, format("Expression does not result in a bool. [%s]", test_val.type));
                    return;
                }
                icode.add(["BF", test_val.Symid, label, ""]);
            }
            else
            {
                gen_error(func, "Expected a var_sar, but got something else");
            }
            SAS.pop();
        }

        // while: pop expression
        void _while(string label = "DEFAULTWHILE")
        {
            string func = "_while";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            if(var_sar test_val = SAS.top!(var_sar)())
            {
                if(test_val.type != "bool")
                {
                    gen_error(func, format("Expression does not result in a boolean. [%s]", test_val.type));
                    return;
                }
                icode.add(["BF", test_val.Symid, label, ""]);
            }
            else
                gen_error(func, "Expected a var_sar, but got something else");
            SAS.pop();
        }

        // TODO: Need to fix the _return to push a var_sar onto the stack -- I don't think I need this
        // TODO: Need to disambiguate between "return;" and "return expression;"
        // for example, a function, a variable, or a literal may be found here, and their types need to be checked stored
        // return: pop expression
        void _return()
        {
            string func = "_return";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            var_sar val = SAS.top!(var_sar)();
            if(val is null)
                gen_error(func, format("Expected a var_sar, but got something else: ", val.identifier, which_sar(val)));
            SAS.pop();
            if(val.type == "null")
            {
                icode.add(["RTN", "", "", ""]);
            }
            else
            {
                icode.add(["RETURN", val.Symid, "", ""]);
            }
        }

        // TODO: Need to verify that the type of data can be printed
        // cout: pop expression
        void _cout()
        {
            string func = "_cout";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            var_sar val = SAS.top!(var_sar)();
            if(val !is null)
            {
                //stderr.writef("_cout: %s\n", symbols.get(val.Symid));
                icode.add(["WRITE", ref_check(val.Symid), "", ""]);
            }
            else
            {
                gen_error(func, format("Expected a var_sar, but got something else: ", val.identifier, which_sar(val)));
            }
            SAS.pop();
        }

        // TODO: Need to verify that the type of data can be read in from a file
        // cin: pop expression
        void _cin()
        {
            string func = "_cin";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            var_sar val = SAS.top!(var_sar)();
            if(val !is null)
            {
                icode.add(["READ", ref_check(val.Symid), "", ""]);
            }
            else
            {
                gen_error(func, format("Expected a var_sar, but got something else: ", val.identifier, which_sar(val)));
            }
            SAS.pop();
        }

        // BAL: push BAL (string)
        void BAL()
        {
            string func = "BAL";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            SAS.push(new basic_sar("BAL"));
        }

        // EAL: pop all arguments(literals and variables), push argument_list (array of literals and variables)
        // EAL: pop all arguments var_sar's, push argument_list (array of var_sar's)
        void EAL()
        {
            string func = "EAL";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            basic_sar cur_sar;
            var_sar[] SARS;
            cur_sar = SAS.top!(basic_sar)();
            debug(log2) log(func , format("Poped [%s] from the SAS", cur_sar.identifier));
            SAS.pop();
            while(cur_sar.identifier != "BAL")
            {
                debug(log2) log(func , format("Poped [%s] from the SAS", cur_sar.identifier));
                if(var_sar test_sar = cast(var_sar)(cur_sar))
                    SARS ~= test_sar;
                else
                    gen_error(func, format("Non-variable in argument_list [%s]", cur_sar.identifier));
                cur_sar = SAS.top!(basic_sar)();
                SAS.pop();
            }
            SAS.push(new argument_list_sar(SARS));
        }

        // func: pop argument_list and identifier, push function (Don't forget return type of the function)
        void func()
        {
            string func = "func";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            argument_list_sar args = SAS.top!(argument_list_sar)();
            SAS.pop();
            id_sar func_name = SAS.top!(id_sar)();
            SAS.pop();
            SAS.push(new func_sar(new var_sar(func_name, "", ""), args));
        }

        // arr: pop expression and identifier and another identifier
        void arr()
        {
            string func = "arr";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            var_sar index = SAS.top!(var_sar)();
            SAS.pop();
            id_sar identifier = SAS.top!(id_sar)();
            SAS.pop();
            // Convert the id_sar to a var_sar, and verify that it's an array
            // get symbol for the id_sar
            // Verify that Type begins with @
            Symbol existing_symbol = symbols.find(identifier.identifier, _scope);
            if(existing_symbol is null)
            {
                gen_error(func, format("Reference before declaration for variable [%s] in the scope [%s] on line [%d]", identifier.identifier, _scope.join("."), tokenizer.ct.line));
            }
            else if(existing_symbol.data.get("Type", "-")[0] == '@')
            {
                SAS.push(new arr_sar(new var_sar(identifier, existing_symbol.data["Type"], existing_symbol.info["Symid"]), index));
            }
            else
            {
                gen_error(func, format("Identifier [%s] is not an array, it is a [%s]", identifier.identifier, existing_symbol.data["Type"]));
            }
        }

        // TODO: Verify that there is a constructor that matches the argument_list types;
        // newObj: pop argument_list and type, push constructor (type + argument_list)
        void newObj()
        {
            string func = "newObj";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            argument_list_sar argument_list = SAS.top!(argument_list_sar)();
            SAS.pop();
            type_sar type = SAS.top!(type_sar)();
            SAS.pop();

            Symbol ref_symbol = symbols.gen_tmp(_scope, "int");
            Symbol new_symbol = symbols.gen_tmp(_scope, type.identifier);
            //new_symbol.set_info(["Reference":type.identifier]);
            //stderr.writef("%s\n", new_symbol);
            //icode.add(["NEWI", "GETSIZE", ref_symbol.info["Symid"], ""]);
            //Symbol size_symbol = symbols.add_global("int", format("GI+%d", symbols.size_of(new_symbol.info["Symid"])));
            //icode.add(["NEWI", "+64", new_symbol.info["Symid"], ""]);
            // TODO: Calling NEWI here is probably not correct....
            icode.add(["NEWI", format("%s", symbols.size_of(new_symbol.info["Symid"])), new_symbol.info["Symid"], ""]);
            Symbol constructor_symbol = symbols.find(new_symbol.data["Type"], "g." ~ new_symbol.data["Type"]);
            icode.add(["FRAME", constructor_symbol.info["Symid"], new_symbol.info["Symid"], ""]);
            foreach(l; argument_list.list)
            {
                icode.add(["PUSH", ref_check(l.Symid), "", ""]);
            }
            icode.add(["CALL", constructor_symbol.info["Symid"], "", ""]);
            icode.add(["PEEK", new_symbol.info["Symid"], "", ""]);
            // The newObj_sar contains the symbol information for the return value of the constructor function
            SAS.push(new newObj_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"], argument_list));
        }

        // TODO: Verify that the var_sar is an int and that type_sar is an array-able type
        // new[]: pop expression and type, push array
        void newArr()
        {
            string func = "newArr";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            var_sar index = SAS.top!(var_sar)();
            SAS.pop();
            type_sar type = SAS.top!(type_sar)();
            SAS.pop();
            Symbol index_symbol = symbols.get(index.Symid);
            Symbol size_symbol = symbols.gen_tmp(_scope, "int");
            Symbol new_symbol = symbols.gen_tmp(_scope, "int");
            Symbol pointer_size = symbols.add_global("int", "GI+4");
            icode.add(["MUL", pointer_size.info["Symid"], index_symbol.info["Symid"], size_symbol.info["Symid"]]);
            icode.add(["NEW", size_symbol.info["Symid"], new_symbol.info["Symid"], ""]);
            //SAS.push(new newArr_sar(type, index));
            SAS.push(new newArr_sar(new_symbol.info["Value"], "@" ~ type.identifier, new_symbol.info["Symid"], index));
        }

        // atoi: pop expression, push variable
        void _atoi()
        {
            string func = "_atoi";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            var_sar top_sar = SAS.top!(var_sar)();
            SAS.pop();
            if(top_sar !is null)
            {
                if(top_sar.type != "char")
                {
                    gen_error(func, format("Expected an [char], but got [%s]", top_sar.type));
                }
                Symbol new_symbol = symbols.gen_tmp(_scope, "int");
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
            }
            else
            {
                gen_error(func, "Expected an [var_sar or var_sar], but got something else. Don't exepect anything else to work.");
            }
        }

        // itoa: pop expression, push variable
        void _itoa()
        {
            string func = "_itoa";
            debug(log2) log(func , format("Scope[%s], Token [%s]", _scope.join("."), tokenizer.ct));
            var_sar top_sar = SAS.top!(var_sar)();
            if(top_sar !is null)
            {
                if(top_sar.type != "int")
                {
                    gen_error(func, format("Expected an [int], but got [%s]", top_sar.type));
                }
                SAS.pop();
                Symbol new_symbol = symbols.gen_tmp(_scope, "char");
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
            }
            else
            {
                gen_error(func, "Expected an [var_sar], but got something else. Don't exepect anything else to work.");
            }
        }

        void _op_mult()
        {
            string func = "_op_mult";
            debug(log4) stderr.writef("Need to multiply left and right\n");
            var_sar right = SAS.top!(var_sar)();
            SAS.pop();
            var_sar left = SAS.top!(var_sar)();
            SAS.pop();
            // TODO: Check types, and create a new SAR
            if(right is null)
                gen_error(func, format("Expected right to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left is null)
                gen_error(func, format("Expected left to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left.type != right.type)
                gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.type, right.type));
            else
            {
                // Create a new symbol
                Symbol new_symbol = symbols.gen_tmp(_scope, left.type);
                // Push a new var_sar
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
                icode.add(["MUL", ref_check(left.Symid), ref_check(right.Symid), new_symbol.info["Symid"]]);
            }
        }

        void _op_div()
        {
            string func = "_op_div";
            debug(log4) stderr.writef("Need to divide left and right\n");
            var_sar right = SAS.top!(var_sar)();
            SAS.pop();
            var_sar left = SAS.top!(var_sar)();
            SAS.pop();
            if(right is null)
                gen_error(func, format("Expected right to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left is null)
                gen_error(func, format("Expected left to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left.type != right.type)
                gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.type, right.type));
            else
            {
                // Create a new symbol
                Symbol new_symbol = symbols.gen_tmp(_scope, left.type);
                // Push a new var_sar
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
                icode.add(["DIV", ref_check(left.Symid), ref_check(right.Symid), new_symbol.info["Symid"]]);
            }
        }

        void _op_add()
        {
            string func = "_op_add";
            debug(log4) stderr.writef("Need to add left and right\n");
            var_sar right = SAS.top!(var_sar)();
            SAS.pop();
            var_sar left = SAS.top!(var_sar)();
            SAS.pop();
            if(left is null)
                gen_error(func, format("[??] + [%s] Expected left to be var_sar, but it was one of these[%s]. Don't expect anything else to work.", right.identifier, which_sar(left)));
            else if(right is null)
                gen_error(func, format("[%s] + [??] Expected right to be var_sar, but it was one of these[%s]. Don't expect anything else to work.", left.identifier, which_sar(right)));
            else if(left.type != right.type)
                gen_error(func, format("[%s] + [%s] Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.identifier, right.identifier, left.type, right.type));
            else
            {
                // Create a new symbol
                Symbol new_symbol = symbols.gen_tmp(_scope, left.type);
                // Push a new var_sar
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
                icode.add(["ADD", ref_check(left.Symid), ref_check(right.Symid), new_symbol.info["Symid"]]);
            }
        }

        void _op_sub()
        {
            string func = "_op_sub";
            debug(log4) stderr.writef("Need to sub left and right\n");
            var_sar right = SAS.top!(var_sar)();
            SAS.pop();
            var_sar left = SAS.top!(var_sar)();
            SAS.pop();
            if(right is null)
                gen_error(func, format("Expected right to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left is null)
                gen_error(func, format("Expected left to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left.type != right.type)
                gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.type, right.type));
            else
            {
                // Create a new symbol
                Symbol new_symbol = symbols.gen_tmp(_scope, left.type);
                // Push a new var_sar
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
                icode.add(["SUB", ref_check(left.Symid), ref_check(right.Symid), new_symbol.info["Symid"]]);
            }
        }

        // TODO: 
        // Need to fix the _return to push a var_sar onto the stack
        // Need to ensure that the left is a var_sar, not var_sar
        void _op_assign()
        {
            string func = "_op_assign";
            debug(log4) stderr.writef("Need to assign left to right\n");
            basic_sar right = SAS.top!(basic_sar)();
            SAS.pop();
            var_sar left = SAS.top!(var_sar)();
            SAS.pop();
            if(right is null)
                gen_error(func, format("Expected right to be basic_sar, but it wasn't. Expect catastrophic failure to ensue."));
            else if(left is null)
            {
                gen_error(func, format("Expected left to be var_sar, but it wasn't. Expect catastrophic failure to ensue."));
            }
            else
            {
                debug(log4) stderr.writef("[%d] Left: %s, %s = Right: %s, %s\n", tokenizer.ct.line, left.identifier, which_sar(left), right.identifier, which_sar(right));
                if(type_sar test_right = cast(type_sar)(right))
                {
                    if(left.type == test_right.identifier)
                    {
                        debug(log4) stderr.writef("good\n");
                        // TODO: Does this need fixing? Move a type to a variable?
                        icode.add(["MOV", left.Symid, right.identifier, ""]);
                    }
                    else if(arr_sar test_left = cast(arr_sar)(left))
                    {
                        if(test_left.type == "@" ~ test_right.identifier)
                        {
                            debug(log4) stderr.writef("good\n");
                            icode.add(["MOV", left.Symid, "*" ~ right.identifier, ""]);
                        }
                        else
                        {
                            gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.type, test_right.identifier));
                        }
                    }
                    else
                    {
                        gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.type, test_right.identifier));
                    }
                }
                else if(var_sar test_right = cast(var_sar)(right))
                {
                    if(left.type == test_right.type)
                    {
                        debug(log4) stderr.writef("good\n");
                        icode.add(["MOV", ref_check(left.Symid), ref_check(test_right.Symid), ""]);
                    }
                    else if(arr_sar test_left = cast(arr_sar)(left))
                    {
                        if(test_left.type == "@" ~ test_right.identifier)
                        {
                            debug(log4) stderr.writef("good\n");
                            icode.add(["MOV", left.Symid, "*" ~ test_right.Symid, ""]);
                        }
                        else
                        {
                            gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.type, test_right.identifier));
                        }
                    }
                    else if(test_right.type == "null")
                    {
                        icode.add(["MOVI", left.Symid, "0", ""]);
                    }
                    else
                    {
                        gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s %s], right[%s %s]", left.type, left.identifier, test_right.type, right.identifier));
                        stderr.writef("left: %s\nright: %s\n", which_sar(left), which_sar(right));
                    }
                }
            }
        }

        void _op_le()
        {
            string func = "_op_le";
            debug(log4) stderr.writef("Need to compare left <= right\n");
            var_sar right = SAS.top!(var_sar)();
            SAS.pop();
            var_sar left = SAS.top!(var_sar)();
            SAS.pop();
            // TODO: Add this to symbol table
            if(right is null)
                gen_error(func, format("Expected right to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left is null)
                gen_error(func, format("Expected left to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left.type != right.type)
                gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.type, right.type));
            else
            {
                // Create a new symbol
                Symbol new_symbol = symbols.gen_tmp(_scope, "bool");
                // Push a new var_sar
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
                icode.add(["LE", ref_check(left.Symid), ref_check(right.Symid), new_symbol.info["Symid"]]);
            }
        }

        void _op_ge()
        {
            string func = "_op_ge";
            debug(log4) stderr.writef("Need to compare left >= right\n");
            var_sar right = SAS.top!(var_sar)();
            SAS.pop();
            var_sar left = SAS.top!(var_sar)();
            SAS.pop();
            // TODO: Add this to symbol table
            if(right is null)
                gen_error(func, format("Expected right to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left is null)
                gen_error(func, format("Expected left to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left.type != right.type)
                gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.type, right.type));
            else
            {
                // Create a new symbol
                Symbol new_symbol = symbols.gen_tmp(_scope, "bool");
                // Push a new var_sar
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
                icode.add(["GE", ref_check(left.Symid), ref_check(right.Symid), new_symbol.info["Symid"]]);
            }
        }

        void _op_lt()
        {
            string func = "_op_lt";
            debug(log4) stderr.writef("Need to compare left < right\n");
            var_sar right = SAS.top!(var_sar)();
            SAS.pop();
            var_sar left = SAS.top!(var_sar)();
            SAS.pop();
            // TODO: Add this to symbol table
            if(right is null)
                gen_error(func, format("Expected right to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left is null)
                gen_error(func, format("Expected left to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left.type != right.type)
                gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s %s], right[%s %s]", left.type, left.identifier, right.type, right.identifier));
            else
            {
                // Create a new symbol
                Symbol new_symbol = symbols.gen_tmp(_scope, "bool");
                // Push a new var_sar
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
                icode.add(["LT", ref_check(left.Symid), ref_check(right.Symid), new_symbol.info["Symid"]]);
            }
        }

        void _op_gt()
        {
            string func = "_op_gt";
            debug(log4) stderr.writef("Need to compare left > right\n");
            var_sar right = SAS.top!(var_sar)();
            SAS.pop();
            var_sar left = SAS.top!(var_sar)();
            SAS.pop();
            // TODO: Add this to symbol table
            if(right is null)
                gen_error(func, format("Expected right to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left is null)
                gen_error(func, format("Expected left to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left.type != right.type)
                gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.type, right.type));
            else
            {
                // Create a new symbol
                Symbol new_symbol = symbols.gen_tmp(_scope, "bool");
                // Push a new var_sar
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
                icode.add(["GT", ref_check(left.Symid), ref_check(right.Symid), new_symbol.info["Symid"]]);
            }
        }

        void _op_eq()
        {
            string func = "_op_eq";
            debug(log4) stderr.writef("Need to compare left == right\n");
            var_sar right = SAS.top!(var_sar)();
            SAS.pop();
            var_sar left = SAS.top!(var_sar)();
            SAS.pop();
            // TODO: Add this to symbol table
            if(right is null)
            {
                gen_error(func, format("Expected right to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            }
            else if(left is null)
            {
                gen_error(func, format("Expected left to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            }
            else if(right.type != "null" && left.type != right.type)
            {
                gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.type, right.type));
            }
            else
            {
                // Create a new symbol
                Symbol new_symbol = symbols.gen_tmp(_scope, "bool");
                // Push a new var_sar
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
                icode.add(["EQ", ref_check(left.Symid), ref_check(right.Symid), new_symbol.info["Symid"]]);
            }
        }

        void _op_ne()
        {
            string func = "_op_ne";
            debug(log4) stderr.writef("Need to compare left != right\n");
            var_sar right = SAS.top!(var_sar)();
            SAS.pop();
            var_sar left = SAS.top!(var_sar)();
            SAS.pop();
            // TODO: Add this to symbol table
            if(right is null)
                gen_error(func, format("Expected right to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left is null)
                gen_error(func, format("Expected left to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(right.type != "null" && left.type != right.type)
                gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.type, right.type));
            else
            {
                // Create a new symbol
                Symbol new_symbol = symbols.gen_tmp(_scope, "bool");
                // Push a new var_sar
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
                icode.add(["NE", ref_check(left.Symid), ref_check(right.Symid), new_symbol.info["Symid"]]);
            }
        }

        void _op_and()
        {
            string func = "_op_and";
            debug(log4) stderr.writef("Need to compare left && right\n");
            var_sar right = SAS.top!(var_sar)();
            SAS.pop();
            var_sar left = SAS.top!(var_sar)();
            SAS.pop();
            // TODO: Add this to symbol table
            if(right is null)
                gen_error(func, format("Expected right to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left is null)
                gen_error(func, format("Expected left to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left.type != right.type)
                gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.type, right.type));
            else
            {
                // Create a new symbol
                Symbol new_symbol = symbols.gen_tmp(_scope, "bool");
                // Push a new var_sar
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
                icode.add(["AND", ref_check(left.Symid), ref_check(right.Symid), new_symbol.info["Symid"]]);
            }
        }

        void _op_or()
        {
            string func = "_op_or";
            debug(log4) stderr.writef("Need to compare left || right\n");
            var_sar right = SAS.top!(var_sar)();
            SAS.pop();
            var_sar left = SAS.top!(var_sar)();
            SAS.pop();
            // TODO: Add this to symbol table
            if(right is null)
                gen_error(func, format("Expected right to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left is null)
                gen_error(func, format("Expected left to be var_sar or var_sar, but it wasn't. Don't expect anything else to work."));
            else if(left.type != right.type)
                gen_error(func, format("Expected left and right to be the same type, but they aren't: left[%s], right[%s]", left.type, right.type));
            else
            {
                // Create a new symbol
                Symbol new_symbol = symbols.gen_tmp(_scope, "bool");
                // Push a new var_sar
                SAS.push(new var_sar(new_symbol.info["Value"], new_symbol.data["Type"], new_symbol.info["Symid"]));
                icode.add(["OR", ref_check(left.Symid), ref_check(right.Symid), new_symbol.info["Symid"]]);
            }
        }
    }
    
    string which_sar(SemanticActionRecord sar)
    {
        string[] retval;
        if(cast(basic_sar)(sar))
            retval ~= "basic_sar";
        if(cast(type_sar)(sar))
            retval ~= "type_sar";
        if(cast(id_sar)(sar))
            retval ~= "id_sar";
        if(cast(var_sar)(sar))
            retval ~= "var_sar";
        if(cast(argument_list_sar)(sar))
            retval ~= "argument_list_sar";
        if(cast(func_sar)(sar))
            retval ~= "func_sar";
        if(cast(arr_sar)(sar))
            retval ~= "arr_sar";
        if(cast(ref_sar)(sar))
            retval ~= "ref_sar";
        if(cast(newObj_sar)(sar))
            retval ~= "newObj_sar";
        if(cast(newArr_sar)(sar))
            retval ~= "newArr_sar";
        return retval.join(",");
    }

    interface SemanticActionRecord
    {
    }

    // Could almost eliminate the interface since most things start here
    // The basic_sar is used to keep track of the identifier and the type of a token
    //   Line number can always be retrieved from the tokenizer, so we don't have any need to store it here
    class basic_sar : SemanticActionRecord
    {
    private:
        this() {}
    public:
        string identifier;
        this(basic_sar identifier) 
        { 
            this.identifier = identifier.identifier; 
        } 
        this(string identifier) 
        {
            this.identifier = identifier;
        }
    }

    // type_sar is used to differentiate a basic_sar storing an identifier from a basic_star storing a type
    // identifier: a keyword like "int", "char", "bool"
    class type_sar : basic_sar 
    { 
        this(basic_sar identifier) 
        { 
            super(identifier.identifier); 
        } 
        this(string identifier) 
        { 
            super(identifier); 
        } 
    }
    // id_sar is used to differentiate a basic_sar storing an identifier from a basic_star storing a type
    // identifier: an identifier like "first_name" or "x"
    class id_sar   : basic_sar
    { 
        this(basic_sar identifier) 
        { 
            super(identifier.identifier); 
        } 
        this(string identifier) 
        { 
            super(identifier); 
        } 
    }

    // var_sar is used to keep track of a literal's data type and value.
    //   identifier: should be set to the Symid of the literal
    //   type: data type of the literal (ie: bool, char, int)
    //   Symid: the Symbol table ID.
    class var_sar  : id_sar 
    { 
        string type;
        string Symid;
        this(var_sar variable)
        { 
            super(variable.identifier); 
            this.type = variable.type;
            this.Symid = variable.Symid;
        } 
        this(id_sar identifier, string type, string Symid) 
        { 
            super(identifier); 
            this.type = type;
            this.Symid = Symid;
        } 
        this(string identifier, string type, string Symid) 
        { 
            super(identifier); 
            this.type = type;
            this.Symid = Symid;
        } 
    }

    // argument_list_sar is simply a collection (array) of SARs. 
    class argument_list_sar : SemanticActionRecord
    {
        var_sar[] list;
        this(var_sar[] list) { this.list = list; }
    }

    // func_sar is an id_sar that has an argument_list
    class func_sar : var_sar
    {
        argument_list_sar args;
        this(var_sar variable, argument_list_sar args)
        {
            super(variable);
            this.args = args;
        }
        this(id_sar identifier, string type, string Symid, argument_list_sar args)
        {
            super(identifier, type, Symid);
            this.args = args;
        }
        this(string identifier, string type, string Symid, argument_list_sar args)
        {
            super(identifier, type, Symid);
            this.args = args;
        }
    }

    // arr_sar is a var_sar and has one of var_sar as the index
    class arr_sar : var_sar
    {
        var_sar index;
        this(var_sar copy, var_sar index) 
        { 
            super(copy.identifier, copy.type, copy.Symid); 
            this.index = index;
        } 
        this(string identifier, string type, string Symid, var_sar index) 
        { 
            super(identifier, type, Symid); 
            this.index = index;
        } 
    }

    // TODO: finish this
    // ref_sar is one of [var_sar, func_sar, arr_sar] and one of [var_sar, func_sar, arr_sar]
    class ref_sar : var_sar
    {
        this(var_sar member)
        {
            super(member);
        }
        this(string identifier, string type, string Symid)
        {
            super(identifier, type, Symid);
        }
    //    var_sar reference;
    //    var_sar member;
    //    this(var_sar reference ,var_sar member)
    //    {
    //        super(reference.identifier ~ "." ~ member.identifier, member.type, member.Symid);
    //        this.reference = reference;
    //        this.member = member;
    //    }
    }

    // newObj_sar is a func_sar (Constructor)
    class newObj_sar : func_sar
    {
        this(var_sar variable, argument_list_sar args)
        {
            super(variable, args);
        }
        this(id_sar identifier, string type, string Symid, argument_list_sar args)
        {
            super(identifier, type, Symid, args);
        }
        this(string identifier, string type, string Symid, argument_list_sar args)
        {
            super(identifier, type, Symid, args);
        }
    }

    // newArr_sar is a var_sar with a var_sar for the size
    class newArr_sar : var_sar
    {
        var_sar size;
        this(var_sar var, var_sar size)
        {
            var.type = "@" ~ var.type;
            super(var);
            this.size = size;
        }
        this(string identifier, string type, string Symid, var_sar size)
        {
            super(identifier, type, Symid);
            this.size = size;
        }
    }

    OperatorStack OS;
    class OperatorStack
    {
    private:
        string[] OPS;
    public:
        void push(string new_op)
        {
            OPS ~= new_op;
        }

        string pop()
        body
        {
            enforce(!OPS.empty, "OPS.pop called on an empty stack!");
            string retval = OPS[$-1];
            OPS.popBack;
            return retval;
        }
        string top()
        {
            if(!OPS.empty)
            {
                string retval = OPS[$-1];
                return retval;
            }
            else
            {
                return "";
            }
        }
        @property size_t length() { return OPS.length; }
        @property bool empty() { return OPS.empty; }
    }

    SemanticActionStack SAS;
    class SemanticActionStack
    {
    private:
        SemanticActionRecord[] SARS;
    public:
        this()
        {
            SARS.length = 0;
        }
        void push(SemanticActionRecord new_sar)
        {
            enforce(new_sar !is null, "Unable to push a null sar onto the SAS.");
            debug(log3) 
                if(basic_sar test_sar = cast(basic_sar)(new_sar)) 
                    stderr.writef("  *  SAS.push called to add [%s]\n", test_sar.identifier);
            SARS ~= new_sar;
            debug(log3) stderr.writef("  *  SAS.push called leaving [%d] on the stack\n", SARS.length);
        }
    
        T top(T)()
        {
            enforce(!SARS.empty, "SAS.top called on an empty stack");
            debug(log3) 
                if(basic_sar test_sar = cast(basic_sar)(SARS[$-1])) 
                    stderr.writef("  *  SAS.top called to return [%s]\n", test_sar.identifier);
            debug(log3) stderr.writef("  *  SAS.top called with [%d] on the stack\n", SARS.length);
            return cast(T)(SARS[$-1]);
        }

        void pop()
        {
            enforce(!SARS.empty, "SAS.pop called on an empty stack");
            debug(log3) 
                if(basic_sar test_sar = cast(basic_sar)(SARS[$-1])) 
                    stderr.writef("  *  SAS.pop called to remove [%s]\n", test_sar.identifier);
            SARS.popBack;
            debug(log3) stderr.writef("  *  SAS.pop called leaving [%d] on the stack\n", SARS.length);
        }
        @property size_t length() { return SARS.length; }
        @property bool empty() { return SARS.empty; }
    }

    bool check_token(string type) 
    {
        return (tokenizer.ct.type == type);
    }

    bool check_token(string[] type) 
    {
        bool retval = false;
        foreach(t; type)
        {
            retval = (retval || check_token(t));
        }
        return retval;
    }

    bool check_token(string type, string lexeme) 
    {
        return (tokenizer.ct.type == type && tokenizer.ct.lexeme == lexeme);
    }

    bool check_token(string type, string[] lexeme) 
    {
        bool retval = false;
        foreach(l; lexeme)
        {
            retval = (retval || check_token(type, l));
        }
        return retval;
    }

    void log(string func, string msg) 
    {
        stderr.writef("     %s: %s\n", func, msg);
    }

    void gen_error(string func, string msg = "", string file = __FILE__, int line = __LINE__)
    {
        if(msg == "")
        {
            debug(gen_error) stderr.writef("gen_error: (in %s:%s on line %d) ", file, func, line);
            stderr.writef("[%d][%s] Error on token (%s).\n", tokenizer.ct.line, _scope.join("."), tokenizer.ct);
        }
        else
        {
            debug(gen_error) stderr.writef("gen_error: (in %s:%s on line %d) ", file, func, line);
            stderr.writef("[%d][%s] Error: %s.\n", tokenizer.ct.line, _scope.join("."), msg);
        }
        errors++;
        if(errors >= 5)
        {
            throw(new Exception(format("Too many errors encountered: [%d]", errors)));
        }
        while(!(check_token("symbol","}") || check_token("punctuation",";") || check_token("EOT")))
        {
            debug(log1) log("gen_error", format("consuming token (%s)", tokenizer.ct.toString));
            tokenizer.nextToken();
        }
        if(check_token("EOT"))
        {
            throw(new Exception(format("Encountered an EOT during gen_error(): %s", tokenizer.ct)));
        }
    }

    // compilation_unit::= 
    //     {class_declaration} 
    //     "void" "main" "(" ")" method_body
    //     ;
    void compilation_unit() 
        {
        string func = "compilation_unit";
        debug(log1) log(func, "Start");

        if(pass == 1)
        {
            Symbol main_symbol = new Symbol;
            main_symbol.set_info(["Scope":"g", "Kind":"method", "Value":"main"]);
            main_symbol.set_data(["Type":"void", "accessMod":"public", "Size":"0"]);
            symbols.add_symbol(main_symbol);
        }
        if(pass == 2)
        {
            // TODO: Get the symbol for main, and pass that Symid to Icode
            icode.add(["FRAME", "M100", "this", ""]);
            icode.add(["CALL", "M100", "", ""]);
            icode.set_label("EOP");
            icode.add(["EOP","","",""]);
        }

        while(check_token("keyword", "class") && !check_token("EOT"))
        {
            class_declaration();
        }

        if(!check_token("type", "void")) 
        {
            gen_error(func, format("Expected type \"void\", and got %s", tokenizer.ct.lexeme));
        } 
        debug(log1) log(func, tokenizer.ct.toString());
        // If I need the return type, I can get it before nextToken is called
        tokenizer.nextToken();

        if(!check_token("keyword", "main")) 
        {
            gen_error(func, format("Expected keyword 'main', but got '%s'", tokenizer.ct.lexeme));
        }
        debug(log1) log(func, tokenizer.ct.toString());
        _scope ~= tokenizer.ct.lexeme;
        tokenizer.nextToken();

        if(!check_token("symbol", "(")) 
        {
            gen_error(func);
        }
        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        if(!check_token("symbol", ")")) 
        {
            gen_error(func);
        }
        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        if(!check_token("symbol", "{")) 
        {
            gen_error(func);
        }
        debug(log1) log(func, tokenizer.ct.toString());

        method_body();

        if(pass == 2)
        {
            Symbol main_symbol = symbols.find("main", "g");
            main_symbol.data["Size"] = format("%s", symbols.size_of(main_symbol.info["Symid"]));
        }

        _scope = _scope[0..$];
        debug(log1) log(func, "End");
    }

    // class_declaration::=
    //     "class" class_name 
    //     "{" 
    //     {class_member_declaration} 
    //     "}" 
    //     ;
    void class_declaration() 
        {
        string func = "class_declaration";
        debug(log1) log(func, "Start");

        if(!check_token("keyword", "class"))
        {
            gen_error(func);
        }
        current_symbol = new Symbol();
        current_symbol.set_info(["Scope":_scope.join("."),"Kind":tokenizer.ct.lexeme]);

        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        if(!(check_token("identifier") || (pass == 2 && check_token("class_name"))))
        {
            gen_error(format("%s: expected identifier", func));
        }

        tokenizer.add_current_class();

        current_symbol.set_info(["Value":tokenizer.ct.lexeme]);
        if(pass == 1)
            symbols.add_symbol(current_symbol);
        current_symbol = null;

        _scope ~= tokenizer.ct.lexeme;

        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        if(!check_token("symbol", "{")) 
        {
            //stderr.writef("Not a {\n");
            gen_error(func);
        }
        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        while((pass == 1 && check_token(["modifier", "identifier", "class_name"])) || (pass == 2 && check_token(["modifier", "class_name"])))
        {
            class_member_declaration();
        }

        if(!check_token("symbol", "}"))
        {
            gen_error(func, format("Got \"%s\", when expecting a modifier, identifier, Constructor, or }", tokenizer.ct.lexeme));
        }
        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        if(pass == 2)
        {
            current_symbol = symbols.find(_scope[$-1], _scope[0..$-1]);
            //writef("Size of Class %s %s\n", _scope.join("."), symbols.size_of(current_symbol.info["Symid"]));
            current_symbol.data["Size"] = format("%s", symbols.size_of(current_symbol.info["Symid"]));
            //stderr.writef("current_symbol: %s\n", current_symbol);
            //enforce(false, format("Need to check the size of the class here. ", _scope.join(".")));
            current_symbol = null;
        }

        _scope = _scope[0..$-1];
        debug(log1) log(func, "End");
    }

    // method_body::=
    //    "{" {variable_declaration} {statement} "}" ;
    void method_body() 
    {
        string func = "method_body";
        debug(log1) log(func, format("Start: %s", _scope));
        if(pass == 2)
        {
            current_symbol = symbols.find(_scope[$-1], _scope[0..$-1]);
            //symbols.size_of(current_symbol.info["Symid"]); // Check the size of all functions every pass2
            enforce(current_symbol !is null);
            icode.set_label(current_symbol.info["Symid"]);
            current_symbol = null;
        }
        // If we need the leading {, we can capture it here before nextToken
        tokenizer.nextToken();

        // {variable_declaration}
        while(((pass == 1 && check_token(["type", "identifier", "class_name"]) && tokenizer.peek(1).type == "identifier") || (pass == 2 && check_token(["type", "class_name"])) && !check_token("EOT")))
        {
            variable_declaration();
        }

        //{statement}
        while
        (
            (
                check_token("symbol", ["{", "(", "+", "-"]) || 
                check_token("keyword", ["if", "while", "return", "cout", "cin", "true", "false", "null"]) ||
                // TODO numeric_literal fix
                check_token(["number", "character_literal", "identifier"])
            )
        )
        {
            statement();
        }
        while(!check_token("symbol", "}")) 
        {
            gen_error(func);
            if(!check_token("symbol", "}"))
            {
                debug(log1) log(func, tokenizer.ct.toString());
                tokenizer.nextToken();
            }
        }
        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        if(pass == 2) 
        {
            current_symbol = symbols.find(_scope[$-1], _scope[0..$-1]);
            enforce(current_symbol !is null);
            symbols.size_of(current_symbol.info["Symid"]); // Check the size of all functions every pass2
            current_symbol = null;
            icode.add(["RTN", "", "", ""]);
        }
        debug(log1) log(func, "End");
    }

    // class_member_declaration::= 
    //       modifier type #tExist identifier field_declaration
    //     | constructor_declaration  
    //     ;
    void class_member_declaration()
    {
        string func = "class_member_declaration";
        debug(log1) log(func, "Start");

        if(check_token("modifier")) {
            current_symbol = new Symbol();
            current_symbol.set_data(["accessMod":tokenizer.ct.lexeme]);

            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            
            if((pass == 1 && !(check_token(["identifier", "type", "class_name"])) || (pass == 2 && !check_token(["type","class_name"]))))
            {
                if(pass == 1)
                    gen_error(func, format("Expected either a type or a identifier. '%s' is not a defined identifier or a built in type.", tokenizer.ct.lexeme));
                if(pass == 2)
                    gen_error(func, format("Expected either a type or a class_name. '%s' is not a defined identifier or a class_name.", tokenizer.ct.lexeme));
            }
            if(pass == 2)
                SA.tPush();
            if(pass == 2)
                SA.tExist();

            current_symbol.set_data(["Type":tokenizer.ct.lexeme]);
            debug(log1) log(func, tokenizer.ct.toString());

            tokenizer.nextToken();

            if(!check_token("identifier")) {
                gen_error(func, format("Expected an identifier (variable name), but got '%s' instead.", tokenizer.ct.lexeme));
            }
            current_symbol.set_info(["Value":tokenizer.ct.lexeme,"Scope":_scope.join(".")]);

            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            field_declaration();
        }
	    else if((pass == 1 && check_token(["identifier", "class_name"])) || (pass == 2 && check_token("class_name",_scope[$-1]))) // Check for Constructor
	    {
            constructor_declaration();
        }
	    else
	    {
            gen_error(func);
	    }

        debug(log1) log(func, "End");
    }

    // constructor_declaration::= 
    //     class_name #CD "(" [parameter_list] ")" method_body ;

    void constructor_declaration()
    {
        string func = "constructor_declaration";
        debug(log1) log(func, "Start");
        if((pass == 1 && !check_token(["identifier", "class_name"])) || (pass == 2 && !check_token("class_name", _scope[$-1])))
        {
            gen_error(func);
        }
        current_symbol = new Symbol();
        current_symbol.set_info(["Scope":_scope.join("."), "Kind":"method", "Value":tokenizer.ct.lexeme]);
        current_symbol.set_data(["returnType":tokenizer.ct.lexeme, "accessMod":"public"]);

        if(pass == 1)
            symbols.add_symbol(current_symbol);
        if(pass == 2)
            SA.CD();
        last_method_symbol = current_symbol;
        current_symbol = null;


        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        if(!check_token("symbol", "("))
        {
            gen_error(func, format("Expected a Constructor to be followed by \"(\" but got a \"%s\".", tokenizer.ct.lexeme));
        }
        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        _scope ~= _scope[$-1];
        parameter_list();

        if(!check_token("symbol", ")"))
        {
            gen_error(func);
        }
        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        last_method_symbol = null;

        if(pass == 2)
            icode.set_label(_scope[$-1]);
        method_body();

        _scope = _scope[0..$-1];

        debug(log1) log(func, "End");
    }

    // parameter_list::= 
    //     parameter { "," parameter } 
    //     ;
    void parameter_list()
    {
        string func = "parameter_list";
        debug(log1) log(func, "Start");

        if((pass == 1 && check_token(["type", "identifier", "class_name"])) || (pass == 2 && check_token(["type", "class_name"])))
        {
            parameter();
        }

        while(check_token("punctuation",","))
        {
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if((pass == 1 && !check_token(["type", "identifier", "class_name"])) || (pass == 2 && !check_token(["type", "class_name"])))
            {
                gen_error(func, format("Expected a type or identifier name. '%s' is not a defined type or identifier.", tokenizer.ct.lexeme));
            }
            parameter();
        }

        debug(log1) log(func, "End");
    }

    // parameter::= 
    //     type identifier ["[" "]"] 
    //     ;
    // parameter::= 
    //     type #tExist identifier ["[" "]"] 
    //     ;
    void parameter()
    {
        string func = "parameter";
        debug(log1) log(func, "Start");
        if((pass == 1 && !check_token(["type", "identifier", "class_name"])) || (pass == 2 && !check_token(["type", "class_name"])))
        {
            gen_error(func, format("Expected a type or identifier name. '%s' is not a defined type or identifier.", tokenizer.ct.lexeme));
        }
        current_symbol = new Symbol;
        current_symbol.set_info(["Scope":_scope.join("."), "Kind":"param"]);
        current_symbol.set_data(["Type":tokenizer.ct.lexeme, "accessMod":"private"]);

        if(pass == 2)
            SA.tPush();
        if(pass == 2)
            SA.tExist();

        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        if(!check_token("identifier"))
        {
            gen_error(func);
        }
        debug(log1) log(func, tokenizer.ct.toString());
        current_symbol.set_info(["Value":tokenizer.ct.lexeme]);
        if(pass == 1)
        {
            symbols.add_symbol(current_symbol);
            if(last_method_symbol is null)
            {
                throw(new Exception("Tried to add a parameter to a non-existent method symbol\n"));
            }
            else
            {
                last_method_symbol.add_param(current_symbol.info["Symid"]);
            }
        }
        current_symbol = null;
        tokenizer.nextToken();

        if(check_token("symbol","["))
        {
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if(!check_token("symbol","]"))
            {
                gen_error(func);
            }
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }

        debug(log1) log(func, "End");
    }


    // variable_declaration::= 
    //     type #tExist identifier ["[" "]"] #vPush ["=" #oPush assignment_expression ] ";" #EOE 
    //     ;
    void variable_declaration()
    {
        string func = "variable_declaration";
        debug(log1) log(func, "Start");

        if((pass == 1 && !check_token(["type", "identifier", "class_name"])) || (pass == 2 && !check_token(["type", "class_name"])))
        {
            gen_error(func);
        }
        current_symbol = new Symbol();
        current_symbol.set_data(["Type":tokenizer.ct.lexeme, "accessMod":"private"]);

        if(pass == 2)
            SA.tPush();

        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        if(!check_token("identifier")) 
        {
            gen_error(func);
        }
        //current_symbol = new Symbol(_scope.join("."), "", tokenizer.ct.lexeme, "lvar", null);
        current_symbol.set_info(["Scope":_scope.join("."), "Kind":"lvar", "Value":tokenizer.ct.lexeme]);

        if(pass == 2)
            SA.tExist();

        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        if(check_token("symbol","["))
        {
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if(!check_token("symbol","]"))
            {
                gen_error(func);
            }
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            // This symbol is an array
            current_symbol.set_data(["Type":"@" ~ current_symbol.data["Type"]]);
        }

        // TODO:
        // SA.vPush uses current_symbol to look up in the symbol table what was put in during pass1.
        // This probably needs to be fixed
        if(pass == 1)
            symbols.add_symbol(current_symbol);
        if(pass == 2)
            SA.vPush();
        current_symbol = null;

        if(check_token("symbol","="))
        {
            debug(log1) log(func, tokenizer.ct.toString());
            if(pass == 2)
                SA.oPush();
            tokenizer.nextToken();
            assignment_expression();
        }

        if(!check_token("punctuation", ";")) 
        {
            gen_error(func);
        }
        if(pass == 2)
            SA.EOE();
        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        debug(log1) log(func, "End");
    }

    // statement::= "{" {statement} "}" 
    //     | expression ";" #EOE
    //     | "if" "(" #oPush expression ")" #) #if statement [ "else" statement ]
    //     | "while" "(" #oPush expression ")" #) #while statement
    //     | "return" [ expression ] ";" #EOE #return
    //     | "cout" "<<" expression ";" #EOE #cout
    //     | "cin" ">>" expression ";" #EOE #cin
    //     ;
    void statement()
    {
        string func = "statement";
        debug(log1) log(func, "Start");

        if(check_token("symbol", "{")) 
        {
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            while(!check_token("symbol", "}")) 
            {
                statement();
            }
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }
        //     | expression ";" #EOE
        else if
        (
            check_token("symbol", ["(", "+", "-"]) || 
            check_token("keyword", ["true", "false", "null"]) ||
            // TODO numeric_literal fix
            check_token(["number", "character_literal"]) ||
            check_token("identifier")
        )
        {
            expression();
            if(!check_token("punctuation", ";"))
            {
                gen_error(func, format("Expected ';', but got '%s'", tokenizer.ct.lexeme));
            }
            if(pass == 2)
                SA.EOE();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }
        //     | "if" "(" #oPush expression ")" #) #if statement [ "else" statement ]
        else if(check_token("keyword", "if"))
        {
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if(!check_token("symbol","("))
            {
                gen_error(func);
            }
            if(pass == 2)
                SA.oPush();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            expression();

            if(!check_token("symbol",")"))
            {
                gen_error(func);
            }

            string if_label;
            if(pass == 2)
            {
                SA.cParen();
                if_label = icode.gen_label("SKIPIF");
                SA._if(if_label);
            }
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            statement();


            if(check_token("keyword", "else"))
            {
                debug(log1) log(func, tokenizer.ct.toString());
                tokenizer.nextToken();

                string else_label;
                if(pass == 2)
                {
                    else_label = icode.gen_label("ENDELSE");
                    icode.add(["JMP", else_label, "", ""]);
                    icode.set_label(if_label);
                }

                statement();
                if(pass == 2)
                    icode.set_label(else_label);
            }
            else
            {
                if(pass == 2)
                    icode.set_label(if_label);
            }
        }
        //     | "while" "(" #oPush expression ")" #) #while statement
        else if(check_token("keyword", "while"))
        {
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if(!check_token("symbol","("))
            {
                gen_error(func);
            }
            string while_label;
            string endwhile_label;
            if(pass == 2)
            {
                while_label = icode.gen_label("WHILE");
                endwhile_label = icode.gen_label("ENDWH");
                icode.set_label(while_label);
                SA.oPush();
            }
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            expression();

            if(!check_token("symbol",")"))
            {
                gen_error(func);
            }
            if(pass == 2)
            {
                SA.cParen();
                SA._while(endwhile_label);
            }
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            statement();

            if(pass == 2)
            {
                icode.add(["JMP", while_label, "", ""]);
                icode.set_label(endwhile_label);
            }
        }
        //     | "return" [ expression ] ";" #EOE #return
        else if(check_token("keyword", "return"))
        {
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if(
                check_token("symbol", ["(", "+", "-"]) || 
                check_token("keyword", ["true", "false", "null"]) || 
                // TODO numeric_literal fix
                check_token(["number", "character_literal"]) || 
                check_token("identifier")
                ) 
            {
                expression(); 
            }
            else
            {
                if(pass == 2)
                    SAS.push(new var_sar(
                        "null",
                        "null",
                        "null"));
            }
            if(!check_token("punctuation", ";"))
            {
                gen_error(func, format("Expected ';', but got '%s'", tokenizer.ct.lexeme));
            }
            if(pass == 2)
                SA.EOE();
            if(pass == 2)
                SA._return();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }
        //     | "cin" ">>" expression ";" #EOE #cin
        else if(check_token("keyword", "cout"))
        {
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if(!check_token("symbol", "<<"))
            {
                gen_error(func, format("Expected '<<', but got '%s'", tokenizer.ct.lexeme));
            }
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            expression();
            if(!check_token("punctuation", ";"))
            {
                gen_error(func, format("Expected ';', but got '%s'", tokenizer.ct.lexeme));
            }
            if(pass == 2)
                SA.EOE();
            if(pass == 2)
                SA._cout();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }
        //     | "cout" "<<" expression ";" #EOE #cout
        else if(check_token("keyword", "cin"))
        {
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if(!check_token("symbol", ">>"))
            {
                gen_error(func);
            }
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            
            expression();
            if(!check_token("punctuation", ";"))
            {
                gen_error(func);
            }
            if(pass == 2)
                SA.EOE();
            if(pass == 2)
                SA._cin();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }


        debug(log1) log(func, "End");
    }

    // field_declaration::= 
    //      ["[" "]"] #vPush ["=" #oPush assignment_expression ] ";" #EOE 
    //     | "(" [parameter_list] ")" method_body
    //     ;
    void field_declaration()
    {
        string func = "field_declaration";
        debug(log1) log(func, "Start");

        if(check_token("symbol", ["[", "="]) || check_token("punctuation", ";"))
        {
            current_symbol.set_info(["Kind":"ivar"]);
            if(check_token("symbol","["))
            {
                debug(log1) log(func, tokenizer.ct.toString());
                tokenizer.nextToken();

                if(!check_token("symbol","]"))
                {
                    gen_error(func);
                }
                debug(log1) log(func, tokenizer.ct.toString());
                tokenizer.nextToken();
                // This symbol is an array
                current_symbol.set_data(["Type":"@" ~ current_symbol.data["Type"]]);
            }

            // TODO:
            // SA.vPush uses current_symbol to look up in the symbol table what was put in during pass1.
            // This probably needs to be fixed
            if(pass == 1)
                symbols.add_symbol(current_symbol);
            if(pass == 2)
                SA.vPush();
            current_symbol = null;

            if(check_token("symbol","="))
            {
                debug(log1) log(func, tokenizer.ct.toString());
                tokenizer.nextToken();

                if(pass == 2)
                    SA.oPush();

                assignment_expression();
            }

            if(!check_token("punctuation", ";"))
            {
                gen_error(func);
            }

            if(pass == 2)
                SA.EOE();

            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

        }
        else if(check_token("symbol", "("))
        {
            current_symbol.set_data(["returnType":current_symbol.data.get("Type", "void")]);
            current_symbol.data.remove("Type");
            current_symbol.set_info(["Kind":"method", "Type":""]);

            _scope ~= current_symbol.info.get("Value", "Error");

            if(pass == 1)
                symbols.add_symbol(current_symbol);
            last_method_symbol = current_symbol;
            current_symbol = null;

            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            parameter_list();

            if(!check_token("symbol", ")"))
            {
                gen_error(func, format("Expected \")\" and got \"%s\"", tokenizer.ct.lexeme));
            }
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            last_method_symbol = null;

            method_body();

            _scope = _scope[0..$-1];
        }
        else
        {
            gen_error(func);
        }

        debug(log1) log(func, "End");
    }

    // expression::= 
    //       "(" #oPush expression ")" #) [ expressionz ]
    //     | "true" #lPush [ expressionz ]
    //     | "false" #lPush [ expressionz ]
    //     | "null" #lPush [ expressionz ]
    //     | numeric_literal [ expressionz ]
    //     | character_literal [ expressionz ]
    //     | identifier #iPush [ fn_arr_member ] #iExist [ member_refz ] [ expressionz ]
    //     ;
    void expression()
    {
        string func = "expression";
        debug(log1) log(func, "Start");

        //       "(" #oPush expression ")" #) [ expressionz ]
        if(check_token("symbol","("))
        {
            if(pass == 2)
                SA.oPush();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            expression();
            if(!check_token("symbol",")"))
            {
                gen_error(func);
            }
            if(pass == 2)
                SA.cParen();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if(check_token("symbol", [ "=", "&&", "||", "==", "!=", "<=", ">=", "<", ">", "+", "-", "*", "/" ]))
            {
                expressionz();
            }
        }
        //     | "true" #lPush [ expressionz ]
        //     | "false" #lPush [ expressionz ]
        //     | "null" #lPush [ expressionz ]
        else if(check_token("keyword", ["true", "false", "null"]))
        {
            if(pass == 2)
                SA.lPush();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if(check_token("symbol", [ "=", "&&", "||", "==", "!=", "<=", ">=", "<", ">", "+", "-", "*", "/" ]))
            {
                expressionz();
            }
        }
        // TODO numeric_literal fix
        //     | numeric_literal [ expressionz ]
        else if(check_token("number") || check_token("symbol", ["+", "-"]))
        {
            string sign = "+";
            if(check_token("symbol"))
            {
                sign = tokenizer.ct.lexeme;
                debug(log1) log(func, tokenizer.ct.toString());
                tokenizer.nextToken();
            }
            if(pass == 2)
                SA.lPush(sign);
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if(check_token("symbol", [ "=", "&&", "||", "==", "!=", "<=", ">=", "<", ">", "+", "-", "*", "/" ]))
            {
                expressionz();
            }
        }
        //     | character_literal [ expressionz ]
        else if(check_token("character_literal"))
        {
            if(pass == 2)
                SA.lPush();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if(check_token("symbol", [ "=", "&&", "||", "==", "!=", "<=", ">=", "<", ">", "+", "-", "*", "/" ]))
            {
                expressionz();
            }
        }
        //     | identifier #iPush [ fn_arr_member ] #iExist [ member_refz ] [ expressionz ]
        else if(check_token("identifier"))
        {
            if(pass == 2)
                SA.iPush();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if(check_token("symbol", ["(", "["]))
            {
                fn_arr_member();
            }
            if(pass == 2)
                SA.iExist();
            if(check_token("punctuation", "."))
            {
                member_refz();
            }
            if(check_token("symbol", [ "=", "&&", "||", "==", "!=", "<=", ">=", "<", ">", "+", "-", "*", "/" ]))
            {
                expressionz();
            }
        }

        debug(log1) log(func, "End");
    }

    // fn_arr_member::= 
    //       "(" #oPush #BAL [ argument_list ] ")" #) #EAL #func 
    //     | "[" #oPush expression "]" #] #arr
    //     ;
    void fn_arr_member()
    {
        string func = "fn_arr_member";
        debug(log1) log(func, "Start");

        if(check_token("symbol", "("))
        {
            if(pass == 2)
                SA.oPush();
            if(pass == 2)
                SA.BAL();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            argument_list();

            if(pass == 2)
                SA.cParen();
            if(pass == 2)
                SA.EAL();
            if(pass == 2)
                SA.func();

            if(!check_token("symbol", ")"))
            {
                gen_error(func);
            }
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }
        else if(check_token("symbol", "["))
        {
            if(pass == 2)
                SA.oPush();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            expression();

            if(!check_token("symbol", "]"))
            {
                gen_error(func);
            }
            if(pass == 2)
                SA.cBrack();
            if(pass == 2)
                SA.arr();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }
        else
        {
            gen_error(func);
        }

        debug(log1) log(func, "End");
    }

    // argument_list::= 
    //     expression { "," #, expression } 
    //     ;
    void argument_list()
    {
        string func = "argument_list";
        debug(log1) log(func, "Start");

        expression();

        while(check_token("punctuation", ","))
        {
            if(pass == 2)
                SA.comma();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            expression();
        }
        debug(log1) log(func, "Done with arguments, no more commas");

        debug(log1) log(func, "End");
    }

    // member_refz::= 
    //     "." identifier #iPush [ fn_arr_member ] #rExist [ member_refz ] 
    //     ;
    void member_refz()
    {
        string func = "member_refz";
        debug(log1) log(func, "Start");

        if(!check_token("punctuation", "."))
        {
            gen_error(func);
        }
        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        if(!check_token("identifier"))
        {
            gen_error(func);
        }
        if(pass == 2)
            SA.iPush();
        debug(log1) log(func, tokenizer.ct.toString());
        tokenizer.nextToken();

        if(check_token("symbol", "("))
        {
            fn_arr_member();
        }
        if(pass == 2)
            SA.rExist();
        if(check_token("punctuation", "."))
        {
            member_refz();
        }

        debug(log1) log(func, "End");
    }


    // expressionz::=
    //       "="  #oPush assignment_expression 
    //     | "&&" #oPush expression       /* logical connective expression */
    //     | "||" #oPush expression       /* logical connective expression */
    //     | "==" #oPush expression       /* boolean expression */
    //     | "!=" #oPush expression       /* boolean expression */
    //     | "<=" #oPush expression       /* boolean expression */
    //     | ">=" #oPush expression       /* boolean expression */
    //     | "<"  #oPush expression       /* boolean expression */
    //     | ">"  #oPush expression       /* boolean expression */
    //     | "+"  #oPush expression       /* mathematical expression */
    //     | "-"  #oPush expression       /* mathematical expression */
    //     | "*"  #oPush expression       /* mathematical expression */
    //     | "/"  #oPush expression       /* mathematical expression */
    //     ;
    void expressionz()
    {
        string func = "expressionz";
        debug(log1) log(func, "Start");

        if(check_token("symbol"))
        {
            if(check_token("symbol", "="))
            {
                if(pass == 2)
                    SA.oPush();
                debug(log1) log(func, tokenizer.ct.toString());
                tokenizer.nextToken();

                assignment_expression();
            } else if (check_token("symbol", ["&&", "||", "==", "!=", "<=", ">=", "<", ">", "+", "-", "*", "/"]))
            {
                if(pass == 2)
                    SA.oPush();
                debug(log1) log(func, tokenizer.ct.toString());
                tokenizer.nextToken();

                expression();
            }
            else
            {
                gen_error(func);
            }
        }
        else
        {
            gen_error(func);
        }

        debug(log1) log(func, "End");
    }

    // assignment_expression::= 
    //      expression
    //    | "this"
    //    | "new" type new_declaration
    //    | "atoi" "(" #oPush expression ")" #) #atoi
    //    | "itoa" "(" #oPush expression ")" #) #itoa
    //    ;
    void assignment_expression()
    {
        string func = "assignment_expression";
        debug(log1) log(func, "Start");

        //      expression
        if
        (
            check_token("symbol", ["(", "+", "-"]) ||
            check_token("keyword", ["true", "false", "null"]) ||
            // TODO numeric_literal fix
            check_token("number") ||
            check_token("character_literal") ||
            check_token("identifier")
        )
        {
            expression();
        }
        //    | "this"
        else if(check_token("keyword", "this"))
        {
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }
        //    | "new" type new_declaration
        else if(check_token("keyword", "new"))
        {
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            if((pass == 1 && !check_token(["type", "identifier", "class_name"])) || (pass == 2 && !check_token(["type", "class_name"])))
            {
                gen_error(func);
            }
            if(pass == 2)
                SA.tPush();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
            new_declaration();
        }
        //    | "atoi" "(" #oPush expression ")" #) #atoi
        else if(check_token("keyword", "atoi"))
        {
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            if(!check_token("symbol","("))
            {
                gen_error(func);
            }
            if(pass == 2)
                SA.oPush();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            expression();

            if(!check_token("symbol",")"))
            {
                gen_error(func);
            }
            if(pass == 2)
                SA.cParen();
            if(pass == 2)
                SA._atoi();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }
        //    | "itoa" "(" #oPush expression ")" #) #itoa
        else if(check_token("keyword", "itoa"))
        {
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            if(!check_token("symbol","("))
            {
                gen_error(func);
            }
            if(pass == 2)
                SA.oPush();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            expression();

            if(!check_token("symbol",")"))
            {
                gen_error(func);
            }
            if(pass == 2)
                SA.cParen();
            if(pass == 2)
                SA._itoa();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }
        else
        {
            gen_error(func);
        }

        debug(log1) log(func, "End");
    }

    // new_declaration::= 
    //       "(" #oPush #BAL [ argument_list ] ")" #) #EAL  #newObj 
    //     | "[" #oPush expression "]" #] #new[]
    //     ;
    void new_declaration()
    {
        string func = "new_declaration";
        debug(log1) log(func, "Start");

        if(check_token("symbol","("))
        {
            if(pass == 2)
                SA.oPush();
            if(pass == 2)
                SA.BAL();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            // argument_list starts with an expression, which can be a lot of things
            // TODO numeric_literal fix
            if(check_token(["identifier", "character_literal", "number"]) || check_token("symbol", ["(", "+", "-"]) || check_token("keyword", ["null", "true", "false"]))
            {
                argument_list();
            }

            if(!check_token("symbol", ")"))
            {
                gen_error(func);
            }
            if(pass == 2)
                SA.cParen();
            if(pass == 2)
                SA.EAL();
            if(pass == 2)
                SA.newObj();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }
        else if(check_token("symbol","["))
        {
            if(pass == 2)
                SA.oPush();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();

            expression();

            if(!check_token("symbol", "]"))
            {
                gen_error(func);
            }
            if(pass == 2)
                SA.cBrack();
            if(pass == 2)
                SA.newArr();
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }
        else
        {
            gen_error(func);
        }
        debug(log1) log(func, "End");
    }

public:
    this(Tokenizer tokenizer) 
    {
        this.tokenizer = tokenizer;
        symbols = new SymbolTable;
        SAS = new SemanticActionStack;
        OS = new OperatorStack;
        SA = new SemanticAction;
        icode = new Icode;
    }

    int pass;

    void run() 
    {
        pass = 1;
        debug(log9) stderr.writef("Lexial/Syntax\n");
        _scope ~= "g";
        string func = "run";
        debug(log1) log(func, "Start");
        compilation_unit();
        while(!check_token("EOT"))
        {
            gen_error(func);
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }
        debug(log1) log(func, "End");
        debug(log1) stderr.writef("Completed Pass 1\n");
        debug(log0) print_symbols();

        enforce(errors == 0, format("Errors encountered: [%d]", errors));

        debug(log1) stderr.writef("Starting Pass 2\n");
        tokenizer.rewind();
        _scope.length = 0;

        pass = 2;
        debug(log9) stderr.writef("Semantics/ICode\n");
        _scope ~= "g";
        debug(log1) log(func, "Start");
        compilation_unit();
        while(!check_token("EOT"))
        {
            gen_error(func);
            debug(log1) log(func, tokenizer.ct.toString());
            tokenizer.nextToken();
        }
        debug(log1)
        {
            log(func, "End");
            log(func, format("Still have SAS.length of [%d]", SAS.length));
            log(func, format("Still have OS.length of [%d]", OS.length));
            log(func, format("Errors encountered: [%d]", errors));
        }
        enforce(errors == 0, format("Errors encountered: [%d]", errors));
        debug(log0) print_symbols();

        debug(log5) icode.output(stderr);
        debug(log9) stderr.writef("Tcode start\n");
        tcode = new Tcode(icode.data, icode.labels, symbols);
        debug(log9) stderr.writef("Done\n");
    }

    void tcode_gen(File outf)
    {
        //auto outf = File("simple.asm", "w+");
        //tcode.output(stdout);
        tcode.output(outf);
    }

    void print_symbols()
    {
        symbols.print_symbols();
    }
}

