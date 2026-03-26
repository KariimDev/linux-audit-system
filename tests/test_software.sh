#!/bin/bash
# =============================================================
# test_software.sh - Tests for software audit module
# =============================================================

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/utils.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/software_audit.sh"

# -------------------------------------------------------------
# MOCKING VISUALS
# -------------------------------------------------------------
# Without this, "assert_not_empty" always passes because the log_info strings
# or "print_section" header are technically output text.
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
        echo -e "\033[0;31m[FAIL]\033[0m $1 — output was empty"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# -------------------------------------------------------------
# TESTS
# -------------------------------------------------------------
test_os_info() {
    output=$(get_os_info 2>/dev/null)
    assert_not_empty "get_os_info retrieves OS string" "$output"
}

test_kernel_info() {
    output=$(get_kernel_info 2>/dev/null)
    assert_not_empty "get_kernel_info retrieves kernel version" "$output"
}

test_arch_info() {
    output=$(get_arch_info 2>/dev/null)
    assert_not_empty "get_arch_info retrieves architecture" "$output"
}

test_installed_packages() {
    output=$(get_installed_packages 2>/dev/null)
    assert_not_empty "get_installed_packages retrieves package list" "$output"
}

test_logged_in_users() {
    get_logged_in_users &>/dev/null
    assert "get_logged_in_users exits safely" "0" "$?"
}

test_services_info() {
    get_services_info &>/dev/null
    assert "get_services_info exits safely" "0" "$?"
}

test_open_ports() {
    get_open_ports &>/dev/null
    assert "get_open_ports exits safely" "0" "$?"
}

test_startup_programs() {
    get_startup_programs &>/dev/null
    assert "get_startup_programs exits safely" "0" "$?"
}

# -------------------------------------------------------------
# MAIN - run all tests
# -------------------------------------------------------------
echo "============================================================"
echo "        SOFTWARE AUDIT TESTS"
echo "============================================================"

test_os_info
test_kernel_info
test_arch_info
test_installed_packages
test_logged_in_users
test_services_info
test_open_ports
test_startup_programs

echo "============================================================"
echo -e "Results: \033[0;32m$TESTS_PASSED passed\033[0m / \033[0;31m$TESTS_FAILED failed\033[0m"
echo "============================================================"

if [ "$TESTS_FAILED" -gt 0 ]; then
    exit 1
fi
exit 0