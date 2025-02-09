## k8s helm charts for the metal-automata sandbox.

This chart deploys the various metal-automata services in docker KIND for development and testing.

 - [FleetDB](https://github.com/metal-automata/fleetdb) with the CrDB backend.
 - [Conditionorc](https://github.com/metal-automata/conditionorc)
 - [Agent](https://github.com/metal-automata/agent)
 - NATS Jetstream and K/V
 - Chaos mesh

The [mctl](https://github.com/metal-automata/mctl/) utility can be used to interact with the various services running in the sandbox.

To understand more about the firmware install and how these services interact, check out the [firmware install architecture](https://github.com/metal-automata/architecture/blob/main/firmware-install-service.md) doc.

### Prerequisites

- Install docker. Test with `docker run hello-world`
- Install docker KIND `go install sigs.k8s.io/kind@v0.23.0`
- Setup a local KIND cluster with a registry using the script here: `./kind-with-registry.sh` (from https://kind.sigs.k8s.io/docs/user/local-registry/)
- Export `KUBECONFIG=~/.kube/config_kind`
- Docker images for FleetDB, Conditionorc, Alloy
- Install [mctl](https://github.com/metal-automata/mctl#getting-started) and use the configuration from [here](https://github.com/metal-automata/sandbox/tree/main/scripts/mctl)
- Install [yq](https://github.com/mikefarah/yq/). (MacOS: `brew install yq`; Linux: `snap install yq`)

### 1. Build docker images and push to local registry

Clone each of the repositories and run `make push-image-devel`

 - [FleetDB](https://github.com/metal-automata/fleetdb)
 - [Conditionorc](https://github.com/metal-automata/conditionorc)
 - [Agent](https://github.com/metal-automata/agent/)

This will build and push the container images to the local container registry.

If you fetched the sandbox beside the other projects, go into the sandbox directory and run:
```
for i in fleetdb agent conditionorc; do (cd ../${i}/ && make push-image-devel) ; done
```

### 2. Deploy helm chart

Deploys the helm chart and bootstrap the NATS Jetstream, K/V store.

```sh
make install
```

### 3. Create hardware vendor and models

This is required for each type of hardware vendor and model that needs to be managed with the automata systems

```
mctl create hardware-vendor --vendor-name supermetal
mctl create hardware-model --vendor-name supermetal --model-name x99gpu-h
```

### 3. Create servers

To run set [conditions](https://github.com/metal-automata/architecture/blob/main/firmware-install-service.md#conditions) on a server, they need to be enlisted in the sandbox `Serverservice`.

Note: this assumes the KIND environment on your machine can connect to server BMC IPs.

- Make sure the `FleetDB` and `PG` pods are running.
- In separate terminals, run `make port-forward-fleetdb`, `make port-forward-conditionorc-api`.
- Import a server using `mctl` ()

```sh
./mctl create server \
      --bmc-addr 192.168.1.1 \
      --bmc-user root \
      --bmc-pass hunter2 \
      --server ede81024-f62a-4288-8730-3fab8cceabcc \
      --facility sandbox

2024/03/06 10:13:57 status=200
msg=condition set
conditionID=fccf1b78-c073-4897-96bd-8c03bc3bc807
serverID=ede81024-f62a-4288-8730-3fab8cceabcc
```

Servers can also be imported in bulk
```
./mctl create server --from-file servers.json
```

```servers.json
[
  {
    "vendor": "supermetal",
    "model": "x99gpu-h",
    "facility_code": "sandbox",
    "bmc": {
      "hardware_vendor_name": "supermetal",
      "hardware_model_name": "x99gpu-h",
      "ipaddress": "192.168.2.102",
      "username": "ADMIN",
      "password": "ADMIN",
      "macaddress": "ca:ca:76:8b:de:ad"
    }
  }
]
```

### 4. Server and component inventory

Importing a server with the `mctl create server` command by default triggers an
inventory collection.

To collect inventory on demand, run
```sh
mctl collect inventory --server ede81024-f62a-4288-8730-3fab8cceabcc
```

Inventory collection status can be checked with,

```sh
mctl collect status --server ede81024-f62a-4288-8730-3fab8cceabcc
```

Inventory for a server can be listed with,

```sh
❯ ./mctl get server -s ede81024-f62a-4288-8730-3fab8cceab78 --list-components --table
+-------------------+---------+--------------------------------+------------------+-------------+--------+---------------+
|     COMPONENT     | VENDOR  |             MODEL              |      SERIAL      |     FW      | STATUS |   REPORTED    |
+-------------------+---------+--------------------------------+------------------+-------------+--------+---------------+
| bios              | -       | -                              |                0 | 2.13.3      | -      | 4 minutes ago |
| bmc               | dell    | PowerEdge R6515                |                0 | 6.10.30.20  | -      | 4 minutes ago |
| cpld              | -       | -                              |                0 | 1.0.7       | -      | 4 minutes ago |
| cpu               | amd     | AMD EPYC 7443P 24-Core         |                0 | 0xA0011D1   | -      | 4 minutes ago |
|                   |         | Processor                      |                  |             |        |               |
| drive             | intel   | SSDSCKKB240G8R                 | PHYH12430FOO     | DL6R        | -      | 4 minutes ago |
| drive             | samsung | MZ7LH480HBHQ0D3                | S5YJNA0R8BAR     | HG58        | -      | 4 minutes ago |
```

### 5. Run server/bmc power actions

Power off server
```sh
❯ mctl power --server ede81024-f62a-4288-8730-3fab8cceab78 --action off
```

Check action status
```sh
mctl power --server ede81024-f62a-4288-8730-3fab8cceab78 --action-status | jq .status
{
  "msg": "server power state set successful: off"
}
```

### 6 Import firmware definitions (optional)

Note: replace `ARTIFACTS_ENDPOINT` in [firmwares.json](./scripts/mctl/firmwares.json) with endpoint serving the firmware files.

Import firmware defs from sample file using `mctl`.

```sh
mctl create  firmware --from-file ./scripts/mctl/firmwares.json
```

### 7. Create a firmware set (optional)

List the firmware using `mctl list firmware` and create a set that can be applied to a server.

```sh
mctl create firmware-set --firmware-ids 5e574c96-6ba4-4078-9650-c52a64cc8cba,a7e86975-11a4-433d-9170-af53fcfc79bd \
                         --labels vendor=dell,model=r6515,latest=true \
                         --name r6515
```

### 8. Set a `firmwareInstall` condition on a server (optional)

With the server added, you can now get flasher to set a `firmwareInstall` condition,

```sh
make port-forward-conditionorc-api
```

```sh
mctl install firmware-set --server ede81024-f62a-4288-8730-3fab8cceabcc
```

Check condition status

```sh
mctl install status --server ede81024-f62a-4288-8730-3fab8cceabcc
```

### Upgrade/uninstall helm chart.

To upgrade the helm install after changes to the templates,

```
make upgrade
```

To uninstall the helm chart

```
make clean
```

## NATs Jetstream setup

The chart configures a NATS Jetstream that Orchestrator and the controllers sends messages on, the NATS Jetstream configuration is specified in [values.yaml](values.yaml).

Check out the [cheatsheet](notes/cheatsheet.md) to validate the Jetstream setup.

## Chaos mesh (optional)

The utility exposes a cool dashboard to run chaos experiments like dropping packets
from one app to another or such.


Install chaos mesh
```
helm install chaos-mesh  chaos-mesh/chaos-mesh -n=default --version 2.5.1 -f values.yaml
```


forward the dashboard port and run an experiment ! `http://localhost:2333/experiments`
```
make port-forward-chaos-dash
```

Uninstall chaos mesh
```
helm delete  chaos-mesh -n=default
```

## Firmware-syncer Test Environment

A test environment for firmware-syncer can be deployed post installation.

Check out the [setup guide](notes/firmware-syncer.md) for more information.

## Helm chart dependencies

To ensure the sandbox is self contained, make sure to update the helm chart depdendencies
when there are new dependencies in the templates.

Update helm dependencies - this will fetch the dependency chart as a tarball
```
helm dependency update
```

Git add in the new chart tarball, and PR changes.
```
git add charts/postgres-2.7.1.tgz
```

### Run `make help` for a list of available commands.

```
❯ make

Usage:
  make <targets>

Targets:
  install                          install helm chart for the sandbox env with fleetdb(default)
  upgrade                          upgrade helm chart for the sandbox environment
  clean                            uninstall helm chart
  port-forward-condition-api       port forward conditions API (runs in foreground)
  port-forward-condition-orc-api   port forward conditions Orchestrator API (runs in foreground)
  port-forward-agent-pprof         port forward condition Alloy pprof endpoint  (runs in foreground)
  port-forward-fleetdb             port forward fleetdb port (runs in foreground)
  port-forward-pg                  port forward pg service port (runs in foreground)
  port-forward-chaos-dash          port forward chaos-mesh dashboard (runs in foreground)
  port-forward-jaeger-dash         port forward jaeger frontend
  port-forward-otel                port forward otel server
  port-forward-minio               port forward to the minio S3 port
  port-all-with-lan                port forward all endpoints (runs in the background)
  port-all                         port forward all endpoints (runs in the background)
  kill-all-ports                   kill all port fowarding processes that are running in the background
  firmware-syncer-env              install extra services used to test firmware-syncer
  firmware-syncer-env-clean        Remove extra services installed for firmware-syncer testing
  firmware-syncer-job              create a firmware-syncer job
  firmware-syncer-job-clean        remove the firmware-syncer job
  psql                             connect to postgres with psql (requires port-forward-pg)
  bootstrap-nats                   bootstrap just the nats setup - after an updated configurtion
  clean-nats                       purge nats app and related storage pvcs
  kubectl-ctx-kind                 set kube ctx to kind cluster
  %-local                          Change service to local service instead of upstream. DIR is optional, defaults to "../".
                                   -Example: `make fleetdb-local ../services/fleetdb` will tell sandbox to use ../services/fleetdb instead of the upstream
                                   -Note: Use `make fleetdb-upstream` to revert this process
  %-upstream                       Change service to upstream service instead of local.
                                   -Example: `make fleetdb-upstream` will tell sandbox to use the upstream (https://metal-automata.github.io/fleetdb) fleetdb.
  %-info                           Get some meta info about a service.
                                   -Example: `make fleetdb-info`
  %-log                            Tail logs of a service
  %-bash                           Enter a pod with bash
  help                             Show help
```
