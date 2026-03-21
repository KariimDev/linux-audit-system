#!/bin/bash
# =============================================================
# test_hardware.sh - Tests for hardware audit module
# =============================================================
source "$(dirname "$0")/../scripts/utils.sh"
source "$(dirname "$0")/../scripts/hardware_audit.sh"

# -------------------------------------------------------------
# TEST HELPER FUNCTIONS
# -------------------------------------------------------------
# counts how many tests passed and failed
TESTS_PASSED=0
TESTS_FAILED=0

# assert function — like assert() in C
assert() {
    # $1 = test name, $2 = expected, $3 = actual
    if [ "$2" = "$3" ]; then
        echo -e "${GREEN}[PASS]${RESET} $1"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}[FAIL]${RESET} $1"
        echo -e "       Expected : $2"
        echo -e "       Got      : $3"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# assert_not_empty — checks that a function returns something
assert_not_empty() {
    # $1 = test name, $2 = actual value
    if [ -n "$2" ]; then
        echo -e "${GREEN}[PASS]${RESET} $1"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}[FAIL]${RESET} $1 — output was empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# -------------------------------------------------------------
# TESTS
# -------------------------------------------------------------
test_cpu_info() {
    print_section "TESTING CPU INFO"
    # capture output of get_cpu_info
    output=$(get_cpu_info 2>/dev/null)
    assert_not_empty "get_cpu_info returns output" "$output"
}

test_gpu_info() {
    print_section "TESTING GPU INFO"
    output=$(get_gpu_info 2>/dev/null)
    # GPU might not exist so we just check function runs without crashing
    assert "get_gpu_info exits successfully" "0" "$?"
}

test_ram_info() {
    print_section "TESTING RAM INFO"
    output=$(get_ram_info 2>/dev/null)
    assert_not_empty "get_ram_info returns output" "$output"
}

test_disk_info() {
    print_section "TESTING DISK INFO"
    output=$(get_disk_info 2>/dev/null)
    assert_not_empty "get_disk_info returns output" "$output"
}

test_network_info() {
    print_section "TESTING NETWORK INFO"
    output=$(get_network_info 2>/dev/null)
    assert_not_empty "get_network_info returns output" "$output"
}

test_motherboard_info() {
    print_section "TESTING MOTHERBOARD INFO"
    # motherboard info might fail without root so just check it runs
    get_motherboard_info 2>/dev/null
    assert "get_motherboard_info exits without crashing" "0" "$?"
}

test_usb_info() {
    print_section "TESTING USB INFO"
    output=$(get_usb_info 2>/dev/null)
    assert "get_usb_info exits successfully" "0" "$?"
}

# -------------------------------------------------------------
# MAIN - run all tests
# -------------------------------------------------------------
separator
echo "        HARDWARE AUDIT TESTS"
separator

test_cpu_info
test_gpu_info
test_ram_info
test_disk_info
test_network_info
test_motherboard_info
test_usb_info

separator
echo -e "Results: ${GREEN}$TESTS_PASSED passed${RESET} / ${RED}$TESTS_FAILED failed${RESET}"
separator