#!/bin/bash
# =============================================================
# test_hardware.sh - Tests for hardware audit module
# =============================================================

# Pull in the external files
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/utils.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/hardware_audit.sh"

# -------------------------------------------------------------
# MOCKING VISUALS
# -------------------------------------------------------------
# Overriding printing functions so we actually test if commands produced real output,
# rather than just successfully printing the string "===== CPU INFORMATION ====="
print_section() { :; }
log_info() { :; }
log_error() { :; }
log_warn() { :; }
separator() { :; }

# -------------------------------------------------------------
# TEST HELPER FUNCTIONS
# -------------------------------------------------------------
TESTS_PASSED=0
TESTS_FAILED=0

assert() {
    # $1 = test name, $2 = expected, $3 = actual
    if [ "$2" = "$3" ]; then
        echo -e "\033[0;32m[PASS]\033[0m $1"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "\033[0;31m[FAIL]\033[0m $1"
        echo -e "       Expected : $2"
        echo -e "       Got      : $3"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

assert_not_empty() {
    if [ -n "$2" ]; then
        echo -e "\033[0;32m[PASS]\033[0m $1"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "\033[0;31m[FAIL]\033[0m $1 — output was empty (command failed or no data)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# -------------------------------------------------------------
# TESTS
# -------------------------------------------------------------
test_cpu_info() {
    output=$(get_cpu_info 2>/dev/null)
    assert_not_empty "get_cpu_info retrieves valid CPU hardware data" "$output"
}

test_gpu_info() {
    output=$(get_gpu_info 2>/dev/null)
    # Check that it either outputs something about a GPU, or the fallback string
    # Without the mocked functions, it would always print the log header
    assert_not_empty "get_gpu_info retrieves valid GPU data or proper fallback" "$output"
}

test_ram_info() {
    output=$(get_ram_info 2>/dev/null)
    assert_not_empty "get_ram_info retrieves valid RAM data" "$output"
}

test_disk_info() {
    output=$(get_disk_info 2>/dev/null)
    assert_not_empty "get_disk_info retrieves valid partition data" "$output"
}

test_network_info() {
    output=$(get_network_info 2>/dev/null)
    assert_not_empty "get_network_info retrieves valid network data" "$output"
}

test_motherboard_info() {
    output=$(get_motherboard_info 2>/dev/null)
    # Since dmidecode usually needs root, if it's run without root and failed,
    # the function might genuinely print nothing if the warning logger is mocked
    # We use an assertion that doesn't instantly fail here if empty unless we literally got nothing
    # Actually wait — checking exit code is safer here if it's just checking the function handles it.
    get_motherboard_info &>/dev/null
    assert "get_motherboard_info exits safely (with or without root)" "0" "$?"
}

test_usb_info() {
    get_usb_info &>/dev/null
    assert "get_usb_info exits safely" "0" "$?"
}

# -------------------------------------------------------------
# MAIN - run all tests
# -------------------------------------------------------------
echo "============================================================"
echo "        HARDWARE AUDIT TESTS"
echo "============================================================"

test_cpu_info
test_gpu_info
test_ram_info
test_disk_info
test_network_info
test_motherboard_info
test_usb_info

echo "============================================================"
echo -e "Results: \033[0;32m$TESTS_PASSED passed\033[0m / \033[0;31m$TESTS_FAILED failed\033[0m"
echo "============================================================"

if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
exit 0