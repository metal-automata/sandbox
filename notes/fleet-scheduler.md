# Fleet Scheduler

[Fleet Scheduler](https://github.com/metal-automata/fleet-scheduler) is an optional part of the sandbox. It uses k8s cron jobs to complete tasks for the sandbox.

For deployment to the sandbox, fleetscheduler.enable in [value.yaml](https://github.com/metal-automata/sandbox/blob/main/values.yaml) must be set to true, and the docker image must be pushed with `make push-image-devel`

You just need to add the job to the [value.yaml](https://github.com/metal-automata/sandbox/blob/main/values.yaml) file.

## Values for creating new jobs

Job Values required and location to explain them with `kubectl explain <field>`

- _name_: cronjob.metadata.name
- _restartPolicy_: cronjob.spec.jobTemplate.spec.template.spec.restartPolicy
- _imagePullPolicy_: cronjob.spec.jobTemplate.spec.template.spec.containers.imagePullPolicy
- _image_ and _tag_: cronjob.spec.jobTemplate.spec.template.spec.containers.image
- - Combined, these two values make up `cronjob.spec.jobTemplate.spec.template.spec.containers.image` like so: `${image}:${tag}`
- _ttlSecondsAfterFinished_: cronjob.spec.jobTemplate.spec.ttlSecondsafterFinished
- - This value is optional, and can be ommited
- _startingDeadlineSeconds_: cronjob.spec.startingDeadlineSeconds
- - This value is optional, and can be ommited
- _schedule_ cronjob.spec.schedule
- - Note: Does not accept cron format with second level precision. Only minute level precision
- _command_: cronjob.spec.jobTemplate.spec.template.spec.containers.command
- - This is the task to be run. Each command argument much be on a new line in array format like [so](https://stackoverflow.com/a/33136212/16289779)
- - First item in the array needs to be the binary of fleet-scheduler. Which will be `/usr/sbin/fleet-scheduler`

Example of getting details of a value with kubectl

```shell
$ kubectl explain cronjob.metadata.name
```

will give you this

```shell
KIND:       Pod
VERSION:    v1

FIELD: name <string>

DESCRIPTION:
    Name must be unique within a namespace. Is required when creating resources,
    although some resources may allow a client to request the generation of an
    appropriate name automatically. Name is primarily intended for creation
    idempotence and configuration definition. Cannot be updated. More info:
    https://kubernetes.io/docs/concepts/overview/working-with-objects/names#names

```

