maintainer "Zahary Karadjov"
name "developer-ca"
version "1.0.0"
license "MIT"

%w{
  amazon
  centos
  debian
  fedora
  freebsd
  mac_os_x
  mac_os_x_server
  opensuse
  opensuseleap
  oracle
  redhat
  scientific
  smartos
  solaris
  suse
  ubuntu
  windows
  zlinux
}.each do |os|
  supports os
end

depends "certbot"

