#!/bin/sh
# Kill every running container of a Swarm service, the way an OOM kill would,
# then wait for Swarm to replace them. Repeat to build up failed task history.
# Usage: ./kill.sh <service> [rounds]
set -eu

service=$1
rounds=${2:-4}

for round in $(seq 1 "$rounds"); do
  docker kill $(docker ps -q --filter "label=com.docker.swarm.service.name=$service") >/dev/null
  echo "round $round: killed, waiting for Swarm to restart the tasks"
  sleep 10
done

docker service ps --no-trunc --format '{{.Name}}\t{{.DesiredState}}\t{{.CurrentState}}\t{{.Error}}' "$service"
