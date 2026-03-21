#!/bin/bash
# =============================================================
# test_software.sh - Tests for software audit module
# =============================================================
source "$(dirname "$0")/../scripts/utils.sh"
source "$(dirname "$0")/../scripts/software_audit.sh"

# -------------------------------------------------------------
# TEST HELPER FUNCTIONS
# -------------------------------------------------------------
TESTS_PASSED=0
TESTS_FAILED=0

assert() {
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

assert_not_empty() {
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
test_os_info() {
    print_section "TESTING OS INFO"
    output=$(get_os_info 2>/dev/null)
    assert_not_empty "get_os_info returns output" "$output"
}

test_kernel_info() {
    print_section "TESTING KERNEL INFO"
    output=$(get_kernel_info 2>/dev/null)
    assert_not_empty "get_kernel_info returns output" "$output"
}

test_arch_info() {
    print_section "TESTING ARCHITECTURE INFO"
    output=$(get_arch_info 2>/dev/null)
    assert_not_empty "get_arch_info returns output" "$output"
}

test_installed_packages() {
    print_section "TESTING INSTALLED PACKAGES"
    output=$(get_installed_packages 2>/dev/null)
    assert_not_empty "get_installed_packages returns output" "$output"
}

test_logged_in_users() {
    print_section "TESTING LOGGED IN USERS"
    output=$(get_logged_in_users 2>/dev/null)
    assert "get_logged_in_users exits successfully" "0" "$?"
}

test_services_info() {
    print_section "TESTING SERVICES INFO"
    output=$(get_services_info 2>/dev/null)
    assert "get_services_info exits successfully" "0" "$?"
}

test_open_ports() {
    print_section "TESTING OPEN PORTS"
    output=$(get_open_ports 2>/dev/null)
    assert_not_empty "get_open_ports returns output" "$output"
}

test_startup_programs() {
    print_section "TESTING STARTUP PROGRAMS"
    output=$(get_startup_programs 2>/dev/null)
    assert "get_startup_programs exits successfully" "0" "$?"
}

# -------------------------------------------------------------
# MAIN - run all tests
# -------------------------------------------------------------
separator
echo "        SOFTWARE AUDIT TESTS"
separator

test_os_info
test_kernel_info
test_arch_info
test_installed_packages
test_logged_in_users
test_services_info
test_open_ports
test_startup_programs

separator
echo -e "Results: ${GREEN}$TESTS_PASSED passed${RESET} / ${RED}$TESTS_FAILED failed${RESET}"
separator