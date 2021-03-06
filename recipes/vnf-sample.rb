#
# Cookbook:: openstack-nfv-orchestration
# Recipe:: vnf-sample
#
# Copyright 2017, x-ion GmbH

require 'uri'

class ::Chef::Recipe
  include ::Openstack
end

#------------------------------------------------------------------------------
# Create vnf
#------------------------------------------------------------------------------

pyenv_dir = node['openstack-nfv-orchestration']['pyenv_dir']

vnfd_name = 'vnfd-sample'
vnf_name = 'vnf-sample'

# python-tackerclient (/usr/bin/tacker) is pulled in by python-mistral, but
# users may choose to install a different version in the virtual environment
tackerclient = if File.file?("#{pyenv_dir}/bin/tacker")
                 "#{pyenv_dir}/bin/tacker"
               else
                 '/usr/bin/tacker'
               end

demo_user = 'nfvdemo'
demo_project = 'service'
service_domain_name = node['openstack']['nfv-orchestration']['conf']['keystone_authtoken']['user_domain_name']
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check for port_security extension in ml2_conf.ini
execute 'check for port_security extension' do
  command 'grep "^extension_drivers.*port_security"' \
          ' /etc/neutron/plugins/ml2/ml2_conf.ini'
end

# Restart services in kitchen to avoid having to run the scripts twice
bash 'restart_services' do
  code <<-EOH
    systemctl restart nova-compute.service
    systemctl restart neutron-dhcp-agent.service
  EOH
  only_if { node.chef_environment == '_default' }
end

network_name = 'selfservice'
subnet_name = 'selfservice'

bash 'create private network' do
  code <<-EOH
    source /root/openrc
    if ! openstack network list -cName -fvalue | grep '^#{network_name}$'; then
      openstack network create "#{network_name}"
    fi
  EOH
end

ruby_block 'create private subnet' do
  block do
    env = openstack_command_env(demo_user, demo_project,
                                  service_domain_name, service_domain_name)
    openstack_command('openstack', ['subnet', 'create',
                                    '--network', network_name,
                                    '--subnet-range', '172.16.1.0/24',
                                    subnet_name], env)
  end
  not_if do
    # Check if subnet already exists (note: test wrong if more than
    # one subnet with the chosen name already exist)
    env = openstack_command_env(demo_user, demo_project,
                                service_domain_name, service_domain_name)
    begin
      openstack_command('openstack', ['subnet', 'show', subnet_name], env)
    rescue RuntimeError => e
      Chef::Log.info("Cannot show subnet #{subnet_name}. Message was #{e.message}")
      false
    end
  end
end
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ruby_block 'create vnf' do
  block do
    env = openstack_command_env(demo_user, demo_project,
                                 service_domain_name, service_domain_name)
    vnfd_id = openstack_command(tackerclient,
                               ['vnfd-show', vnfd_name,
                                '-cid', '-fvalue'],
                               env).chomp
    openstack_command(tackerclient, ['vnf-create', '--vnfd-id', vnfd_id,
                                     vnf_name], env)
  end
  not_if do
    # Check if subnet already exists (note: test wrong if more than
    # one subnet with the chosen name already exist)
    env = openstack_command_env(demo_user, demo_project,
                                service_domain_name, service_domain_name)
    begin
      openstack_command(tackerclient, ['vnf-show', vnf_name], env)
    rescue RuntimeError => e
      Chef::Log.info("vnf does not yet exist. Message was #{e.message}")
      false
    end
  end
end

ruby_block 'wait for vnf to become active' do
  block do
    loop do
      env = openstack_command_env(demo_user, demo_project,
                                service_domain_name, service_domain_name)
      begin
        break if openstack_command(tackerclient,
                                   ['vnf-show', 'vnf-sample', '-cstatus',
                                    '-fvalue'], env).chomp == 'ACTIVE'
      rescue RuntimeError => e
        Chef::Log.info("vnf still inactive. Message was #{e.message}")
      end
    end
  end
end
