#!/bin/bash

set -euo pipefail

setup_mock_snap_environment() {
    if [ -z "${SNAP:-}" ]; then
        SNAP="${SNAP:-$(pwd)}"
        export SNAP
    fi

    if [ -z "${SNAP_COMMON:-}" ]; then
        SNAP_COMMON="${SNAP_COMMON:-/tmp/snap-polkadot-parachain-test}"
        export SNAP_COMMON
        mkdir -p "${SNAP_COMMON}"
    fi

    if [ -z "${SNAP_DATA:-}" ]; then
        SNAP_DATA="${SNAP_DATA:-/tmp/snap-polkadot-parachain-data-test}"
        export SNAP_DATA
        mkdir -p "${SNAP_DATA}"
    fi

    SNAP_NAME="${SNAP_NAME:-polkadot-parachain}"
    export SNAP_NAME

    MOCK_SNAPCTL_DIR="/tmp/mock-snapctl-$$"
    MOCK_CONFIG_FILE="/tmp/mock-snap-config-$$"
    export MOCK_CONFIG_FILE
    mkdir -p "${MOCK_SNAPCTL_DIR}"

    cat > "${MOCK_SNAPCTL_DIR}/snapctl" << 'EOF'
#!/bin/sh

case "$1" in
    "get")
        key="$2"
        if [ -f "$MOCK_CONFIG_FILE" ]; then
            value=$(grep "^$key=" "$MOCK_CONFIG_FILE" 2>/dev/null | head -1 | cut -d'=' -f2-)
            if [ -n "$value" ]; then
                echo "$value"
            fi
        fi
        ;;
    "set")
        key_value="$2"
        key=$(echo "$key_value" | cut -d'=' -f1)
        if [ -f "$MOCK_CONFIG_FILE" ]; then
            grep -v "^$key=" "$MOCK_CONFIG_FILE" > "$MOCK_CONFIG_FILE.tmp" 2>/dev/null || true
            mv "$MOCK_CONFIG_FILE.tmp" "$MOCK_CONFIG_FILE" 2>/dev/null || true
        fi
        echo "$key_value" >> "$MOCK_CONFIG_FILE"
        ;;
    "unset")
        key="$2"
        if [ -f "$MOCK_CONFIG_FILE" ]; then
            grep -v "^$key=" "$MOCK_CONFIG_FILE" > "$MOCK_CONFIG_FILE.tmp" 2>/dev/null || true
            mv "$MOCK_CONFIG_FILE.tmp" "$MOCK_CONFIG_FILE" 2>/dev/null || true
        fi
        ;;
    *)
        echo "Mock snapctl: unsupported command $1" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "${MOCK_SNAPCTL_DIR}/snapctl"

    export PATH="${MOCK_SNAPCTL_DIR}:${PATH}"
    trap 'rm -rf "${MOCK_SNAPCTL_DIR}" "${MOCK_CONFIG_FILE}" 2>/dev/null' EXIT

    echo "Mock snap environment setup:"
    echo "  SNAP=$SNAP"
    echo "  SNAP_COMMON=$SNAP_COMMON"
    echo "  SNAP_DATA=$SNAP_DATA"
    echo "  snapctl: $(command -v snapctl)"

    if [ "$(command -v snapctl)" = "${MOCK_SNAPCTL_DIR}/snapctl" ]; then
        echo "  Mock snapctl is active"
    else
        echo "  Warning: Real snapctl may still be in use"
    fi
}

test_validate_service_args() {
    echo "Testing validate_service_args function..."

    setup_mock_snap_environment

    source "$SNAP/utils/config.sh"
    source "$SNAP/utils/utils.sh"

    local test_count=0
    local passed_count=0

    run_test_case() {
        local description="$1"
        local args="$2"
        local expected_exit_code="$3"
        local test_name="$4"

        test_count=$((test_count + 1))
        echo "  Test $test_count: $description"

        local original_args
        original_args="$(get_service_args)"
        set_previous_service_args "$original_args"

        set +e
        (validate_service_args "$args") >/dev/null 2>&1
        local actual_exit_code=$?
        set -e

        if [ "$actual_exit_code" -eq "$expected_exit_code" ]; then
            echo "    PASSED: Expected exit code $expected_exit_code, got $actual_exit_code"
            passed_count=$((passed_count + 1))
        else
            echo "    FAILED: Expected exit code $expected_exit_code, got $actual_exit_code"
        fi

        set_service_args "$original_args"
    }

    local initial_args
    initial_args="$(get_service_args)"
    set_previous_service_args "$initial_args"

    local effective_args
    effective_args="$(get_effective_service_args)"
    if [[ "${effective_args}" == "${__DEFAULT_SERVICE_ARGS}"* ]]; then
        echo "  Effective args include the default base-path when none is configured"
    else
        echo "  FAILED: Effective args did not include the default base-path" >&2
        return 1
    fi

    run_test_case "Valid base-path with equals format" "--base-path=$SNAP_COMMON/polkadot_base/data" 0 "valid_base_path_equals"
    run_test_case "Valid base-path with space format" "--base-path $SNAP_COMMON/polkadot_base/subdir" 0 "valid_base_path_space"
    run_test_case "Valid base-path pointing to /mnt" "--base-path=/mnt/external-drive" 0 "valid_mnt_path"
    run_test_case "Valid base-path pointing to /media" "--base-path=/media/usb-drive" 0 "valid_media_path"
    run_test_case "Valid base-path pointing to /run/media" "--base-path=/run/media/user/drive" 0 "valid_run_media_path"
    run_test_case "Invalid base-path (not allowed)" "--base-path=/home/user/data" 1 "invalid_base_path"
    run_test_case "Invalid base-path pointing to root" "--base-path=/" 1 "invalid_root_path"
    run_test_case "Invalid base-path pointing to /tmp" "--base-path=/tmp/polkadot" 1 "invalid_tmp_path"
    run_test_case "Missing path after --base-path flag" "--base-path" 1 "missing_base_path"
    run_test_case "Multiple arguments with valid base-path" "--name=test-node --base-path=$SNAP_COMMON/polkadot_base --port=30333" 0 "multiple_args_valid"
    run_test_case "Multiple arguments with invalid base-path" "--name=test-node --base-path=/invalid/path --port=30333" 1 "multiple_args_invalid"
    run_test_case "No base-path argument" "--name=test-node --port=30333" 0 "no_base_path"
    run_test_case "Empty arguments" "" 0 "empty_args"
    run_test_case "Base-path exactly matching allowed path" "--base-path=$SNAP_COMMON/polkadot_base" 0 "exact_allowed_path"
    run_test_case "Multiple base-path arguments (last invalid)" "--base-path=$SNAP_COMMON/polkadot_base --base-path=/invalid/path" 1 "multiple_base_paths_invalid"

    set_service_args "--base-path=/mnt/polkadot --name=test-node"
    effective_args="$(get_effective_service_args)"
    test_count=$((test_count + 1))
    echo "  Test $test_count: Effective args preserve explicit base-path"
    if [[ "${effective_args}" == "--base-path=/mnt/polkadot --name=test-node" ]]; then
        echo "    PASSED: Explicit base-path was preserved"
        passed_count=$((passed_count + 1))
    else
        echo "    FAILED: Explicit base-path was not preserved"
    fi

    echo ""
    echo "Test Summary:"
    echo "  Total tests: $test_count"
    echo "  Passed: $passed_count"
    echo "  Failed: $((test_count - passed_count))"

    if [ "$passed_count" -eq "$test_count" ]; then
        echo "  All tests passed!"
        return 0
    fi

    echo "  Some tests failed."
    return 1
}

test_validate_service_args
