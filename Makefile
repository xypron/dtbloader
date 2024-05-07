# SPDX-License-Identifier: GPL-2.0-or-later OR BSD-3-Clause

ARCH		:= aarch64
O		:= $(CURDIR)/build-$(ARCH)

CC		:= clang
LD 		:= lld-link
AR		:= llvm-ar

LIBFDT_DIR = $(CURDIR)/external/dtc/libfdt
LIBFDT  := $(O)/external/libfdt.a

GNUEFI_DIR = $(CURDIR)/external/gnu-efi
LIBEFI  := $(O)/external/libefi.a


CFLAGS		:= -target $(ARCH)-windows \
		   -ffreestanding -fno-stack-protector -fshort-wchar -mno-red-zone \
		   -I$(GNUEFI_DIR)/inc -I$(LIBFDT_DIR) -I$(CURDIR)/src/include \
		   -g -gcodeview -O2

CFLAGS		+= -Wno-pointer-to-int-cast -Wno-int-to-pointer-cast

LDFLAGS		:= -subsystem:efi_application -nodefaultlib -debug

OBJS := \
	$(O)/src/main.o \
	$(O)/src/libc.o \


all: $(O)/dtbloader.efi

$(O)/dtbloader.efi: $(OBJS) $(LIBEFI) $(LIBFDT)
	@echo [LD] $(notdir $@)
	@mkdir -p $(dir $@)
	@$(LD) $(LDFLAGS) -entry:efi_main $^ -out:$@

$(O)/%.o: %.c
	@echo [CC] $(if $(findstring external,$@),\($(word 3,$(subst /, ,$(@:$(CURDIR)%=%)))\) )$(notdir $@)
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -c $< -o $@


.PHONY: clean
clean:
	rm -rf $(O)

#
# GNU-EFI Related rules
#

# NOTE: We drop setjmp and ctors since they are asm code in gnu flavor and clang is upset with that.
LIBEFI_FILES = boxdraw smbios console crc data debug dpath \
        entry error event exit guid hand hw init lock \
        misc pause print sread str cmdline\
	runtime/rtlock runtime/efirtlib runtime/rtstr runtime/vm runtime/rtdata  \
	$(ARCH)/initplat $(ARCH)/math

LIBEFI_OBJS := $(LIBEFI_FILES:%=$(O)/external/gnu-efi/lib/%.o)


.INTERMEDIATE: $(GNUEFI_DIR)/inc/elf.h
$(GNUEFI_DIR)/inc/elf.h:
	ln -sf /usr/include/elf.h $(GNUEFI_DIR)/inc/elf.h

$(LIBEFI): $(LIBEFI_OBJS) $(GNUEFI_DIR)/inc/elf.h
	@echo [AR] $(notdir $@)
	@$(AR) rc $@ $(LIBEFI_OBJS)

#
# libfdt related rules
#

LIBFDT_dir = $(LIBFDT_DIR)

include $(LIBFDT_DIR)/Makefile.libfdt
LIBFDT_OBJS := $(LIBFDT_SRCS:%.c=$(O)/external/dtc/libfdt/%.o)

$(LIBFDT): $(LIBFDT_OBJS)
	@echo [AR] $(notdir $@)
	@$(AR) rc $@ $(LIBFDT_OBJS)
