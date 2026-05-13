# Polkadot Parachain - snap

Basically the `polkadot-parachain` service built as a snap.

## Building the snap

Clone the repo, then build with `snapcraft`:

```bash
sudo snap install snapcraft --classic
cd snap-polkadot-parachain
snapcraft pack --use-lxd --debug --verbosity=debug
```

## Upgrading Polkadot parachain version

Change the upstream version reference in [snap/snapcraft.yaml](snap/snapcraft.yaml), then rebuild.

## Releasing

When a commit is made to `main`, a build will start in Launchpad and if successful release to the `edge` channel.
To promote further, follow [TESTING.md](TESTING.md).

Promoting can be done either from [the Snap Store release page](https://snapcraft.io/polkadot-parachain/releases) or by running:

```bash
snapcraft release polkadot-parachain <revision> <channel>
```

## Testing

The main testing guide lives in [TESTING.md](TESTING.md).

### Local test scripts

The local test entry points are:

- `bash tests/run_all_local.sh /path/to/file.snap <downgrade-revision>`
  Runs the full local test sequence against a local snap build.
- `bash tests/run_all_local.sh --revision <revision> [--downgrade-revision <revision>]`
  Runs the same full sequence against a Snap Store revision.
- `bash tests/test_shellscripts.sh`
  Fast helper coverage for `utils/utils.sh`.
- `bash tests/test_basic_install.sh`
  Basic install-and-sync coverage for one chain.
- `bash tests/test_initial_install.sh`
  Full install flow used by the Asset Hub Polkadot suite.
- `bash tests/test_base_path.sh`
- `bash tests/test_downgrade.sh`
- `bash tests/test_endure.sh`

The runtime tests can install from:

- a local `.snap` file via `POLKADOT_SNAP_FILE=/path/to/file.snap`
- a specific Snap Store revision via `POLKADOT_INSTALL_REVISION=<revision>`
- a Snap Store channel via `POLKADOT_INSTALL_CHANNEL=<channel>`

The tests map symbolic chain names such as `polkadot-assethub` to JSON chain spec files under [tests/resources/chainspecs](</home/jonathan/versioned/dwellir/snap-polkadot-parachain/tests/resources/chainspecs>) and stage the selected file into `/var/snap/polkadot-parachain/common/test-chainspecs/` before starting the snap. The runtime `service-args` therefore use `--chain=/var/snap/.../<spec>.json` instead of `--chain=<name>`.

Example:

```bash
POLKADOT_SNAP_FILE=/full/path/to/polkadot-parachain.snap bash tests/test_initial_install.sh
```

For local `.snap` installs, downgrade and endure tests need an explicit store revision to downgrade to:

```bash
POLKADOT_DOWNGRADE_REVISION=64 bash tests/test_endure.sh
```

### GitHub Actions

This repository has two test-oriented GitHub workflows:

- [manual-revision-tests.yaml](.github/workflows/manual-revision-tests.yaml)
  Manual runtime test workflow.
- [test-shellscripts.yaml](.github/workflows/test-shellscripts.yaml)
  Runs `tests/test_shellscripts.sh` on pull requests and pushes to `main`.

The manual workflow supports:

- testing a Snap Store revision
- building the snap from the selected branch or tag and testing that local artifact
- `chain=all`, which runs the full Asset Hub Polkadot suite and basic install tests for Asset Hub Kusama and Bridge Hub Polkadot

## Hardware requirements

See https://wiki.polkadot.network/docs/maintain-guides-how-to-validate-polkadot#standard-hardware

## Install snap

```bash
sudo snap install <snap-file> --dangerous
```

or from the Snap Store:

```bash
sudo snap install polkadot-parachain
```

### Configuration

#### service-args

```bash
sudo snap set polkadot-parachain service-args="<my service args>"
```

For available arguments see https://github.com/paritytech/polkadot-sdk

Example:

```bash
sudo snap set polkadot-parachain service-args="--name DWELLIR-NODE \
--chain polkadot-assethub \
--prometheus-external \
--pruning archive \
--rpc-external \
--rpc-port=9933 \
--rpc-cors all \
--rpc-methods Safe \
--rpc-max-connections=1000"
```

If `service-args` does not include `--base-path`, the snap automatically prepends the default base path under `$SNAP_COMMON/polkadot_base` and logs that behavior in `snap logs polkadot-parachain`.

Changes to `service-args` are written immediately, but they take effect on the next service start or manual `sudo snap restart polkadot-parachain`.

#### endure

```bash
sudo snap set polkadot-parachain endure=true|false
```

If true, the Polkadot parachain service will not be restarted after a snap refresh.

Use this when restarts should be avoided, for example when running a validator.

#### Changing base-path outside of the SNAP_COMMON directory

Setting an alternative `base-path` can be done by connecting the snap `removable-media` interface. This allows the snap to access external filesystems and directories.

```bash
sudo snap connect polkadot-parachain:removable-media
sudo snap set polkadot-parachain service-args='--base-path /mnt/polkadot-parachain/'
```

### Start the service

```bash
sudo snap start polkadot-parachain
```

### Check logs

```bash
sudo snap logs polkadot-parachain -f
```

### Stop the service

```bash
sudo snap stop polkadot-parachain
```

### Alternatively - use systemd

```bash
sudo systemctl <stop|start> snap.polkadot-parachain.polkadot-parachain.service
```

### Running polkadot-parachain from other snaps

Other snaps can call this snap to execute `polkadot-parachain` commands by connecting to the `bins` slot. This avoids getting `Permission denied` when calling `polkadot-parachain` from other snaps.

```bash
sudo snap connect <snap-name>:bins polkadot-parachain:bins
```
