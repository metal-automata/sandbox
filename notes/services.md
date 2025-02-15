## Pointing to local services/repositories

Some of our services have moved to be self contained helm charts. They are included within Chart.yaml as dependencies.
 - [Fleetscheduler](https://github.com/metal-automata/fleetdb) (OPTIONAL, enable in values.yaml fleetscheduler.enable)

### With the Makefile

`make <SERVICE>-local DIR=<RELATIVE-PATH>` will automatically swap out your `<SERVICE>` with the local repo of that service found at `<RELATIVE-PATH>`. DIR is optional, and defaults to the parent folder: `../`.

Example:
- Assuming [Fleet-Scheduler](https://github.com/metal-automata/fleetdb) is cloned into the same parent directory as the sandbox.
- call `make fleetdb-local` to now use the local service instead of the upstream service. Note: This will edit `Chart.yaml`, do not commit those changes!
- `make install` will now install the sandbox with the local service. Note: You must still build you app and push the docker image (using `make push-image-devel`).
  To revert back to upstream. call `make fleetdb-upstream`.

### 1.1.2 Pointing to local services/repositories

To replace a dependency with a local version of the dependency you are working on, you can edit the dependency within the Chart.yaml, and can refer to the [helm docs](https://helm.sh/docs/helm/helm_dependency/) for more information.

For example: To replace fleetdb's upstream helm chart with a local custom version, you must do the following:
- Clone [Fleet-Scheduler](https://github.com/metal-automata/fleetdb). Preferably in the same directory as the [Sandbox](https://github.com/metal-automata/sandbox)
- Replace the repository URL for fleetdb with the relative path (and prefixed with `file://`) to your cloned repository's chart folder, and make sure the versions match.
  - So if you have this in `parentFolder/fleetdb/chart/Chart.yaml`:
    ```yaml
    apiVersion: v2
    name: fleetdb
    version: v0.1.7
    description: A chart for fleet scheduled cron jobs
    ```
  - And the fleetdb dependency within `parentFolder/sandbox/Chart.yaml` is this:
  ```yaml
  - name: fleetdb
    version: v0.1.0
    repository: https://metal-automata.github.io/fleetdb
  ```
  - `parentFolder/sandbox/Chart.yaml`'s fleetdb dependency becomes this:
  ```yaml
  - name: fleetdb
    version: v0.1.7
    repository: file://../fleetdb/chart
  ```
  - Note: This is assuming the sandbox and fleetdb have the same parent folder.
- Inform the Fleet-Scheduler helm chart you are using a local docker image instead of upstream
  - Within `parentFolder/sandbox/values.yaml`, you have this for your fleetdb definition
  ```yaml
    fleetdb:
      enable: true # when enabled, metal-automata/fleetdb will need to be deployed with `make push-image-devel`
      <<: *image_anchor
      <<: *env_anchor
  ```
  - Change it to this to overwrite the image url and tag
  ```yaml
    fleetdb:
      enable: true # when enabled, metal-automata/fleetdb will need to be deployed with `make push-image-devel`
      <<: *image_anchor
      image:
        repository:
          tag: latest
          url: localhost:5001
      <<: *env_anchor
  ```
  - Then `cd` into the fleetdb repository and run `make push-image-devel` to build and deploy the docker image for the helm chart to use.
