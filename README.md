# Kayobe on Packet

This Terraform deployment reproduces the environment for [a universe from
seed](https://github.com/stackhpc/a-universe-from-nothing) workshop on Packet.

# Software Components

[Kayobe](https://kayobe.readthedocs.io/) enables deployment of containerised OpenStack to bare metal.

## Prerequisites

Ensure that the lab users have the following entry in their `~/.ssh/config`:

    Host lab
      User root
      HostName 139.178.64.215
      IdentityFile ~/.ssh/id_rsa
      PreferredAuthentications password

Then login to the node by running and entering the provided password:

    ssh lab

It is recommeded that you run `passwd` immediately to change the default password.

## Nested virtualisation

You need to have a machine that can support nested virtualisation.

To check if you have virtualisation enabled on the host, try:

```bash
$ egrep --color 'vmx|svm' /proc/cpuinfo
```

and look for **vmx** or **svm** coloured red in the output.

## Initial seed deployment

Ensure that the initialsation steps are complete by looking at the log:

    tail -f screenlog.0

When complete, it should report an elapsed time as follows:

    61 minutes and 3 seconds elapsed.

## Inspect the docker container and images inside your seed VM:

    ssh stack@192.138.33.5

# Configuring bare metal cloud using Kayobe

Look at the steps involved in deploying Kayobe inside `configure-kayobe.sh`. To run the script:

    bash configure-kayobe.sh

## Wrapping up

Join the discussion at #openstack-kayobe channel on IRC.
