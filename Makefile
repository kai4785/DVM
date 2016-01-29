# Virtual Machine Make file for CS-4380
# I've decided to throw away my sanity, and try to do this in D
# And also write code that works on both Windows and Linux

COMPILER = dmd

# Differentiate between a Linux and Windows build
ifeq (${windir},)
  RM = rm -f
  BIN_EXT = 
  OBJ_EXT = o
else
  RM = del
  BIN_EXT = .exe
  OBJ_EXT = obj
endif

release: DFLAGS = -release -O -inline -L-lrt
release: all
debug: DFLAGS = -g -wi -debug -L-lrt
debug: all
profile: DFLAGS = -wi -profile -L-lrt
profile: all
unittest: DFLAGS = -debug -unittest -L-lrt
unittest: all

Compiler.${OBJ_EXT}: Compiler.d
	${COMPILER} ${DFLAGS} Compiler.d -c -ofCompiler.${OBJ_EXT}

Assembler.${OBJ_EXT}: Assembler.d Utilities.d
	${COMPILER} ${DFLAGS} Assembler.d -c -ofAssembler.${OBJ_EXT}

Utilities.${OBJ_EXT}: Utilities.d
	${COMPILER} ${DFLAGS} Utilities.d -c -ofUtilities.${OBJ_EXT}

VirtualMachine.${OBJ_EXT}: VirtualMachine.d Utilities.d Assembler.d
	${COMPILER} ${DFLAGS} VirtualMachine.d -c -ofVirtualMachine.${OBJ_EXT}

OperatingSystem.${OBJ_EXT}: OperatingSystem.d VirtualMachine.d FileSystem.d Utilities.d
	${COMPILER} ${DFLAGS} OperatingSystem.d -c -ofOperatingSystem.${OBJ_EXT}

FileSystem.${OBJ_EXT}: FileSystem.d Utilities.d
	${COMPILER} ${DFLAGS} FileSystem.d -c -ofFileSystem.${OBJ_EXT}

cm.${OBJ_EXT}: cm.d Compiler.d Utilities.d
	${COMPILER} ${DFLAGS} cm.d -c -ofcm.${OBJ_EXT}

cm${BIN_EXT}: cm.${OBJ_EXT} Compiler.${OBJ_EXT} Utilities.${OBJ_EXT}
	${COMPILER} ${DFLAGS} cm.${OBJ_EXT} Compiler.${OBJ_EXT} Utilities.${OBJ_EXT} -ofcm${BIN_EXT}

as.${OBJ_EXT}: as.d Assembler.d
	${COMPILER} ${DFLAGS} as.d -c -ofas.${OBJ_EXT}

as${BIN_EXT}: as.${OBJ_EXT} Utilities.${OBJ_EXT} Assembler.${OBJ_EXT}
	${COMPILER} ${DFLAGS} as.${OBJ_EXT} Utilities.${OBJ_EXT} Assembler.${OBJ_EXT} -ofas${BIN_EXT}

os.${OBJ_EXT}: os.d OperatingSystem.d
	${COMPILER} ${DFLAGS} os.d -c -ofos.${OBJ_EXT}

os${BIN_EXT}: os.${OBJ_EXT} OperatingSystem.${OBJ_EXT} FileSystem.${OBJ_EXT} VirtualMachine.${OBJ_EXT} Assembler.${OBJ_EXT} Utilities.${OBJ_EXT}
	${COMPILER} ${DFLAGS} os.${OBJ_EXT} OperatingSystem.${OBJ_EXT} FileSystem.${OBJ_EXT} VirtualMachine.${OBJ_EXT} Assembler.${OBJ_EXT} Utilities.${OBJ_EXT} -ofos${BIN_EXT}

fs.${OBJ_EXT}: fs.d FileSystem.d Utilities.d
	${COMPILER} ${DFLAGS} fs.d -c -offs.${OBJ_EXT}

fs${BIN_EXT}: fs.${OBJ_EXT} FileSystem.${OBJ_EXT} Utilities.${OBJ_EXT}
	${COMPILER} ${DFLAGS} fs.${OBJ_EXT} FileSystem.${OBJ_EXT} Utilities.${OBJ_EXT} -offs${BIN_EXT}

all: cm${BIN_EXT} as${BIN_EXT} os${BIN_EXT} fs${BIN_EXT}

clean:
	${RM} *.o *.map *.obj *.hex cm${BIN_EXT} as${BIN_EXT} os${BIN_EXT} fs${BIN_EXT}
