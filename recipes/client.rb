begin
  require 'resolv'
  dnsserver = false
  node.roles.each do |role|
    if role == 'DNS_Server' || role == 'DNSSlave_Server'
      dnsserver = true
    end
  end

  if Chef::Config[:solo]
    Chef::Log.warn("This recipe uses search. Chef Solo does not support search.")
  else
    if dnsserver == false
      master_dns_servers = search(:node, "roles:DNS_Server").map {|n| n["network"]["interfaces"][node["network_interfaces"]["private"]]["addresses"].select { |address, data| data["family"] == "inet" }.keys}.flatten.compact
      slave_dns_servers = search(:node, "roles:DNSSlave_Server").map {|n|  n["network"]["interfaces"][node["network_interfaces"]["private"]]["addresses"].select { |address, data| data["family"] == "inet" }.keys}.flatten.compact
      hosts = [master_dns_servers, slave_dns_servers].flatten.compact
    else
      hosts = ['127.0.0.1']
    end
  end

  Resolv::DNS.new(:nameserver => hosts).getaddress("google.com")
  template "/etc/resolv.conf" do
    source "resolv.conf.erb"
    owner "root"
    group "root"
    mode "0644"
    action :create
    variables( :hosts => hosts )
  end
rescue
  log "can't find or connect to DNS server, using fool proof resolv.conf" do
    level :debug
  end

  template "/etc/resolv.conf" do
    source "resolv.conf.erb"
    owner "root"
    group "root"
    mode "0644"
    action :create
    variables( :hosts => ["4.2.2.1", "4.2.2.3", "4.2.2.4", "8.8.8.8", "8.8.4.4"])
  end
end
