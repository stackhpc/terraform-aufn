# Terraform for "A Universe From Nothing" Lab

Terraform for the following configuration:

* OpenStack virtualised instances
* Cinder volumes for instance storage
* Floating IPs for networking

This Terraform deployment reproduces the environment for [a universe from
nothing](https://github.com/stackhpc/a-universe-from-nothing) workshop on
OpenStack infrastructure.

## Prerequisites

* A Neutron network the instances can attach to, with router
* Plenty of resource quota

## Software Components

[Kayobe](https://docs.openstack.org/kayobe/latest/) enables deployment of
containerised OpenStack to bare metal.

# Instructions for deployment

After cloning this repo, source the regular OpenStack rc file with necessary
vars for accessing the *A Universe From Nothing* lab project.

There are a various variables available for configuration. These can be seen
in `vars.tf`, and can be set in `terraform.tfvars` (see sample file
`terraform.tfvars.sample`).

Next up is the `terraform` bit assuming it is already installed:

    terraform init
    terraform plan
    terraform apply -auto-approve -parallelism=52

To reprovision a lab machine:

    terraform taint openstack_compute_instance_v2.#
    terraform apply -auto-approve

where `#` is the lab index which can be obtained from the web UI.

To destroy the cluster:

    terraform destroy

# Instructions for lab users

## Logging in

SSH in to your lab instance by running and entering the provided password:

    ssh lab@<lab-ip-address> -o PreferredAuthentications=password

The default password is the id of the lab instance. As such, it is recommeded
that you run `passwd` immediately to change the default password.

## Nested virtualisation

Make sure that nested virtualisation is enabled on the host:

    egrep --color 'vmx|svm' /proc/cpuinfo

Look for **vmx** or **svm** coloured red in the output.

## Initial seed deployment

Ensure that the initialsation steps are complete by looking at the log:

    tail -f a-seed-from-nothing.out

When complete, it should report an elapsed time as follows:

    [INFO] 22 minutes and 3 seconds elapsed.

## Inspect the bifrost container inside your seed VM:

    ssh stack@192.138.33.5
    docker ps
    exit

## Configuring bare metal cloud using Kayobe

Look at the steps involved in deploying Kayobe control plane:

    < a-universe-from-seed.sh

# Wrapping up

Join the discussion at `#openstack-kolla` channel on IRC.
