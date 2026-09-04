#!/usr/bin/env bash

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."


SERVICE="${1:-}"


if [[ -n "${SERVICE}" ]]
then

    docker compose logs -f "${SERVICE}"

else

    docker compose logs -f

fi
