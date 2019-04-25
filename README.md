# Kayobe on Packet

This Terraform deployment reproduces the environment for [a universe from
seed](https://github.com/stackhpc/a-universe-from-nothing) workshop on Packet.

## Software Components

[Kayobe](https://kayobe.readthedocs.io/) enables deployment of containerised
OpenStack to bare metal.

# Instructions for deployment

After cloning this repo,

    cd kata-on-packet    
    
    echo terraform_username=\"$LOGNAME\" >> terraform.tfvars
    echo packet_auth_token=\"ABCDEFGHIJKLMNOPQRSTUVWXYZ123456\" >> terraform.tfvars
    echo packet_project_id=\"12345678-90AB-CDEF-GHIJ-KLMNOPQR\" >> terraform.tfvars
    echo deploy_prefix=kayobe >> terraform.tfvars
    echo packet_facility=\"ewr1\" >> terraform.tfvars
    echo lab_count=25 >> terraform.tfvars
    echo packet_facility_alt=\"nrt1\" >> terraform.tfvars
    echo lab_count_alt=25 >> terraform.tfvars

Note that the `packet_auth_token` needs to be the user auth token, not the
project auth token, otherwise you will hit strange errors. This can be
obtained by clicking the user icon on the top right hand corner on
https://app.packet.net and choose API Keys in the menu.

Next up is the `terraform` bit assuming it is already installed:

    terraform init
    terraform plan
    terraform apply -auto-approve

To reprovision a lab machine:

    terraform taint packet_device.lab.#
    terraform apply

where `#` is the lab index which can be obtained from the web UI.

# Instructions for lab users

## Logging in

SSH in to your lab instance by running and entering the provided password:

    ssh lab@<lab-ip-address> -o PreferredAuthentications=password

It is recommeded that you run `passwd` immediately to change the default password.

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

Join the discussion at `#openstack-kayobe` channel on IRC.
