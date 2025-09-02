# Polkadot - snap

Basically the polkadot-parachain service built as a snap.

## Building the snap

Clone the repo, then build with snapcraft

```
sudo snap install snapcraft --classic
cd snap-polkadot-parachain
snapcraft pack --use-lxd --debug --verbosity=debug # Takes some time.
```

## Upgrading Polkadot version

Simply change the version number here: https://github.com/dwellir-public/snap-polkadot-parachain/blob/main/snap/snapcraft.yaml#L58 and then of course rebuild.

## Releasing

When a commit is made to the main branch a build will start in launchpad and if successful release to the edge channel.
To promote further follow the instructions in [this document](TESTING.md)

Promoting can be done either from [this webpage](https://snapcraft.io/polkadot-parachain/releases)
or by running
`snapcraft release polkadot-parachain <revision> <channel>`

## Hardware requirements

See https://wiki.polkadot-parachain.network/docs/maintain-guides-how-to-validate-polkadot-parachain#standard-hardware

## Install snap

`sudo snap install <snap-file> --devmode`
or from snap store
`sudo snap install polkadot-parachain`

### Configuration

#### service-args

```sudo snap set polkadot-parachain service-args="<my service args>"```

For available arguments see https://github.com/paritytech/polkadot-parachain-sdk

Example:

```
sudo snap set polkadot-parachain service-args="--base-path=/var/snap/polkadot-parachain/common/polkado_base \
--name DWELLIR-NODE \
--chain kusama \
--prometheus-external \
--pruning archive \
--rpc-external \
--rpc-port=9933 \
--rpc-cors all \
--rpc-methods Safe \
--rpc-max-connections=1000"
```

#### endure

```sudo snap set polkadot-parachain endure=true|false```

If true the Polkadot service will not be restarted after a snap refresh.
Note that the Polkadot service will still be restarted as the result of changing service-args, etc.

Use this when restarts should be avoided e.g. when running a validator.

#### Changing base-path outside of the SNAP_COMMON directory
Setting an alternative base-path can be done by connecting the snap removable-media interface This allows the snap to access external filsystems/dirs (see: snap interface removable-media)

    sudo snap connect polkadot-parachain:removable-media

Configure your startup parameters (written to /var/snap/polkadot-parachain/common/service-arguments). 

    sudo snap set polkadot-parachain service-args='--base-path /mnt/polkadot-parachain/'


### Start the service

`sudo snap start polkadot-parachain`

### Check logs from polkadot-parachain

`sudo snap logs polkadot-parachain -f`

### Stop the service

`sudo snap stop polkadot-parachain`

### Alternatively - use systemd

`sudo systemctl <stop|start> snap.polkadot-parachain.polkadot-parachain.service`
