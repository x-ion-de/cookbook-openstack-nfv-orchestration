#
# Cookbook:: openstack-nfv-orchestration
# Recipe:: vnfd-sample
#
# Copyright 2017, x-ion GmbH

require 'uri'

class ::Chef::Recipe
  include ::Openstack
end

#------------------------------------------------------------------------------
# Create vnfd
#------------------------------------------------------------------------------

pyenv_dir = node['openstack-nfv-orchestration']['pyenv_dir']

vnfd_name = 'vnfd-sample'

config_dir = '/etc/tacker/vnfd'

vnfd_conf_path = File.join(config_dir, 'vnfd-tosca.yaml')

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
directory config_dir do
  recursive true
  owner 'root'
  group 'root'
  mode 0700
end

template vnfd_conf_path do
  owner 'root'
  group 'root'
  mode 0644
  variables(
    version: run_context.cookbook_collection['openstack-nfv-orchestration'].metadata.version
  )
end
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ruby_block 'create vnfd' do
  block do
    env = openstack_command_env(demo_user, demo_project,
                                service_domain_name, service_domain_name)
    # We need user password for tacker user here
    # (openstack-chef-repo/data_bags/user_passwords/tacker.json)
    openstack_command(tackerclient, ['vnfd-create',
                                     '--vnfd-file', vnfd_conf_path, vnfd_name],
                      env)
  end
  not_if do
    # Check if a vnfd already exists
    env = openstack_command_env(demo_user, demo_project,
                                service_domain_name, service_domain_name)
    begin
      openstack_command(tackerclient, ['vnfd-show', vnfd_name], env)
    rescue RuntimeError => e
      Chef::Log.info("vnfd does not yet exist. Message was #{e.message}")
      false
    end
  end
end

ruby_block 'wait for vnfd onboarding' do
  block do
    env = openstack_command_env(demo_user, demo_project,
                              service_domain_name, service_domain_name)
    sleep 1 until openstack_command(tackerclient,
                                    ['vnfd-show', vnfd_name,
                                     '-ctemplate_source', '-fvalue'],
                                    env).chomp == 'onboarded'
  end
end
