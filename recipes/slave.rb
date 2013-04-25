if Chef::Config[:solo]
  Chef::Log.warn("This recipe uses search. Chef Solo does not support search.")
end

include_recipe "cxyz-dns"
directory "/etc/bind" do
        action :create
        owner "bind"
        group "bind"
        recursive true
        mode "0770"
        only_if { node['cxyz']['dns']['publish'] }

end

#directory "/etc/bind/forward" do
#        action :delete
#        owner "bind"
#        group "bind"
#        recursive true
#        mode "0770"
#	only_if { node['cxyz']['dns']['publish'] }
#end

directory "/etc/bind/reverse" do
        action :delete
        owner "bind"
        group "bind"
        recursive true
        mode "0770"
        only_if { node['cxyz']['dns']['publish'] }

end

directory "/etc/bind/forward" do 
	action :create
	owner "bind"
	group "bind"
	recursive true
	mode "0770"
        only_if { node['cxyz']['dns']['publish'] }

end

directory "/etc/bind/reverse" do
        action :create
        owner "bind"
        group "bind"
        recursive true
        mode "0770"
        only_if { node['cxyz']['dns']['publish'] }

end
begin
nodes = search(:node, "roles:Base")
rescue
nodes = []
end

begin
master_dns_servers = search(:node, "roles:DNS_Server").map {|n| n["network"]["interfaces"][node["network_interfaces"]["public"]]["addresses"].select { |address, data| data["family"] == "inet" }.keys}.flatten.compact
rescue
master_dns_servers = []
end

begin
slave_dns_servers = search(:node, "roles:DNSSlave_Server").map {|n|  n["network"]["interfaces"][node["network_interfaces"]["public"]]["addresses"].select { |address, data| data["family"] == "inet" }.keys}.flatten.compact
rescue
slave_dns_servers = []
end

begin
private_nodes = search(:node, "roles:Base").map {|n| n["network"]["interfaces"][node["network_interfaces"]["private"]]["addresses"].select { |address, data| data["family"] == "inet" }.keys}.flatten.compact
rescue
private_nodes = []
end

if master_dns_servers.empty?
	master_dns_servers.push(node['ipaddress'])
end
reverse_zones_priv = {} 
reverse_zones_pub = {}

nodes.each do |nodeling|
	begin
	addr = nodeling['network']['interfaces'][node["network_interfaces"]["private"]]['addresses'].select { |address, data| data["family"] == "inet"}.keys.first
	rescue
		next
	end
	addrToReverse = addr.split('.').reverse
	zone = addrToReverse[1] + "." + addrToReverse[2] + "." + addrToReverse[3] + ".in-addr.arpa"
	if reverse_zones_priv[zone] == nil 
		reverse_zones_priv[zone] = []
	end
	reverse_zones_priv[zone] = [reverse_zones_priv[zone], [{"name" => nodeling['fqdn'], "address" => addr}]]
end
reverse_zones_priv.each_pair do |k, v| 
	reverse_zones_priv[k] = v.flatten.compact
end

nodes.each do |nodeling|
	begin 
        addr = nodeling['network']['interfaces'][node["network_interfaces"]["public"]]['addresses'].select { |address, data| data["family"] == "inet"}.keys.first
	rescue
		next
	end
        addrToReverse = addr.split('.').reverse
        zone = addrToReverse[1] + "." + addrToReverse[2] + "." + addrToReverse[3] + ".in-addr.arpa"
        if reverse_zones_pub[zone] == nil
                reverse_zones_pub[zone] = []
        end
        reverse_zones_pub[zone] = [reverse_zones_pub[zone], [{"name" => nodeling['fqdn'], "address" => addr}]]
end

reverse_zones_pub.each_pair do |k, v|
        reverse_zones_pub[k] = v.flatten.compact
end

#main config file
template "/etc/bind/named.conf" do
   source "slave.bind.conf.erb"
   owner "bind"
   group "bind"
   mode "0770"
   action :create
   variables(
        :masters => master_dns_servers,
        :reverse_priv => reverse_zones_priv,
        :reverse_pub => reverse_zones_pub
   )
end

service "bind9" do
        action :restart
        only_if { File.exists? "/var/run/named/named.pid" }

end

