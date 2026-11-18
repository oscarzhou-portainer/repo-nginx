#!/bin/sh
# Kill every running container of a Swarm service, the way an OOM kill would,
# then wait for Swarm to replace them. Repeat to build up failed task history.
#
# Run it on a manager node. The containers can be on any node: each round starts
# a one-off global job that runs `docker kill` on every node of the Swarm.
#
# Usage: ./kill.sh <service> [rounds]
set -eu

service=$1
rounds=${2:-4}
killer=kill-$service

if ! docker service inspect "$service" >/dev/null 2>&1; then
  echo "service $service not found, check the name with: docker service ls" >&2
  exit 1
fi

trap 'docker service rm "$killer" >/dev/null 2>&1 || true' EXIT

for round in $(seq 1 "$rounds"); do
  docker service create --quiet --name "$killer" --mode global-job \
    --mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
    docker:cli sh -c "ids=\$(docker ps -q --filter label=com.docker.swarm.service.name=$service); [ -z \"\$ids\" ] || docker kill \$ids" \
    >/dev/null
  docker service rm "$killer" >/dev/null
  echo "round $round: killed, waiting for Swarm to restart the tasks"
  sleep 10
done

docker service ps --no-trunc --format '{{.Name}}\t{{.Node}}\t{{.DesiredState}}\t{{.CurrentState}}\t{{.Error}}' "$service"
