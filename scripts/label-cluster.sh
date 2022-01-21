#!/usr/bin/env bash

WORKER_NODES=$(kubectl get node --selector='!node-role.kubernetes.io/master' -o=name)
WORKER_NODES_COUNT=$(kubectl get node --selector='!node-role.kubernetes.io/master' -o=name | wc -l)

echo "Worker node count: ${WORKER_NODES_COUNT}"

if [ ${WORKER_NODES_COUNT} -lt 10 ]; then
  MS_NAME=$(oc get machinesets -n openshift-machine-api -o=jsonpath='{.items[0].metadata.name}')
  NODE_DIFF=$((10 - ${WORKER_NODES_COUNT}))
  CUR_MS_REP=$(oc get machinesets ${MS_NAME} -n openshift-machine-api -o=jsonpath='{.spec.replicas}')
  NEW_REP=$(($NODE_DIFF + $CUR_MS_REP))
  oc patch machinesets ${MS_NAME} -n openshift-machine-api -p "{\"spec\":{\"replicas\":${NEW_REP}}"
  sleep 60
fi

READY="false"
while [[ ${READY} == "false" ]]; do
  if [[ $(kubectl get node --selector='!node-role.kubernetes.io/master' -o=name | wc -l) -eq 10 ]]; then
    READY="true"
  fi
done

INFRA_NODES_COUNT=2
CONNECT_NODES_COUNT=3

WORKER_NODES_ARRAY=(${WORKER_NODES// / })

for index in "${!WORKER_NODES_ARRAY[@]}"; do
  if [ ${index} -lt ${INFRA_NODES_COUNT} ]; then
    echo "Labeling node: $index client-node -> ${WORKER_NODES_ARRAY[index]}"
    kubectl label ${WORKER_NODES_ARRAY[index]} nodetype=infra --overwrite
  elif [ ${index} -lt $((INFRA_NODES_COUNT + CONNECT_NODES_COUNT)) ]; then
    echo "Labeling node: $index connect-cluster-node -> ${WORKER_NODES_ARRAY[index]}"
    kubectl label ${WORKER_NODES_ARRAY[index]} nodetype=connect --overwrite
  else
    echo "Labeling node: $index main-cluster-node -> ${WORKER_NODES_ARRAY[index]}"
    kubectl label ${WORKER_NODES_ARRAY[index]} nodetype=kafka --overwrite
  fi
done
