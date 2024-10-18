.DEFAULT_GOAL := help

# local-port:service-port
CONDITION_API_PORT_FW=9001:9001
CONDITION_ORC_API_PORT_FW=9002:9001
ALLOY_PORT_FW=9091:9091
FLEETDB_PORT_FW=8000:8000
PG_PORT_FW=5432:5432
CHAOS_DASH_PORT_FW=2333:2333
JAEGER_DASH_PORT_FW=16686:16686
OTEL_PORT_FW=4317:4317
MINIO_PORT_FW=9000:9000

ifneq (,$(wildcard .local-values.yaml))
	OVERRIDE_VALUES_YAML=-f .local-values.yaml
else
	OVERRIDE_VALUES_YAML=
endif

## install helm chart for the sandbox env with fleetdb(default)
install: kubectl-ctx-kind
	cp ./scripts/nats-bootstrap/values-nats.yaml.tmpl values-nats.yaml
	./scripts/makefile/generate-chart.sh
	helm dependency update
	helm install hollow-sandbox . -f values.yaml -f values-nats.yaml ${OVERRIDE_VALUES_YAML}
	kubectl get pod
	./scripts/nats-bootstrap/boostrap.sh

## upgrade helm chart for the sandbox environment
upgrade: kubectl-ctx-kind
	helm upgrade hollow-sandbox . -f values.yaml -f values-nats.yaml ${OVERRIDE_VALUES_YAML}

## uninstall helm chart
clean: kubectl-ctx-kind
	helm uninstall hollow-sandbox
	rm values-nats.yaml
	./scripts/wait-clean.sh

## port forward conditions API (runs in foreground)
port-forward-condition-api: kubectl-ctx-kind
	kubectl port-forward deployment/conditions-api ${CONDITION_API_PORT_FW}

## port forward conditions Orchestrator API (runs in foreground)
port-forward-condition-orc-api: kubectl-ctx-kind
	kubectl port-forward deployment/conditionorc ${CONDITION_ORC_API_PORT_FW}


## port forward condition Alloy pprof endpoint  (runs in foreground)
port-forward-alloy-pprof: kubectl-ctx-kind
	kubectl port-forward deployment/alloy ${ALLOY_PORT_FW}

## port forward fleetdb port (runs in foreground)
port-forward-fleetdb: kubectl-ctx-kind
	kubectl port-forward deployment/fleetdb ${FLEETDB_PORT_FW}

## port forward pg service port (runs in foreground)
port-forward-pg: kubectl-ctx-kind
	kubectl port-forward service/postgresql ${PG_PORT_FW}

## port forward chaos-mesh dashboard (runs in foreground)
port-forward-chaos-dash: kubectl-ctx-kind
	kubectl port-forward service/chaos-dashboard ${CHAOS_DASH_PORT_FW}

## port forward jaeger frontend
port-forward-jaeger-dash:
	kubectl port-forward service/jaeger ${JAEGER_DASH_PORT_FW}

## port forward otel server
port-forward-otel:
	kubectl port-forward deployment/jaeger ${OTEL_PORT_FW}

## port forward to the minio S3 port
port-forward-minio:
	kubectl port-forward deployment/minio ${MINIO_PORT_FW}


## port forward all endpoints (runs in the background)
port-all-with-lan:
	kubectl port-forward deployment/conditions-api --address 0.0.0.0 ${CONDITION_API_PORT_FW} > /dev/null 2>&1 &
	kubectl port-forward deployment/alloy --address 0.0.0.0 ${ALLOY_PORT_FW} > /dev/null 2>&1 &
	kubectl port-forward service/postgresql --address 0.0.0.0 ${PG_PORT_FW} > /dev/null 2>&1 &
	kubectl port-forward deployment/fleetdb --address 0.0.0.0 ${FLEETDB_PORT_FW} > /dev/null 2>&1 &
	kubectl port-forward service/chaos-dashboard --address 0.0.0.0 ${CHAOS_DASH_PORT_FW} > /dev/null 2>&1 &
	kubectl port-forward service/jaeger --address 0.0.0.0 ${JAEGER_DASH_PORT_FW} > /dev/null 2>&1 &
	kubectl port-forward deployment/minio --address 0.0.0.0 ${MINIO_PORT_FW} > /dev/null 2>&1

port-all:
	kubectl port-forward deployment/conditions-api ${CONDITION_API_PORT_FW} > /dev/null 2>&1 &
	kubectl port-forward deployment/alloy ${ALLOY_PORT_FW} > /dev/null 2>&1 &
	kubectl port-forward service/postgresql ${PG_PORT_FW} > /dev/null 2>&1 &
	kubectl port-forward deployment/fleetdb ${FLEETDB_PORT_FW} > /dev/null 2>&1 &
	kubectl port-forward service/chaos-dashboard ${CHAOS_DASH_PORT_FW} > /dev/null 2>&1 &
	kubectl port-forward service/jaeger ${JAEGER_DASH_PORT_FW} > /dev/null 2>&1 &
	kubectl port-forward deployment/minio ${MINIO_PORT_FW} > /dev/null 2>&1

## kill all port fowarding processes that are running in the background
kill-all-ports:
	lsof -i:${CONDITION_API_PORT_FW} -t | xargs kill
	lsof -i:${ALLOY_PORT_FW} -t | xargs kill
	lsof -i:${FLEETDB_PORT_FW} -t | xargs kill
	lsof -i:${PG_PORT_FW} -t | xargs kill
	lsof -i:${CHAOS_DASH_PORT_FW} -t | xargs kill
	lsof -i:${JAEGER_DASH_PORT_FW} -t | xargs kill
	lsof -i:${MINIO_PORT_FW} -t | xargs kill

## install extra services used to test firmware-syncer
firmware-syncer-env:
	helm upgrade hollow-sandbox . -f values.yaml -f values-nats.yaml --set syncer.enable_env=true
	./scripts/minio-dns-setup.sh set

## Remove extra services installed for firmware-syncer testing
firmware-syncer-env-clean:
	helm rollback hollow-sandbox
	./scripts/minio-dns-setup.sh clear

## create a firmware-syncer job
firmware-syncer-job:
	helm template syncer . --set syncer.enable_job=true | kubectl apply -f - -l app=syncer-job

## remove the firmware-syncer job
firmware-syncer-job-clean:
	helm template syncer . --set syncer.enable_job=true | kubectl delete -f - -l app=syncer-job

## connect to postgres with psql (requires port-forward-pg)
psql: kubectl-ctx-kind
	psql -d "postgresql://user:hunter2@localhost:5432/fleetdb?sslmode=disable"

## bootstrap just the nats setup - after an updated configurtion
bootstrap-nats: clean-nats
	./scripts/nats-bootstrap/boostrap.sh

## purge nats app and related storage pvcs
clean-nats:
	kubectl delete statefulsets.apps nats --wait=true && kubectl delete pvc nats-js-pvc-nats-0 nats-jwt-pvc-nats-0

## set kube ctx to kind cluster
kubectl-ctx-kind:
	export KUBECONFIG=~/.kube/config_kind
	kubectl config use-context kind-kind

## Change service to local service instead of upstream. DIR is optional, defaults to "../".
## Example: `make fleet-scheduler-local ../services/fleet-scheduler` will tell sandbox to use ../services/fleet-scheduler instead of the upstream
## Note: Use `make fleet-scheduler-upstream` to revert this process
%-local:
	$(eval DIR ?= ../)
	@./scripts/makefile/set-service-to-local.sh $(subst -local,,$@) ${DIR}

## Change service to upstream service instead of local.
## Example: `make fleet-scheduler-upstream` will tell sandbox to use the upstream (https://metal-automata.github.io/fleet-scheduler) fleet-scheduler.
%-upstream:
	@touch .local-values.yaml
	@yq -i "del(.localrepos.[] | select(.name == \"$(subst -upstream,,$@)\"))" .local-values.yaml

## Get some meta info about a service.
## Example: `make fleet-scheduler-info`
%-info:
	@./scripts/makefile/get-service-info.sh $(subst -info,,$@)

## Tail logs of a service
%-log:
	kubectl logs -f $$(kubectl get pods | grep -Po '$(subst -log,,$@)-([0-9]|[a-z])*-([0-9]|[a-z])* ')

## Enter a pod with bash
%-bash:
	kubectl exec -ti $$(kubectl get pods | grep -Po '$(subst -bash,,$@)-([0-9]|[a-z])*-([0-9]|[a-z])* ') -- /bin/sh

## Show help
help:
	@./scripts/makefile/help.awk ${MAKEFILE_LIST}
