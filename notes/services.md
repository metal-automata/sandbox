## Pointing to local services/repositories

Some of our services have moved to be self contained helm charts. They are included within Chart.yaml as dependencies.
 - [Fleetscheduler](https://github.com/metal-automata/fleet-scheduler) (OPTIONAL, enable in values.yaml fleetscheduler.enable)

### With the Makefile

`make <SERVICE>-local DIR=<RELATIVE-PATH>` will automatically swap out your `<SERVICE>` with the local repo of that service found at `<RELATIVE-PATH>`. DIR is optional, and defaults to the parent folder: `../`.

Example:
- Assuming [Fleet-Scheduler](https://github.com/metal-automata/fleet-scheduler) is cloned into the same parent directory as the sandbox.
- call `make fleet-scheduler-local` to now use the local service instead of the upstream service. Note: This will edit `Chart.yaml`, do not commit those changes!
- `make install` will now install the sandbox with the local service. Note: You must still build you app and push the docker image (using `make push-image-devel`).
  To revert back to upstream. call `make fleet-scheduler-upstream`.

### 1.1.2 Pointing to local services/repositories

To replace a dependency with a local version of the dependency you are working on, you can edit the dependency within the Chart.yaml, and can refer to the [helm docs](https://helm.sh/docs/helm/helm_dependency/) for more information.

For example: To replace fleet-scheduler's upstream helm chart with a local custom version, you must do the following:
- Clone [Fleet-Scheduler](https://github.com/metal-automata/fleet-scheduler). Preferably in the same directory as the [Sandbox](https://github.com/metal-automata/sandbox)
- Replace the repository URL for fleet-scheduler with the relative path (and prefixed with `file://`) to your cloned repository's chart folder, and make sure the versions match.
  - So if you have this in `parentFolder/fleet-scheduler/chart/Chart.yaml`:
    ```yaml
    apiVersion: v2
    name: fleet-scheduler
    version: v0.1.7
    description: A chart for fleet scheduled cron jobs
    ```
  - And the fleet-scheduler dependency within `parentFolder/sandbox/Chart.yaml` is this:
  ```yaml
  - name: fleet-scheduler
    version: v0.1.0
    repository: https://metal-automata.github.io/fleet-scheduler
  ```
  - `parentFolder/sandbox/Chart.yaml`'s fleet-scheduler dependency becomes this:
  ```yaml
  - name: fleet-scheduler
    version: v0.1.7
    repository: file://../fleet-scheduler/chart
  ```
  - Note: This is assuming the sandbox and fleet-scheduler have the same parent folder.
- Inform the Fleet-Scheduler helm chart you are using a local docker image instead of upstream
  - Within `parentFolder/sandbox/values.yaml`, you have this for your fleet-scheduler definition
  ```yaml
    fleet-scheduler:
      enable: true # when enabled, metal-automata/fleet-scheduler will need to be deployed with `make push-image-devel`
      <<: *image_anchor
      <<: *env_anchor
  ```
  - Change it to this to overwrite the image url and tag
  ```yaml
    fleet-scheduler:
      enable: true # when enabled, metal-automata/fleet-scheduler will need to be deployed with `make push-image-devel`
      <<: *image_anchor
      image:
        repository:
          tag: latest
          url: localhost:5001
      <<: *env_anchor
  ```
  - Then `cd` into the fleet-scheduler repository and run `make push-image-devel` to build and deploy the docker image for the helm chart to use.
