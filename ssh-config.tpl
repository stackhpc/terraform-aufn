Host ${bastion.name}
  HostName ${bastion.ip}
  User centos
  ForwardAgent yes

Host ${registry.name}
  HostName ${registry.ip}
  User centos
  ProxyJump ${bastion.name}

%{ for name, ip in zipmap(labs.names, labs.ips) ~}
Host ${name}
  HostName ${ip}
  User lab
  ProxyJump ${bastion.name}
%{ endfor ~}
