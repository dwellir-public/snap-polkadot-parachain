#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/test-helpers.bash"

readonly POLKADOT_TEST_CHAIN="${POLKADOT_TEST_CHAIN:-polkadot-assethub}"

cleanup_polkadot_snap
install_polkadot_snap

readonly CHAIN_ARGUMENT="$(get_chain_argument)"
readonly EXPECTED_SERVICE_ARGS_SUBSTRING="--name=testing --chain=${CHAIN_ARGUMENT} --rpc-port=9933 --prometheus-port=9900 --prometheus-external"

sudo snap set "${POLKADOT_SNAP_NAME}" service-args="--name=testing --chain=${CHAIN_ARGUMENT} --rpc-port=9933"
sudo snap start "${POLKADOT_SNAP_NAME}"

sleep 5
check_polkadot_service_running

before_restart_log_count="$(get_snap_log_count)"
sudo snap set "${POLKADOT_SNAP_NAME}" service-args="${EXPECTED_SERVICE_ARGS_SUBSTRING}"
sudo snap restart "${POLKADOT_SNAP_NAME}"

wait_for_polkadot_service
wait_for_node_health
run_node_status_checks
assert_logs_after_line_contain "${before_restart_log_count}" "Service arguments: --base-path="
assert_logs_after_line_contain "${before_restart_log_count}" "${EXPECTED_SERVICE_ARGS_SUBSTRING}"
