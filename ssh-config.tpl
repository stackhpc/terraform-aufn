Host ${bastion.name}
  HostName ${bastion.ip}
  User cloud-user
  ForwardAgent yes

Host ${registry.name}
  HostName ${registry.ip}
  User cloud-user
  ProxyJump ${bastion.name}

%{ for name, ip in zipmap(labs.names, labs.ips) ~}
Host ${name}
  HostName ${ip}
  User lab
  ProxyJump ${bastion.name}
%{ endfor ~}
