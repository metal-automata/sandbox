#!/bin/bash

# - `Accounts` group users and Jetstream support is enabled/disabled at the account level NOTE: pub/sub permissions set at the Account level are not inherited by users of that account.
# - `Signing keys` are associated with accounts and can be 'templated' with pub/sub permissions and have a `role` name set.
# - `Users` are applications connecting to NATS to pub/sub, users can be assigned a `role`.

source scripts/nats-bootstrap/validation.sh

function clean_natsserver() {
	set +e
	kubectl get statefulsets | grep nats && make clean-nats

	set -e
}

function init_natsserver() {
	kubectl get pods
	make upgrade
	kubectl get pods
}

function clean_natsbox() {
	set -e
	kubectl exec -ti deployments/nats-box -- rm -rf /root/*.* /nsc
	set +e
}

function init_natsaccounts() {
	while ! kubectl get pods | awk '/nats-box/{print $3}' | grep "Running"; do
		echo "waiting for nats-box to be ready... "
		sleep 5
	done

	kubectl exec -ti deployments/nats-box -- /bin/sh <<'EOF'

set -e

echo '
# NSC Environment Setup
export NKEYS_PATH=/root/nsc/nkeys
export NSC_HOME=/root/nsc/accounts
' > /root/.nsc.env

source /root/.nsc.env

mkdir -p $NSC_HOME
mkdir -p "$NKEYS_PATH"

# create operator account
nsc add operator --name KO
nsc edit operator --service-url nats://nats:4222
nsc edit operator --account-jwt-server-url nats://nats:4222

# Create system account - required to interact with the nats server
nsc add account --name SYS
nsc add user --name sys

# create controllers Jetstream account - with permissions to list, create JS streams
nsc add account --name controllers
nsc edit account --name controllers --js-disk-storage 256M --js-mem-storage -1 --js-consumer -1 --js-streams -1

# generate a signing key to create a controllers role
# so we can attach various pubsub permissions to the role
nsc edit account --sk generate --name controllers
SK_A=$(nsc describe account controllers -J | jq .nats.signing_keys[0] -r)
nsc edit signing-key -a controllers --sk ${SK_A} --role controllers

# https://docs.nats.io/reference/reference-protocols/nats_api_reference
nsc edit signing-key -a controllers --sk ${SK_A} \
	--allow-pubsub '$KV.>' \
	--allow-pubsub '$JS.API.DIRECT.GET.>' \
	--allow-pubsub '$JS.API.INFO' \
	--allow-pubsub '$JS.API.STREAM.INFO.controllers' \
	--allow-pubsub '$JS.API.STREAM.NAMES' \
	--allow-pubsub '$JS.API.STREAM.LIST' \
	--allow-pubsub '$JS.API.STREAM.CREATE.controllers' \
	--allow-pubsub '$JS.API.STREAM.UPDATE.controllers' \
	--allow-pubsub '$JS.API.STREAM.PURGE.controllers' \
	--allow-pubsub '$JS.API.STREAM.MSG.DELETE.controllers' \
	--allow-pubsub '$JS.API.STREAM.MSG.GET.controllers' \
	--allow-pubsub '$JS.API.CONSUMER.NAMES.controllers' \
	--allow-pubsub '$JS.API.CONSUMER.INFO.controllers.>' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.controllers.>' \
	--allow-pubsub '$JS.API.CONSUMER.MSG.NEXT.controllers.>' \
	--allow-pubsub '$JS.API.CONSUMER.DELETE.controllers.>' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_tasks' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_tasks.>' \
	--allow-pubsub '$JS.API.CONSUMER.DELETE.KV_tasks.>' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_firmwareInstall' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_firmwareInstall.>' \
	--allow-pubsub '$JS.API.CONSUMER.DELETE.KV_firmwareInstall.>' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_firmwareInstallInband' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_firmwareInstallInband.>' \
	--allow-pubsub '$JS.API.CONSUMER.DELETE.KV_firmwareInstallInband.>' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_serverControl' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_serverControl.>' \
	--allow-pubsub '$JS.API.CONSUMER.DELETE.KV_serverControl.>' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_biosControl' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_biosControl.>' \
	--allow-pubsub '$JS.API.CONSUMER.DELETE.KV_biosControl.>' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_inventory' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_inventory.>' \
	--allow-pubsub '$JS.API.CONSUMER.DELETE.KV_inventory.>' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_active-controllers' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_active-controllers.>' \
	--allow-pubsub '$JS.API.CONSUMER.DELETE.KV_active-controllers.>' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_active-conditions' \
	--allow-pubsub '$JS.API.CONSUMER.CREATE.KV_active-conditions.>' \
	--allow-pubsub '$JS.API.CONSUMER.DELETE.KV_active-conditions.>' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_active-conditions' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_active-conditions.>' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_active-conditions' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_active-conditions.>' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_active-controllers' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_active-controllers.>' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_active-controllers' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_active-controllers.>' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_tasks' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_tasks.>' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_tasks' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_tasks.>' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_firmwareInstall' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_firmwareInstall.>' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_firmwareInstall' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_firmwareInstall.>' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_firmwareInstallInband' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_firmwareInstallInband.>' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_firmwareInstallInband' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_serverControl' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_serverControl.>' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_serverControl' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_serverControl.>' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_broker' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_broker.>' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_broker-tasks' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_broker' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_broker.>' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_broker-tasks' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_biosControl' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_biosControl.>' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_biosControl' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_biosControl.>' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_inventory' \
	--allow-pubsub '$JS.API.STREAM.INFO.KV_inventory.>' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_inventory' \
	--allow-pubsub '$JS.API.STREAM.CREATE.KV_inventory.>' \
	--allow-pubsub '$JS.ACK.controllers.>' \
	--allow-pubsub 'com.hollow.sh.controllers.>' \
	--allow-sub 'com.hollow.sh.controllers.commands.>' \
	--allow-pubsub 'com.hollow.sh.controllers.responses' \
        --allow-sub '_INBOX.>'

for controller in conditionorc agent; do
   nsc add user -a controllers --name ${controller} -K controllers
done

EOF
}

function kuexec() {
	kubectl exec -ti deployments/nats-box -- /bin/sh -c \
		"NKEYS_PATH=/root/nsc/nkeys NSC_HOME=/root/nsc/accounts && $1"
}

function push_natsaccounts() {
	while ! kubectl logs statefulsets/nats nats | head -100 | grep "Server is ready"; do
		echo "waiting for nats server to be ready to push accounts... "
		sleep 5
	done

	while ! kubectl exec -ti deployments/nats-box -- ping nats -W 1 -c 1; do
		echo "waiting for nats service to be accessible on k8s.."
		sleep 5
	done

	kuexec "nsc push --system-account SYS -u nats://nats:4222 -A"
}

function update_values_nats_yaml() {
	set -x
	f=values-nats.yaml.bk
	cp values-nats.yaml $f

	CURRENT_OPKEY=$(awk '/operator: /{print $2}' $f)
	CURRENT_SYSKEY=$(awk '/systemAccount: /{print $2}' $f)
	CURRENT_SYSPRELOADKEY=$(grep resolverPreload -a1 $f | grep $CURRENT_SYSKEY | awk -F': ' '/: /{print $2}')

	OPKEY=$(kuexec "nsc generate config --sys-account SYS --nats-resolver | awk  '/operator: /{print \$2}' | tr -d '\\r' ")
	SYSKEY=$(kuexec "nsc generate config --sys-account SYS --nats-resolver | awk '/system_account: /{print \$2}' | tr -d '\\r' ")
	SYSPRELOADKEY=$(kuexec "nsc generate config --sys-account SYS  --nats-resolver |  \
	grep resolver_preload -A1 | sed -e 's/,//g' -e 's/{//g'  | awk -F': ' '/: /{print \$2}' | tr -d '\r' ")

	OPKEY=$(echo $OPKEY | tr -d '\r')
	SYSKEY=$(echo $SYSKEY | tr -d '\r')
	SYSPRELOADKEY=$(echo $SYSPRELOADKEY | tr -d '\n' | tr -d '\r' | tr -d ' ')
	sed -ie 's/operator: '${CURRENT_OPKEY}'/operator: '${OPKEY}'/' $f
	sed -ie 's/systemAccount: '${CURRENT_SYSKEY}'/systemAccount: '${SYSKEY}'/' $f
	sed -ie 's/'${CURRENT_SYSKEY}': '${CURRENT_SYSPRELOADKEY}'/'${SYSKEY}': '${SYSPRELOADKEY}'/' $f

	mv $f values-nats.yaml
}

function push_controller_secrets() {
	for controller in conditionorc agent; do
		sekrit=$(kuexec "cat /root/nsc/nkeys/creds/KO/controllers/${controller}.creds" | "${os_base64[@]}" -w 0)
		push_secret "${sekrit}" ${controller}
	done
}

function push_secret() {
	sekrit=$1
	name=$2

	cat <<-EOF | kubectl apply -f -
		apiVersion: v1
		metadata:
		  name: ${name}-secrets
		  namespace: default
		data:
		  ${name}-nats-creds: ${sekrit}
		kind: Secret
		type: Opaque
	EOF
}

function reload_controller_deployments() {
	echo "restarting controller deployments for NATSs changes to take effect..."
	kubectl delete deployments.apps -l kind=controller
	make upgrade
}

function backup_accounts() {
	kuexec "cd / && tar -czf nats-accounts.tar.gz /root/nsc /nsc"
	kubectl cp $(kubectl get pods | awk '/nats-box/{print $1}'):/nats-accounts.tar.gz ./scripts/nats-bootstrap/nats-accounts.tar.gz
}

function restore_accounts() {
	set -x
	kubectl cp ./scripts/nats-bootstrap/nats-accounts.tar.gz $(kubectl get pods | awk '/nats-box/{print $1}'):/nats-accounts.tar.gz
	kuexec "cd / && tar -xvzf nats-accounts.tar.gz && nsc push --system-account SYS -u nats://nats:4222 -A"
}
