# Bela
# Low-latency, real-time audio and sensor processing on BeagleBone Black
# (c) 2016 Andrew McPherson, Victor Zappi, Giulio Moro, Liam Donovan
# Centre for Digital Music, Queen Mary University of London

## This Makefile is intended for use on the BeagleBone Black itself #
## and not for cross-compiling #
## available command line options: #
## EXAMPLE=             -- name of the folder in examples/ to be copied to projects/ and built
## PROJECT=             -- name of the folder in projects/ to be built
## CL=                  -- list of command line options to pass to the program when running
## CPPFLAGS=           -- list of additional flags passed to the C++ compiler
## CFLAGS=             -- list of additional flags passed to the C compiler
## COMPILER=            -- compiler to use (clang or gcc)
## LDFLAGS=                -- linker flags (e.g.: -L. ) 
## LDLIBS=                -- libs to link in (e.g.: -lm )
## AT=                  -- used instead of @ to silence the output. Defaults AT=@, use AT= for a very verbose output
###
##available targets: #
.DEFAULT_GOAL := Bela

AT?=@
NO_PROJECT_TARGETS=help coreclean distclean stop nostartup connect idestart idestop idestartup idenostartup ideconnect scsynthstart scsynthstop scsynthconnect scsynthstartup scsynthnostartup update checkupdate updateunsafe lib libbela.so 
NO_PROJECT_TARGETS_MESSAGE=PROJECT or EXAMPLE should be set for all targets except: $(NO_PROJECT_TARGETS)
# list of targets that automatically activate the QUIET=true flag
QUIET_TARGETS=runide

# Type `$ make help` to get a description of the functionalities of this Makefile.
help: ## Show this help
	$(AT) echo 'Usage: make [target] CL=[command line options] [PROJECT=[projectName] | EXAMPLE=[exampleName]]'
	$(AT) printf "\n$(NO_PROJECT_TARGETS_MESSAGE)\n\n"
	$(AT) echo 'Targets: (default: $(.DEFAULT_GOAL))'
	$(AT) echo list: $(MAKEFILE_LIST)
	$(AT) fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/^\(.*\): .*##\(.*\)/\1:#\2/' | sed -e 's/^\(.*\)= .* -- \(.*\)/\1=#\2/' | sed 's/^##//' | awk -F"#" '{ printf "%-18s %-1s\n", $$1, $$2}' 

# PROJECT or EXAMPLE must be set for targets that are not included in NO_PROJECT_TARGETS
ifeq (,$(filter $(NO_PROJECT_TARGETS),$(MAKECMDGOALS)))
  ifndef PROJECT
    ifndef EXAMPLE
      $(error $(NO_PROJECT_TARGETS_MESSAGE))
    endif
  endif
endif

# if we are building an example, just copy it to the projects/ folder
# and then treat it as a project
ifdef EXAMPLE
  #you can alternatively specify PROJECT= along with EXAMPLE=
  PROJECT?=exampleTempProject
  PROJECT_DIR?=$(abspath projects/$(PROJECT))
  $(shell mkdir -p $(abspath projects))
  $(shell rm -rf $(PROJECT_DIR))
  $(shell cp -r examples/$(EXAMPLE) $(PROJECT_DIR))
else
  PROJECT_DIR := $(abspath projects/$(PROJECT))
endif


ifdef PROJECT

#check if project dir exists
CHECK_PROJECT_DIR_EXIST=$(shell stat $(PROJECT_DIR))
ifeq ($(CHECK_PROJECT_DIR_EXIST),)
$(error $(PROJECT_DIR) does not exist)
endif
SHOULD_BUILD=true
PROJECT_TYPE=invalid
RUN_FILE?=$(PROJECT_DIR)/run.sh
SUPERCOLLIDER_FILE=$(PROJECT_DIR)/_main.scd
LIBPD_FILE=$(PROJECT_DIR)/_main.pd
HAS_RUN_FILE=false

FILE_LIST:= $(wildcard $(PROJECT_DIR)/*)
ifeq ($(filter $(RUN_FILE),$(FILE_LIST)),$(RUN_FILE))
SHOULD_BUILD=false
HAS_RUN_FILE=true
PROJECT_TYPE=custom
endif
ifeq ($(filter $(SUPERCOLLIDER_FILE),$(FILE_LIST)),$(SUPERCOLLIDER_FILE))
PROJECT_TYPE=sc
SHOULD_BUILD=false
else
ifeq ($(filter $(LIBPD_FILE),$(FILE_LIST)),$(LIBPD_FILE))
PROJECT_TYPE=libpd
else
ifneq ($(filter %.c %.cpp %.cc,$(FILE_LIST)),)
PROJECT_TYPE=cpp
endif
endif
endif

ifeq ($(AT),)
$(info Automatically detected PROJECT_TYPE: $(PROJECT_TYPE) )
endif


ifeq ($(PROJECT_TYPE),invalid)
ifeq ($(HAS_RUN_FILE),false)
$(error Invalid/empty project. A project needs to have at least one .cpp or .c or .cc or $(notdir $(LIBPD_FILE)) or $(notdir $(SUPERCOLLIDER_FILE)) or $(notdir $(RUN_FILE)) file )
endif
endif

ifeq ($(SHOULD_BUILD),true)
#create build directories
$(shell mkdir -p $(PROJECT_DIR)/build build/core )
endif

endif # ifdef PROJECT

OUTPUT_FILE?=$(PROJECT_DIR)/$(PROJECT)
COMMAND_LINE_OPTIONS?=$(CL)
RUN_FROM?=$(PROJECT_DIR)
ifeq ($(HAS_RUN_FILE),true)
RUN_COMMAND?=bash $(RUN_FILE)
else
ifeq ($(PROJECT_TYPE),sc)
RUN_COMMAND?=sclang $(SUPERCOLLIDER_FILE)
else
RUN_COMMAND?=$(OUTPUT_FILE) $(COMMAND_LINE_OPTIONS)
endif
endif
RUN_IDE_COMMAND?=PATH=$$PATH:/usr/local/bin/ stdbuf -i0 -o0 -e0 $(RUN_COMMAND)
BELA_STARTUP_SCRIPT?=/root/Bela_startup.sh
BELA_AUDIO_THREAD_NAME?=bela-audio 
SCREEN_NAME?=Bela
BELA_IDE_STARTUP_SCRIPT?=/root/Bela_node.sh
BELA_IDE_HOME?=/root/Bela/IDE
# A bug in this version of screen forces us to use two screen names which beginning substrings do not match (Bela, Bela-IDE would cause problems)
BELA_IDE_SCREEN_NAME?=IDE-Bela
BELA_IDE_RUN_COMMAND?=cd $(BELA_IDE_HOME) && export USER=root && export HOME=/root && export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin && screen -S $(BELA_IDE_SCREEN_NAME) -d -m bash -c "while true; do /usr/local/bin/node index.js; sleep 0.5; done"
BELA_IDE_STOP_COMMAND?=screen -X -S $(BELA_IDE_SCREEN_NAME) quit > /dev/null 

SC_CL?=-u 57110 -z 16 -J 8 -K 8 -G 16 -i 2 -o 2

ifneq (,$(filter $(QUIET_TARGETS),$(MAKECMDGOALS)))
  QUIET=true
endif
QUIET?=false

RM := rm -rf
STATIC_LIBS := ./lib/libprussdrv.a ./lib/libNE10.a ./lib/libmathneon.a
LIBS = -lrt -lnative -lxenomai -lsndfile -lasound 

# refresh library cache and check if libpd is there
#TEST_LIBPD := $(shell ldconfig; ldconfig -p | grep "libpd\.so")  # safest but slower way of checking
LIBPD_PATH = /usr/lib/libpd.so
TEST_LIBPD := $(shell [ -e $(LIBPD_PATH) ] && echo yes)
ifneq ($(strip $(TEST_LIBPD)), )
# if libpd is there, link it in
  LIBS += -lpd -lpthread_rt
endif
INCLUDES := -I$(PROJECT_DIR) -I./include -I/usr/include/ne10 -I/usr/xenomai/include -I/usr/arm-linux-gnueabihf/include/xenomai/include 
DEFAULT_COMMON_FLAGS := -O3 -march=armv7-a -mtune=cortex-a8 -mfloat-abi=hard -mfpu=neon -ftree-vectorize -ffast-math -DNDEBUG
DEFAULT_CPPFLAGS := $(DEFAULT_COMMON_FLAGS) -std=c++11
DEFAULT_CFLAGS := $(DEFAULT_COMMON_FLAGS) -std=gnu11

ifndef COMPILER
# check whether clang is installed
  TEST_COMPILER := $(shell which clang)
  ifneq ($(strip $(TEST_COMPILER)), )
    #if it is installed, use it
    COMPILER := clang
	CLANG_PATH:=$(TEST_COMPILER)
  else
    # just in case the PATH is broken, check for the full path to clang
	# this is a workaround for people with old IDE startup script (without /usr/local/bin in the $PATH)
    CLANG_PATH:=/usr/local/bin/clang
    TEST_COMPILER := $(shell [ -e $(CLANG_PATH) ] && echo yes)
    ifneq ($(strip $(TEST_COMPILER)), )
      COMPILER := clang
    else
      COMPILER := gcc
	endif
  endif
endif

ifeq ($(COMPILER), clang)
  CC=$(CLANG_PATH)
  CXX=$(CLANG_PATH)++
  DEFAULT_CPPFLAGS += -no-integrated-as
  DEFAULT_CFLAGS += -no-integrated-as
else 
  ifeq ($(COMPILER), gcc)
    CC=gcc
    CXX=g++
  endif
endif

ALL_DEPS=
ASM_SRCS := $(wildcard $(PROJECT_DIR)/*.S)
ASM_OBJS := $(addprefix $(PROJECT_DIR)/build/,$(notdir $(ASM_SRCS:.S=.o)))
ALL_DEPS += $(addprefix $(PROJECT_DIR)/build/,$(notdir $(ASM_SRCS:.S=.d)))

P_SRCS := $(wildcard $(PROJECT_DIR)/*.p)
P_OBJS := $(addprefix $(PROJECT_DIR)/,$(notdir $(P_SRCS:.p=_bin.h)))

C_SRCS := $(wildcard $(PROJECT_DIR)/*.c)
C_OBJS := $(addprefix $(PROJECT_DIR)/build/,$(notdir $(C_SRCS:.c=.o)))
ALL_DEPS += $(addprefix $(PROJECT_DIR)/build/,$(notdir $(C_SRCS:.c=.d)))

CPP_SRCS := $(wildcard $(PROJECT_DIR)/*.cpp)
CPP_OBJS := $(addprefix $(PROJECT_DIR)/build/,$(notdir $(CPP_SRCS:.cpp=.o)))
ALL_DEPS += $(addprefix $(PROJECT_DIR)/build/,$(notdir $(CPP_SRCS:.cpp=.d)))

PROJECT_OBJS := $(P_OBJS) $(ASM_OBJS) $(C_OBJS) $(CPP_OBJS)

# Core Bela sources
CORE_C_SRCS = $(wildcard core/*.c)
CORE_OBJS := $(addprefix build/core/,$(notdir $(CORE_C_SRCS:.c=.o)))
ALL_DEPS += $(addprefix build/core/,$(notdir $(CORE_C_SRCS:.c=.d)))

CORE_CPP_SRCS = $(filter-out core/default_main.cpp core/default_libpd_render.cpp, $(wildcard core/*.cpp))
CORE_OBJS := $(CORE_OBJS) $(addprefix build/core/,$(notdir $(CORE_CPP_SRCS:.cpp=.o)))
CORE_CORE_OBJS := build/core/RTAudio.o build/core/PRU.o build/core/RTAudioCommandLine.o build/core/I2c_Codec.o build/core/math_runfast.o build/core/GPIOcontrol.o
EXTRA_CORE_OBJS := $(filter-out $(CORE_CORE_OBJS), $(CORE_OBJS))
ALL_DEPS += $(addprefix build/core/,$(notdir $(CORE_CPP_SRCS:.cpp=.d)))

CORE_ASM_SRCS := $(wildcard core/*.S)
CORE_ASM_OBJS := $(addprefix build/core/,$(notdir $(CORE_ASM_SRCS:.S=.o)))
ALL_DEPS += $(addprefix build/core/,$(notdir $(CORE_ASM_SRCS:.S=.d)))

# Objects for a system-supplied default main() file, if the user
# only wants to provide the render functions.
DEFAULT_MAIN_CPP_SRCS := ./core/default_main.cpp
DEFAULT_MAIN_OBJS := ./build/core/default_main.o
ALL_DEPS += ./build/core/default_main.d

# Objects for a system-supplied default render() file for libpd projects,
# if the user only wants to provide the Pd files.
DEFAULT_PD_CPP_SRCS := ./core/default_libpd_render.cpp
DEFAULT_PD_OBJS := ./build/core/default_libpd_render.o
ALL_DEPS += ./build/core/default_libpd_render.d

Bela: ## Builds the Bela program with all the optimizations
Bela: $(OUTPUT_FILE)

# all = build Bela 
all: ## Same as Bela
all: SYNTAX_FLAG :=
all: Bela

# debug = buildBela debug
debug: ## Same as Bela but with debug flags and no optimizations
debug: DEFAULT_CPPFLAGS=-g -std=c++11
debug: DEFAULT_CFLAGS=-g -std=c11
debug: all

# include all dependencies - necessary to force recompilation when a header is changed
# (had to remove -MT"$(@:%.o=%.d)" from compiler call for this to work)
-include $(ALL_DEPS)

# syntax = check syntax
syntax: ## Only checks syntax
syntax: SYNTAX_FLAG := -fsyntax-only
syntax: $(PROJECT_OBJS) 

# Rule for Bela core C files
build/core/%.o: ./core/%.c
	$(AT) echo 'Building $(notdir $<)...'
#	$(AT) echo 'Invoking: C++ Compiler $(CXX)'
	$(AT) $(CC) $(SYNTAX_FLAG) $(INCLUDES) $(DEFAULT_CFLAGS)  -Wa,-mimplicit-it=arm -Wall -c -fmessage-length=0 -U_FORTIFY_SOURCE -MMD -MP -MF"$(@:%.o=%.d)" -o "$@" "$<" $(CFLAGS) -fPIC
	$(AT) echo ' ...done'
	$(AT) echo ' '

# Rule for Bela core C++ files
build/core/%.o: ./core/%.cpp
	$(AT) echo 'Building $(notdir $<)...'
#	$(AT) echo 'Invoking: C++ Compiler $(CXX)'
	$(AT) $(CXX) $(SYNTAX_FLAG) $(INCLUDES) $(DEFAULT_CPPFLAGS) -Wall -c -fmessage-length=0 -U_FORTIFY_SOURCE -MMD -MP -MF"$(@:%.o=%.d)" -o "$@" "$<" $(CPPFLAGS) -fPIC
	$(AT) echo ' ...done'
	$(AT) echo ' '

# Rule for Bela core ASM files
build/core/%.o: ./core/%.S
	$(AT) echo 'Building $(notdir $<)...'
#	$(AT) echo 'Invoking: GCC Assembler'
	$(AT) as  -o "$@" "$<"
	$(AT) echo ' ...done'
	$(AT) echo ' '

# Rule for user-supplied C++ files
$(PROJECT_DIR)/build/%.o: $(PROJECT_DIR)/%.cpp
	$(AT) echo 'Building $(notdir $<)...'
#	$(AT) echo 'Invoking: C++ Compiler $(CXX)'
	$(AT) $(CXX) $(SYNTAX_FLAG) $(INCLUDES) $(DEFAULT_CPPFLAGS) -Wall -c -fmessage-length=0 -U_FORTIFY_SOURCE -MMD -MP -MF"$(@:%.o=%.d)" -o "$@" "$<" $(CPPFLAGS)
	$(AT) echo ' ...done'
	$(AT) echo ' '

# Rule for user-supplied C files
$(PROJECT_DIR)/build/%.o: $(PROJECT_DIR)/%.c
	$(AT) echo 'Building $(notdir $<)...'
#	$(AT) echo 'Invoking: C Compiler $(CC)'
	$(AT) $(CC) $(SYNTAX_FLAG) $(INCLUDES) $(DEFAULT_CFLAGS) -Wall -c -fmessage-length=0 -U_FORTIFY_SOURCE -MMD -MP -MF"$(@:%.o=%.d)" -o "$@" "$<" $(CFLAGS)
	$(AT) echo ' ...done'
	$(AT) echo ' '

# Rule for user-supplied assembly files
$(PROJECT_DIR)/build/%.o: $(PROJECT_DIR)/%.S
	$(AT) echo 'Building $(notdir $<)...'
#	$(AT) echo 'Invoking: GCC Assembler'
	$(AT) as  -o "$@" "$<"
	$(AT) echo ' ...done'
	$(AT) echo ' '

# Rule for user-supplied assembly files
$(PROJECT_DIR)/%_bin.h: $(PROJECT_DIR)/%.p
	$(AT) echo 'Building $(notdir $<)...'
	$(AT) echo 'Invoking: PRU Assembler'
	$(AT)#Note that pasm will most likely run during the syntax check and will actually generate the output ...
	$(AT)#check if pasm exists, skip otherwise. This provides (sort of)
	$(AT)#backwards compatibility in case pre-compiled header is available.
	$(AT)#pasm outputs to the same folder, so cd to the project folder before running it
	$(AT) if [ -z "`which pasm`" ]; then echo 'pasm not found, .p files not compiled.' 1>&2; else \
	      cd $(PROJECT_DIR) &&\
	      pasm "$<" -c >/dev/null && echo ' ...done'; fi
	$(AT) echo ' '


ifeq ($(SHOULD_BUILD),false)
# if it is a project that does not require build, there are no dependencies to compile, nor a binary to generate
$(OUTPUT_FILE):
else
# This is a nasty kludge: we want to be able to optionally link in a default
# main file if the user hasn't supplied one. We check for the presence of the main()
# function, and conditionally call one of two recursive make targets depending on whether
# we want to link in the default main file or not. The kludge is the mess of a shell script
# line below. Surely there's a better way to do this?
$(OUTPUT_FILE): $(CORE_ASM_OBJS) $(CORE_OBJS) $(PROJECT_OBJS) $(STATIC_LIBS) $(DEFAULT_MAIN_OBJS) $(DEFAULT_PD_OBJS)
	$(eval DEFAULT_MAIN_CONDITIONAL :=\
	    $(shell bash -c '[ `nm -C /dev/null $(PROJECT_OBJS) 2>/dev/null | grep -w T | grep -w main | wc -l` == '0' ] && echo "$(DEFAULT_MAIN_OBJS)" || : '))
ifeq ($(PROJECT_TYPE),libpd)
#If it is a libpd project AND there is no "render" symbol then link in the $(DEFAULT_PD_OBJS) 
	$(eval DEFAULT_PD_CONDITIONAL :=\
	    $(shell bash -c '{ [ `nm -C /dev/null $(PROJECT_OBJS) 2>/dev/null | grep -w T | grep "\<render\>" | wc -l` -eq 0 ]; } && echo '$(DEFAULT_PD_OBJS)' || : ' ))
endif
	$(AT) echo 'Linking...'
	$(AT) $(CXX) $(SYNTAX_FLAG) $(LDFLAGS) -L/usr/xenomai/lib -L/usr/arm-linux-gnueabihf/lib -L/usr/arm-linux-gnueabihf/lib/xenomai -L/usr/lib/arm-linux-gnueabihf -pthread -Wpointer-arith -o "$(PROJECT_DIR)/$(PROJECT)" $(CORE_ASM_OBJS) $(CORE_OBJS) $(DEFAULT_MAIN_CONDITIONAL) $(DEFAULT_PD_CONDITIONAL) $(ASM_OBJS) $(C_OBJS) $(CPP_OBJS) $(STATIC_LIBS) $(LIBS) $(LDLIBS)
	$(AT) echo ' ...done'
endif
# Other Targets:
projectclean: ## Remove the PROJECT's build objects & binary
	-$(RM) $(PROJECT_DIR)/build/* $(OUTPUT_FILE)
	-@echo ' '	

clean: ## Same as projectclean
clean: projectclean

coreclean: ## Remove the core's build objects
	-$(RM) build/core/*

prompt:
	$(AT) printf "Warning: you are about to DELETE the projects/ folder and its content. This operation cannot be undone. Continue? (y/N) "
	$(AT) read REPLY; if [ $$REPLY !=  y ] && [ $$REPLY != Y ]; then echo "Aborting..."; exit 1; fi
	
distclean: ## Restores the Bela folder to a pristine state: remove all the projects source and the built objects, including the core Bela objects.
distclean: prompt distcleannoprompt
	
distcleannoprompt: ## Same as distclean, but does not prompt for confirmation. Use with care.
	-$(RM) build/source/* $(CORE_OBJS) $(CORE_CPP_DEPS) $(DEFAULT_MAIN_OBJS) $(DEFAULT_MAIN_CPP_DEPS) $(OUTPUT_FILE)
	-@echo ' '

runfg: run
run: ## Run PROJECT in the foreground
run: stop Bela
	$(AT) echo "Running $(RUN_COMMAND)"
	$(AT) sync& cd $(RUN_FROM) && $(RUN_COMMAND)

runide: ## Run PROJECT for IDE (foreground, no buffering)
runide: stop Bela
	$(AT) sync& cd $(RUN_FROM) && $(RUN_IDE_COMMAND)
runscreen: ## Run PROJECT in the background (detached screen)
runscreen: stop $(OUTPUT_FILE)
	$(AT) echo "Running $(RUN_COMMAND) in a screen"
	$(AT) cd $(RUN_FROM) && screen -S $(SCREEN_NAME) -d -m $(RUN_COMMAND)
runscreenfg: ## Run PROJECT in a screen in the foreground (can detach with ctrl-a ctrl-d)
runscreenfg: stop $(OUTPUT_FILE)
	$(AT) echo "Running $(RUN_COMMAND) in a screen"
	$(AT) cd $(RUN_FROM) && screen -S $(SCREEN_NAME) -m $(RUN_COMMAND)

STARTUP_COMMAND=printf "\#!/bin/sh\n\#\n\# This file is autogenerated by Bela. Do not edit!\n\necho Running Bela...\nexport PATH=\"$$PATH:/usr/local/bin\"\n cd $(RUN_FROM) && screen -S $(SCREEN_NAME) -d -m %s $(RUN_COMMAND) %s\n"
nostartup: ## No Bela project runs at startup 
nostartup:
	$(AT) echo "Disabling Bela at startup..."
	$(AT) printf "#!/bin/sh\n#\n\n# This file is autogenerated by Bela. Do not edit!\n\n# Run on startup disabled -- nothing to do here\n" > $(BELA_STARTUP_SCRIPT)

startuploop: ## Makes PROJECT run at startup and restarts it if it crashes
startuploop: Bela
	$(AT) echo "Enabling Bela at startup in a loop..."
	$(AT) $(STARTUP_COMMAND) 'bash -c "while sleep 0.6 ; do echo Running Bela...;' '; done"' > $(BELA_STARTUP_SCRIPT)

startup: ## Makes PROJECT run at startup
startup: Bela
	$(AT) echo "Enabling Bela at startup..."
	$(AT) $(STARTUP_COMMAND) > $(BELA_STARTUP_SCRIPT)
	$(AT) chmod +x $(BELA_STARTUP_SCRIPT)

stop: ## Stops any Bela program that is currently running
stop:
	$(AT) PID=`grep $(BELA_AUDIO_THREAD_NAME) /proc/xenomai/stat | cut -d " " -f 5 | sed s/\s//g`; if [ -z $$PID ]; then [ $(QUIET) = true ] || echo "No process to kill"; else [  $(QUIET) = true  ] || echo "Killing old Bela process $$PID"; kill -2 $$PID; sleep 0.2; kill -9 $$PID 2> /dev/null; fi; screen -X -S $(SCREEN_NAME) quit > /dev/null; exit 0;
# take care of stale sclang / scsynth processes
ifeq ($(PROJECT_TYPE),sc)
#if we are about to start a sc project, these killall should be synchronous, otherwise they may kill they newly-spawn sclang process
	$(AT) killall scsynth 2>/dev/null; killall sclang 2>/dev/null; true
else
#otherwise, it safe if they are asynchronous (faster). The Bela program will still be able to start as the 
# audio thread has been killed above
	$(AT) killall scsynth 2>/dev/null& killall sclang 2>/dev/null& true
endif

connect: ## Connects to the running Bela program (if any), can detach with ctrl-a ctrl-d.
	$(AT) screen -r -S $(SCREEN_NAME)
	
idestart: ## Starts the on-board IDE
idestart: idestop
	$(AT) printf "Starting IDE..."
	$(AT) $(BELA_IDE_RUN_COMMAND)
	$(AT) printf "done\n"

idestop: ## Stops the on-board IDE
	$(AT) printf "Stopping currently running IDE..."
	$(AT) screen -X -S $(BELA_IDE_SCREEN_NAME) quit > /dev/null; exit 0;
	$(AT) printf "done\n"

BELA_IDE_STARTUP_COMMAND=printf '\#!/bin/sh\n\#\n\# This file is autogenerated by Bela. Do not edit!\n\necho Running the Bela IDE...\n$(BELA_IDE_RUN_COMMAND)\n' > $(BELA_IDE_STARTUP_SCRIPT)

idestartup: ## Enables the IDE at startup
	$(AT) echo "Enabling the IDE at startup"
	$(AT) $(BELA_IDE_STARTUP_COMMAND)
	$(AT) chmod +x $(BELA_IDE_STARTUP_SCRIPT)

idenostartup: ## Disables the IDE at startup
	$(AT) echo "Disabling the IDE at startup"
	$(AT) printf "#!/bin/sh\n#\n\n# This file is autogenerated by Bela. Do not edit!\n\n# The Bela IDE is disabled on startup.\n" > $(BELA_IDE_STARTUP_SCRIPT)

ideconnect: ## Brings in the foreground the IDE that currently is running in a screen (if any), can detach with ctrl-a ctrl-d.
	$(AT) screen -r -S $(BELA_IDE_SCREEN_NAME)

SCSYNTH_SCREEN_NAME=scsynth
SCSYNTH_RUN_COMMAND=screen -S $(SCSYNTH_SCREEN_NAME) -d -m scsynth $(SC_CL)
SCSYNTH_STOP_COMMAND?=screen -X -S $(SCSYNTH_SCREEN_NAME) quit > /dev/null 
scsynthstart: ## Starts scsynth
scsynthstart: scsynthstop
	$(AT) printf "Starting scsynth..."
	$(AT) $(SCSYNTH_RUN_COMMAND)
	$(AT) printf "done\n"

scsynthstop: ## Stops scsynth
	$(AT) printf "Stopping currently running scsynth..."
	$(AT) $(SCSYNTH_STOP_COMMAND); exit 0;
	$(AT) printf "done\n"

scsynthconnect: ## Brings in the foreground the scsynth that currently is running in a screen (if any), can detach with ctrl-a ctrl-d.
	$(AT) screen -r -S $(SCSYNTH_SCREEN_NAME)

SCSYNTH_STARTUP_COMMAND=printf '\#!/bin/sh\n\#\n\# This file is autogenerated by Bela. Do not edit!\n\necho Running scsynth...\n$(SCSYNTH_RUN_COMMAND)\n' 
scsynthstartup: ## Enables scsynth at startup
	$(SCSYNTH_STARTUP_COMMAND) > $(BELA_STARTUP_SCRIPT)

scsynthnostartup: ## Disables scsynth at startup
scsynthnostartup: nostartup
	$(AT) echo "Disabling scsynth at startup...done"

BELA_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
UPDATES_DIR?=/root/Bela/updates
UPDATE_SOURCE_DIR?=/tmp/belaUpdate
UPDATE_REQUIRED_PATHS?=scripts include core scripts/update_board 
UPDATE_BELA_PATCH?=/tmp/belaPatch
UPDATE_BELA_MV_BACKUP?=/tmp/belaMvBak

updateclean: ## Cleans the $(UPDATES_DIR) folder
	$(AT) [ -n $(UPDATE_DIR) ] && rm -rf $(UPDATE_DIR) && mkdir -p $(UPDATE_DIR)

checkupdate: ## Unzips the zip file in $(UPDATES_DIR) and checks that it contains a valid
	$(AT) echo Validating archive...
	$(AT) cd $(UPDATES_DIR) && COUNT=`ls -l *.zip | wc -l` && [ $$COUNT -eq 1 ] && rm -rf "`ls | grep -v \"\.zip$$\"`"
	$(AT) #TODO: heuristics on available space. Use unzip -l and df
	$(AT) echo uncompressed size: `unzip -l "$(UPDATES_DIR)/*.zip" | tail -n1 | awk '{print $$1}'`
	$(AT) # Delete and re-create the temp directory (first, make sure it is not an empty string!)
	$(AT) [ -n $(UPDATE_SOURCE_DIR) ] && rm -rf $(UPDATE_SOURCE_DIR) && mkdir -p $(UPDATE_SOURCE_DIR)
	$(AT) echo Unzipping archive...
	$(AT) cd $(UPDATE_SOURCE_DIR) && unzip -qq "$(UPDATES_DIR)/*zip"
	$(AT) # RemoveMac OSX garbage if it exists
	$(AT) rm -rf $(UPDATE_SOURCE_DIR)/__MACOSX $(UPDATE_SOURCE_DIR)/.DS_store
	$(AT) # Strip the top-level folder ( if there is only one )
	$(AT) DIR=`ls -d $(UPDATE_SOURCE_DIR)` && COUNT=`ls $$DIR | wc -l` &&\
	  [ $$COUNT -eq 1 ] && mv $(UPDATE_SOURCE_DIR)/* /tmp/supertemp && rm -rf $(UPDATE_SOURCE_DIR) && mv /tmp/supertemp $(UPDATE_SOURCE_DIR)
	
	$(AT) echo Validating unzipped archive...
	$(AT) cd $(UPDATE_SOURCE_DIR) && FAIL=0 && for path in $(UPDATE_REQUIRED_PATHS); do `ls $$path >/dev/null 2>&1` || { FAIL=1; break; }; done;\
	  [ $$FAIL -eq 0 ] || { echo "$$path was not found in the zip archive. Maybe it is corrupted?"; exit 1; }
	$(AT) echo 	...done
UPDATE_LOG?=/root/update.log
LOG=>> $(UPDATE_LOG) 2>&1
updateunsafe: ## Installs the update from $(UPDATES_DIR) in a more brick-friendly way
	$(AT) echo > $(UPDATE_LOG)
	# Re-perform the check, just in case ...	
	$(AT) cd $(UPDATE_SOURCE_DIR) && FAIL=0 && for path in $(UPDATE_REQUIRED_PATHS); do `ls $$path >/dev/null 2>&1` || { FAIL=1; break; }; done;\
	  [ $$FAIL -eq 0 ] || { echo "$$path was not found in the zip archive. Maybe it is corrupted?"; exit 1; }
	$(AT) cd $(UPDATE_SOURCE_DIR)/scripts && BBB_ADDRESS=root@127.0.0.1 BBB_BELA_HOME=$(BELA_DIR) ./update_board -y --no-frills
	$(AT) screen -S update-Bela -d -m bash -c "echo Restart the IDE $(LOG) &&\
	  $(MAKE) --no-print-directory idestart $(LOG) && echo Update succesful $(LOG);" $(LOG)
update: ## Installs the update from $(UPDATES_DIR)
update: stop
	$(AT) # Truncate the log file
	$(AT) echo > $(UPDATE_LOG)
	$(AT) echo Re-perform the check, just in case ... >> $(UPDATE_LOG)
	$(AT) cd $(UPDATE_SOURCE_DIR) && FAIL=0 && for path in $(UPDATE_REQUIRED_PATHS); do `ls $$path >/dev/null 2>&1` || { FAIL=1; break; }; done;\
	  [ $$FAIL -eq 0 ] || { echo "$$path was not found in the zip archive. Maybe it is corrupted?"; exit 1; }
	$(AT) [ -n $(UPDATE_BELA_PATCH) ] && mkdir -p $(UPDATE_BELA_PATCH)
	$(AT) #TODO: this would allow to trim trailing slashes in case we want to be safer: a="`pwd`/" ; target=${a%/} ; echo $target
	$(AT) $(MAKE) --no-print-directory coreclean
	$(AT) echo Copying $(BELA_DIR) to $(UPDATE_BELA_PATCH) ... | tee -a $(UPDATE_LOG)
	$(AT) rsync -a --delete-during --exclude Documentation $(BELA_DIR)/ $(UPDATE_BELA_PATCH)
	$(AT) echo Applying patch in $(UPDATE_BELA_PATCH)... | tee -a $(UPDATE_LOG)
	$(AT) cd $(UPDATE_SOURCE_DIR)/scripts && BBB_ADDRESS=root@127.0.0.1 BBB_BELA_HOME=$(UPDATE_BELA_PATCH) ./update_board -y --no-frills
	$(AT) # If everything went ok, we now have the updated version of $(BELA_DIR) in $(UPDATE_BELA_PATCH)
	$(AT) # So let's operate the magic swap. $(BELA_DIR) is moved to $(UPDATE_BELA_MV_BACKUP) and $(UPDATE_BELA_PATCH) is moved to $(BELA_DIR).
	$(AT) # The fun part is that this Makefile is moved as well...
	$(AT) # We are about to kill the IDE, so just in case you are running this from within the IDE, we run the remainder of this update in a screen.
	$(AT) # Output will be logged to $(UPDATE_LOG)
	$(AT) echo Restoring directory structure... | tee -a $(UPDATE_LOG)
	$(AT) [ -n $(UPDATE_BELA_MV_BACKUP) ] $(LOG) && rm -rf $(UPDATE_BELA_MV_BACKUP) $(LOG)
	$(AT) screen -S update-Bela -d -m bash -c '\
	        echo Kill the IDE $(LOG) && \
	        $(MAKE) --no-print-directory idestop $(LOG) &&\
	        mv $(BELA_DIR) $(UPDATE_BELA_MV_BACKUP) $(LOG) && mv $(UPDATE_BELA_PATCH) $(BELA_DIR) $(LOG) &&\
	        echo Hope we are still alive here $(LOG) &&\
	        echo Restart the IDE $(LOG) &&\
	        make --no-print-directory -C $(BELA_DIR) idestart $(LOG) &&\
	        echo Update succesful $(LOG); \
	        ' $(LOG)

LIB_EXTRA_SO = libbelaextra.so
LIB_EXTRA_A = libbelaextra.a
LIB_EXTRA_OBJS = $(EXTRA_CORE_OBJS) build/core/GPIOcontrol.o
lib/$(LIB_EXTRA_SO): $(LIB_EXTRA_OBJS)
	$(AT) echo Building lib/$(LIB_EXTRA_SO)
	$(AT) gcc -shared -Wl,-soname,$(LIB_EXTRA_SO) $(LDLIBS) -o lib/$(LIB_EXTRA_SO) $(LIB_EXTRA_OBJS) $(LDFLAGS)

lib/$(LIB_EXTRA_A): $(LIB_EXTRA_OBJS) $(PRU_OBJS) $(LIB_DEPS)
	$(AT) echo Building lib/$(LIB_EXTRA_A)
	$(AT) ar rcs lib/$(LIB_EXTRA_A) $(LIB_EXTRA_OBJS)

LIB_SO =libbela.so
LIB_A = libbela.a
LIB_OBJS = $(CORE_CORE_OBJS) build/core/AuxiliaryTasks.o lib/libprussdrv.a build/core/Gpio.o
lib/$(LIB_SO): $(LIB_OBJS)
	$(AT) echo Building lib/$(LIB_SO)
	$(AT) gcc -shared -Wl,-soname,$(LIB_SO) $(LDLIBS) -o lib/$(LIB_SO) $(LIB_OBJS) $(LDFLAGS)

lib/$(LIB_A): $(LIB_OBJS) $(PRU_OBJS) $(LIB_DEPS)
	$(AT) echo Building lib/$(LIB_A)
	$(AT) ar rcs lib/$(LIB_A) $(LIB_OBJS)

lib: lib/libbelaextra.so lib/libbelaextra.a lib/libbela.so lib/libbela.a
	

HEAVY_TMP_DIR=/tmp/heavy-bela/
HEAVY_SRC_TARGET_DIR=$(PROJECT_DIR)
HEAVY_SRC_FILES=$(HEAVY_TMP_DIR)/*.cpp $(HEAVY_TMP_DIR)/*.c $(HEAVY_TMP_DIR)/*.hpp $(HEAVY_TMP_DIR)/*.h
HEAVY_OBJ_TARGET_DIR=$(PROJECT_DIR)/build
HEAVY_OBJ_FILES=$(HEAVY_TMP_DIR)/*.o
heavy-unzip-archive:
	$(AT) [ -z "$(HEAVY_ARCHIVE)" ] && { echo "You should specify the path to the Heavy archive with HEAVY_ARCHIVE=" >&2; false; } || true
	$(AT) [ -f "$(HEAVY_ARCHIVE)" ] || { echo "File $(HEAVY_ARCHIVE) not found" >&2; false; }
	$(AT) rm -rf $(HEAVY_TMP_DIR)
	$(AT) mkdir -p $(HEAVY_TMP_DIR)
	$(AT) unzip -qq -d $(HEAVY_TMP_DIR) $(HEAVY_ARCHIVE) && rm -rf $(HEAVY_ARCHIVE)
# For each source file, check if it already exists at the destination. If it
# does not, or if it is `diff`erent, then mv the source file to the destination
# We do all of this instead of simply touching all the src and obj files so
# that we make sure that the prerequsites of `render.o` are not more recent
# than the target unless they actually have changed.
	$(AT) for file in $(HEAVY_SRC_FILES); do dest="$(HEAVY_SRC_TARGET_DIR)/`basename $$file`"; diff -q "$$file" "$$dest" 2>/dev/null || { mv "$$file" "$$dest"; touch "$$dest"; } ; done
# For each object file, move it to the destination and make sure it is older than the source
	$(AT) for file in $(HEAVY_OBJ_FILES); do touch "$$file"; mv "$$file" "$(HEAVY_OBJ_TARGET_DIR)"; done
# If there is no render.cpp, copy the default Heavy one
	$(AT) [ -f $(PROJECT_DIR)/render.cpp ] || { cp $(BELA_DIR)/scripts/hvresources/render.cpp $(PROJECT_DIR)/ 2> /dev/null || echo "No default render.cpp found on the board"; }

.PHONY: all clean distclean help projectclean nostartup startup startuploop debug run runfg runscreen runscreenfg stop idestart idestop idestartup idenostartup ideconnect connect update checkupdate updateunsafe scsynthstart scsynthstop scsynthstartup scsynthnostartup scsynthconnect lib
