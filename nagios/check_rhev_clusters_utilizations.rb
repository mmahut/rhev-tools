# TODO: Create a nagios plugin from this
require 'rubygems'
require 'restclient'
require 'nokogiri'

RHEVM_API = 'https://localhost:8443/api'

client = RestClient::Resource.new(RHEVM_API)

def auth_header
  encoded_credentials = ["rhevadmin@win.example.com:password"].pack("m0").gsub(/\n/,'')
  { :authorization => "Basic " + encoded_credentials }
end

clusters = Nokogiri::XML(client['/clusters'].get(auth_header))
clusters.xpath('/clusters/cluster/name').text.each do |clustername|

  hosts = Nokogiri::XML(client["/hosts?search=cluster%3D#{clustername}"].get(auth_header))
  cores = hosts.xpath('/hosts/host/cpu/topology/@cores').inject(0) { |sum, x| sum += x.text.to_s.to_i;sum }
  summem = 0
  hosts.xpath('/hosts/host/@id').each do |hostid|
    memory = Nokogiri::XML(client["/hosts/#{hostid}/statistics"].get(auth_header))
    summem += memory.xpath('//statistic/name[text()="memory.total"]/../values/value/datum/text()').text.to_s.to_i
  end
  sumemmb = summem / 8388608
  puts "Cluster #{clustername} provides #{cores} of CPU cores and #{sumemmb} MB of memory."

  vms = Nokogiri::XML(client["/vms?search=cluster%3D#{clustername}"].get(auth_header))
  vmsmem = vms.xpath('/vms/vm/memory').inject(0) { |sum, x| sum += x.text.to_s.to_i;sum }
  sumvmsmb = vmsmem / 8388608
  sumcpu = 0
  vms.xpath('/vms/vm/name').each do |name|
    vmscores = vms.xpath("/vms/vm/name[text()='#{name.text}']/../cpu/topology/@cores").text.to_s.to_i
    vmssockets = vms.xpath("/vms/vm/name[text()='#{name.text}']/../cpu/topology/@sockets").text.to_s.to_i
    sumcpu += vmssockets * vmscores
  end
  puts "Virtual guests occupies #{sumcpu} of CPU cores and #{sumvmsmb} MB of memory."

  percentcpu = (sumcpu.to_f / cores.to_f * 100.0).ceil
  percentmem = (sumvmsmb.to_f / sumemmb.to_f * 100.0).ceil
  puts "Overall CPU utilization is at #{percentcpu}% and memory is at #{percentmem}%."
end
