#
# Cookbook:: openstack-nfv-orchestration
# Recipe:: vim
#
# Copyright 2017, x-ion GmbH

require 'uri'

class ::Chef::Recipe
  include ::Openstack
end

#------------------------------------------------------------------------------
# Create vim
#------------------------------------------------------------------------------

pyenv_dir = node['openstack-nfv-orchestration']['pyenv_dir']

vim_name = 'controller'

config_dir = '/usr/local/tacker/etc'

vim_conf_path = File.join(config_dir, 'vim-config.yaml')

# python-tackerclient (/usr/bin/tacker) is pulled in by python-mistral, but
# users may choose to install a different version in the virtual environment
tackerclient = if File.file?("#{pyenv_dir}/bin/tacker")
                 "#{pyenv_dir}/bin/tacker"
               else
                 '/usr/bin/tacker'
               end

identity_public_endpoint = public_endpoint 'identity'
public_auth_url = ::URI.decode identity_public_endpoint.to_s

demo_pass = get_password 'user', 'nfvdemo'
demo_user = 'nfvdemo'
service_project_name = node['openstack']['nfv-orchestration']['conf']['keystone_authtoken']['project_name']
service_domain_name = node['openstack']['nfv-orchestration']['conf']['keystone_authtoken']['user_domain_name']
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
directory config_dir do
  recursive true
  owner 'root'
  group 'root'
  mode 0755
end

template vim_conf_path do
  owner 'root'
  group 'root'
  mode 0600
  variables(
    tacker_admin_user: demo_user,
    tacker_admin_pass: demo_pass,
    tacker_auth_url: public_auth_url,
    version: run_context.cookbook_collection['openstack-nfv-orchestration'].metadata.version
  )
end
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
ruby_block 'wait for tacker service' do
  block do
    begin
      env = openstack_command_env(demo_user, service_project_name,
                                  service_domain_name, service_domain_name)
      sleep 1 until openstack_command(tackerclient, 'vim-list', env)
      # We need user password for tacker user here
      # (openstack-chef-repo/data_bags/user_passwords/tacker.json)
    end
  end
end

ruby_block 'create vim' do
  block do
    env = openstack_command_env(demo_user, service_project_name,
                                service_domain_name, service_domain_name)
    # We need user password for tacker user here
    # (openstack-chef-repo/data_bags/user_passwords/tacker.json)
    openstack_command(tackerclient,
                      ['vim-register', '--is-default',
                       '--config-file', vim_conf_path,
                       '--description', 'Controller node is VIM',
                       vim_name], env)
  end
  not_if do
    # Check if a default vim already exists
    env = openstack_command_env(demo_user, service_project_name,
                                service_domain_name, service_domain_name)
    openstack_command(tackerclient, ['vim-list', '-cis_default', '-fvalue'], env).chomp == 'True'
  end
end

ruby_block 'wait for vim' do
  block do
    begin
      env = openstack_command_env(demo_user, service_project_name,
                                  service_domain_name, service_domain_name)
      until openstack_command(tackerclient,
                              ['vim-show', vim_name, '-cstatus', '-fvalue'],
                              env).chomp == 'REACHABLE'
        sleep 1
      end
    end
  end
end
