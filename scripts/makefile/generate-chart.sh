#!/bin/bash

# Generate files for local service overriding

. ./scripts/makefile/functions.sh

diff -q Chart.yaml.tmpl Chart.yaml
if [ $? -ne 0 ];
then
	echo "fix differences in Chart.yaml.tmpl and rerun"
	exit 1
fi

cp Chart.yaml.tmpl Chart.yaml

LENGTH=$(yq ".localrepos | length" $TEMPFILE)

for ((I=0;I<LENGTH;I++)); do
	SERVICE=$(yq ".localrepos.[$I].name" .local-values.yaml)
	RELPATH=$(yq ".localrepos.[$I].relpath" .local-values.yaml)

	CHARTDIR=$(echo "$RELPATH/$SERVICE/chart" | tr -s '/')
	CHARTYAML=$(echo "$CHARTDIR/Chart.yaml" | tr -s '/')
	CHARTVERSION=$(cat $CHARTYAML | yq ".version")
	OBJECT="{\"name\":\"$SERVICE\",\"version\":\"$CHARTVERSION\", \"repository\":\"file://$CHARTDIR\"}"

	FOUND_SERVICE=$(yq ".dependencies.[] | select(.name == \"$SERVICE\")" Chart.yaml)
	if [[ $FOUND_SERVICE == "" ]]; then
		yq -i ".dependencies += [$OBJECT]" Chart.yaml
	else
		yq -i "(.dependencies.[] | select(.name == \"$SERVICE\")) = $OBJECT" Chart.yaml
	fi
done
