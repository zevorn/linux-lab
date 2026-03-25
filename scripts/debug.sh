#!/bin/bash
# Launch GDB and connect to QEMU debug server
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

VMLINUX="$KERNEL_OUT/vmlinux"

check_file "$VMLINUX" "vmlinux not found. Run 'make kernel-build BOARD=$BOARD KERNEL=$KERNEL'"
check_cmd gdb-multiarch

GDB_INIT="$BOARD_OUTPUT/.gdbinit"

cat > "$GDB_INIT" << EOF
set architecture $GDB_ARCH
target remote :$GDB_PORT
EOF

log_info "Connecting GDB to QEMU ($BOARD) on port $GDB_PORT..."
log_info "vmlinux: $VMLINUX"
exec gdb-multiarch -x "$GDB_INIT" "$VMLINUX"
