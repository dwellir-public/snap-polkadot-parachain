# Testing

This repository has both local test scripts and GitHub Actions workflows.

## Preparation

Run the tests in a container or start from a clean local snap environment:

```bash
sudo snap remove polkadot-parachain --purge
```

Keep a terminal open with the snap logs while testing:

```bash
sudo snap logs polkadot-parachain -f
```

## Test scripts

The test scripts live in `tests/` and share the helper logic in `tests/test-helpers.bash`.

### Available scripts

- `tests/run_all_local.sh`
  Runs the full local test sequence against either one local snap file or one Snap Store revision.
- `tests/test_basic_install.sh`
  Runs the basic install-and-sync test for a single chain.
- `tests/test_initial_install.sh`
  Runs the full install flow used for the Asset Hub Polkadot full suite.
- `tests/test_base_path.sh`
  Verifies that an invalid `--base-path` update is rejected and that the previous config is kept.
- `tests/test_downgrade.sh`
  Refreshes to an older revision and verifies the node still starts and syncs.
- `tests/test_endure.sh`
  Verifies `endure=true` prevents restart during refresh and that a manual restart picks up the downgraded revision.
- `tests/test_shellscripts.sh`
  Fast local unit-style coverage for `utils/utils.sh`, especially `validate_service_args()`.

### Installation source selection

The runtime test scripts can install Polkadot Parachain from three sources:

1. Local snap file

```bash
POLKADOT_SNAP_FILE=/full/path/to/polkadot-parachain.snap bash tests/test_initial_install.sh
```

2. Specific Snap Store revision

```bash
POLKADOT_INSTALL_REVISION=65 bash tests/test_initial_install.sh
```

3. Snap Store channel

```bash
POLKADOT_INSTALL_CHANNEL=edge bash tests/test_initial_install.sh
```

The scripts print the chosen install source before installation.

The tests do not pass `--chain=<name>` directly. Instead they map the symbolic test chain to a JSON chain spec file under `tests/resources/chainspecs/`, copy that file into `/var/snap/polkadot-parachain/common/test-chainspecs/`, and run the node with `--chain=/var/snap/.../<spec>.json`.

### Supported chains

The currently supported test chains are:

- `polkadot-assethub`
- `kusama-assethub`
- `bridge-hub-polkadot`

An additional spec file for `people-polkadot` is stored in `tests/resources/chainspecs/` for future use, but it is not part of the current automated test matrix.

Example:

```bash
POLKADOT_INSTALL_REVISION=65 POLKADOT_TEST_CHAIN=kusama-assethub bash tests/test_basic_install.sh
```

### Downgrade and endure tests

When the installed snap comes from the Snap Store, `tests/test_downgrade.sh` and `tests/test_endure.sh` can usually discover the previous published revision automatically.

When the installed snap comes from a local `.snap` file, set the downgrade target explicitly:

```bash
POLKADOT_SNAP_FILE=/full/path/to/polkadot-parachain.snap bash tests/test_initial_install.sh
POLKADOT_DOWNGRADE_REVISION=64 bash tests/test_downgrade.sh
POLKADOT_DOWNGRADE_REVISION=64 bash tests/test_endure.sh
```

### Base-path test

Run:

```bash
bash tests/test_base_path.sh
```

Expected behavior:

- the `snap set` command fails
- the output mentions `base-path`
- the previously configured `service-args` value is preserved

Current expected output is similar to:

```text
error: cannot perform the following tasks:
- Run configure hook of "polkadot-parachain" snap (run hook "configure": base-path requires a value. No change was made to service-args.)
```

This is expected for the current validation logic.

### Node status checks

The runtime tests call `tests/check_node_status.py`, which checks:

- RPC version matches the installed snap build
- node health reports peers and syncing
- sync state increases between two checks
- `system_chain` matches the configured chain

The version match is based on the shared git SHA suffix when the snap version format and RPC version format differ.

## Recommended local flows

### Fast validation of shell helpers

```bash
bash tests/test_shellscripts.sh
```

### Test a local snap build on Asset Hub Polkadot

Run the full local sequence:

```bash
bash tests/run_all_local.sh /full/path/to/polkadot-parachain.snap 64
```

Or with explicit flags:

```bash
bash tests/run_all_local.sh --snap-file /full/path/to/polkadot-parachain.snap --downgrade-revision 64
```

### Test a Snap Store revision on Asset Hub Polkadot

Run the same full sequence against a published revision:

```bash
bash tests/run_all_local.sh --revision 65
```

If you want to pin the downgrade target instead of auto-discovering it:

```bash
bash tests/run_all_local.sh --revision 65 --downgrade-revision 64
```

### Test a local snap build on another chain

```bash
POLKADOT_SNAP_FILE=/full/path/to/polkadot-parachain.snap POLKADOT_TEST_CHAIN=bridge-hub-polkadot bash tests/test_basic_install.sh
```

## GitHub Actions

### PR and main-branch shellscript validation

The workflow [test-shellscripts.yaml](.github/workflows/test-shellscripts.yaml) runs `tests/test_shellscripts.sh` on:

- pull requests
- pushes to `main`

### Manual runtime test workflow

The workflow [manual-revision-tests.yaml](.github/workflows/manual-revision-tests.yaml) is manually triggered with `workflow_dispatch`.

Inputs:

- `build_snap`
  If `true`, the workflow builds the snap from the selected Git ref and tests that local artifact.
- `revision`
  Required when `build_snap=false`.
- `downgrade_revision`
  Required for Asset Hub Polkadot full-suite runs when `build_snap=true`.
- `chain`
  One of `all`, `polkadot-assethub`, `kusama-assethub`, `bridge-hub-polkadot`.

Behavior:

- `chain=all` runs the full Asset Hub Polkadot suite plus basic install tests for Asset Hub Kusama and Bridge Hub Polkadot.
- `chain=polkadot-assethub` runs the full Asset Hub Polkadot suite only.
- `chain=kusama-assethub` or `bridge-hub-polkadot` runs the basic install test for that chain only.
- when `build_snap=true`, the snap is built from the selected branch or tag, uploaded as an artifact, then installed with `--dangerous` in the test jobs.

## Snap Store testing

If you need to test a branch build through the Snap Store:

1. Upload to a temporary branch channel

```bash
snapcraft upload <snap>
snapcraft release <revision> latest/edge/my-tests
```

2. Install it

```bash
sudo snap install polkadot-parachain --channel latest/edge/my-tests
```
