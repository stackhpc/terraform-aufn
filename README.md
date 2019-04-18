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
    echo lab_count=50 >> terraform.tfvars

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

## SSH config

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

Make sure that nested virtualisation is enabled on the host:

    egrep --color 'vmx|svm' /proc/cpuinfo

Look for **vmx** or **svm** coloured red in the output.

## Initial seed deployment

Ensure that the initialsation steps are complete by looking at the log:

    tail -f screenlog.0

When complete, it should report an elapsed time as follows:

    22 minutes and 3 seconds elapsed.

## Inspect the docker container and images inside your seed VM:

    ssh stack@192.138.33.5

## Configuring bare metal cloud using Kayobe

Look at the steps involved in deploying Kayobe inside `configure-kayobe.sh`. To
run the script:

    bash configure-kayobe.sh

# Wrapping up

Join the discussion at `#openstack-kayobe` channel on IRC.
