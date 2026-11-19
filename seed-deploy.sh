#!/bin/bash

set -eu
set -o pipefail

source ~/deployment/src/kayobe/dev/functions

function main {
    config_init

    environment_setup

    control_host_bootstrap

    run_kayobe seed vm provision
    run_kayobe seed host configure
    run_kayobe playbook run ~/deployment/src/kayobe-config/etc/kayobe/ansible/pull-retag-push.yml
    run_kayobe seed service deploy
}

main
