#
# Cookbook:: openstack-nfv-orchestration
# Recipe:: tacker_server
#
# Copyright 2017, x-ion GmbH

class ::Chef::Recipe
  include ::Openstack # address_for, get_password
end

pyenv_dir = node['openstack-nfv-orchestration']['pyenv_dir']

config_dir = File.join(pyenv_dir, 'etc/tacker')

tacker_conf_path = File.join(config_dir, 'tacker.conf')

db_user = node['openstack']['db']['nfv-orchestration']['username']
db_pass = get_password('db', 'tacker')

#------------------------------------------------------------------------------
tacker_user = 'tacker'
tacker_group = 'tacker'

group tacker_group

user tacker_user do
  shell '/usr/sbin/nologin'
  gid tacker_group
  comment 'OpenStack tacker'
  system true
  manage_home false
end

directory '/var/log/tacker' do
  owner tacker_user
  group tacker_group
  mode 0750
end

# State directory for vim/fernet_keys
directory '/etc/tacker' do
  owner tacker_user
  group tacker_group
  mode 0750
end

#------------------------------------------------------------------------------
apt_update ''
package 'python-pip'
package 'virtualenv'
package 'python-dev'
package 'libmysqlclient-dev'
package 'libffi-dev'
package 'libssl-dev'
#------------------------------------------------------------------------------
node.default['openstack']['nfv-orchestration']['conf_secrets']
.[]('database')['connection'] =
  db_uri('nfv-orchestration', db_user, db_pass)

if node['openstack']['mq']['service_type'] == 'rabbit'
  node.default['openstack']['nfv-orchestration']['conf_secrets']['DEFAULT']['transport_url'] = rabbit_transport_url 'nfv-orchestration'
end

node.default['openstack']['nfv-orchestration']['conf_secrets']
.[]('keystone_authtoken')['password'] =
  get_password 'service', 'openstack-nfv-orchestration'

identity_endpoint = public_endpoint 'identity'

auth_url = auth_uri_transform identity_endpoint.to_s, node['openstack']['api']['auth']['version']

node.default['openstack']['nfv-orchestration']['conf'].tap do |conf|
  conf['keystone_authtoken']['auth_url'] = auth_url
end

#------------------------------------------------------------------------------
# Config file

tacker_conf = merge_config_options 'nfv-orchestration'

directory config_dir do
  recursive true
  owner tacker_user
  group tacker_group
  mode 0700
end

template tacker_conf_path do
  source 'openstack-service.conf.erb'
  cookbook 'openstack-common'
  owner 'root'
  group 'root'
  mode 0644
  variables(
    service_config: tacker_conf
  )
  notifies :restart, 'service[tacker-server]'
  notifies :restart, 'service[tacker-conductor]'
end

#------------------------------------------------------------------------------

directory pyenv_dir do
  recursive true
  owner 'root'
  group 'root'
  mode 0755
end

execute 'install_tacker' do
  cwd pyenv_dir
  command "virtualenv #{pyenv_dir} --system-site-packages && . #{pyenv_dir}/bin/activate && pip install tacker==0.8.0 && pip install heat-translator && tacker-db-manage --config-file /usr/local/pyenv/tacker/etc/tacker/tacker.conf upgrade head"
  # Add tacker.vim_ping_action to mistral
  notifies :run, 'execute[mistral-db-manage_populate]', :immediate
  notifies :restart, 'service[mistral-api]', :immediate
  notifies :restart, 'service[mistral-engine]', :immediate
  notifies :restart, 'service[mistral-executor]', :immediate
end
#------------------------------------------------------------------------------
# Install systemd service file and start service
execute 'daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

execute 'Allow users in non-admin projects with admin roles to create flavors.' do
  command 'sudo sed -i.bak \'s/"resource_types:OS::Nova::Flavor.*/"resource_types:OS::Nova::Flavor": "role:admin",/\' /etc/heat/policy.json'
  action :nothing
end

template '/etc/systemd/system/tacker-server.service' do
  source 'systemd-tacker.service.erb'
  owner 'root'
  group 'root'
  mode 0644
  variables(
    name: 'tacker-server',
    tacker_user: tacker_user,
    tacker_group: tacker_group,
    tacker_conf_file: '/usr/local/pyenv/tacker/etc/tacker/tacker.conf',

    executable: File.join(pyenv_dir, '/bin/python2.7') + ' /usr/local/pyenv/tacker/bin/tacker-server'
  )
  notifies :run, 'execute[daemon-reload]', :immediately
  notifies :restart, 'service[tacker-server]', :delayed
end

template '/etc/systemd/system/tacker-conductor.service' do
  source 'systemd-tacker.service.erb'
  owner 'root'
  group 'root'
  mode 0644
  variables(
    name: 'tacker-conductor',
    tacker_user: tacker_user,
    tacker_group: tacker_group,
    tacker_conf_file: '/usr/local/pyenv/tacker/etc/tacker/tacker.conf',

    executable: File.join(pyenv_dir, '/bin/python2.7') + ' /usr/local/pyenv/tacker/bin/tacker-conductor'
  )
  notifies :run, 'execute[daemon-reload]', :immediately
  notifies :restart, 'service[tacker-conductor]', :delayed
end

service 'tacker-server' do
  action [:enable, :start]
end

service 'tacker-conductor' do
  action [:enable, :start]
end
