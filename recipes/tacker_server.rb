#
# Cookbook:: openstack-nfv-orchestration
# Recipe:: tacker_server
#
# Copyright 2017, x-ion GmbH

class ::Chef::Recipe
  include ::Openstack # address_for, get_password
end

#------------------------------------------------------------------------------
# Install tacker server
#------------------------------------------------------------------------------

pyenv_dir = node['openstack-nfv-orchestration']['pyenv_dir']

config_dir = File.join(pyenv_dir, 'etc/tacker')

tacker_conf_path = File.join(config_dir, 'tacker.conf')

db_user = node['openstack']['db']['nfv-orchestration']['username']
db_pass = get_password('db', 'tacker')

tacker_system_user = 'tacker'
tacker_system_group = 'tacker'
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
group tacker_system_group

user tacker_system_user do
  shell '/usr/sbin/nologin'
  gid tacker_system_group
  comment 'OpenStack tacker'
  system true
  manage_home false
end

directory '/var/log/tacker' do
  owner tacker_system_user
  group tacker_system_group
  mode 0750
end

# State directory for vim/fernet_keys
directory '/etc/tacker' do
  owner tacker_system_user
  group tacker_system_group
  mode 0750
end
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
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

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Config file

tacker_conf = merge_config_options 'nfv-orchestration'

directory config_dir do
  recursive true
  owner tacker_system_user
  group tacker_system_group
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

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
tacker_server_version = node['openstack-nfv-orchestration']['tacker_server_version']

python_runtime '2'

python_virtualenv pyenv_dir

apt_update ''
%w(
  python-dev
  libmysqlclient-dev
  libffi-dev
  libssl-dev
).each do |pkg|
  package pkg
end

# Dependencies for tacker, tacker-db-manage
%w(
  heat-translator
  mysql-python
  pymysql
  python-memcached
).each do |pkg|
  python_package pkg
end

# Use links to make files in tacker virtual environment available to mistral
distinfo = "tacker-#{tacker_server_version}.dist-info"
link 'distinfo_dir' do
  target_file "/usr/local/lib/python2.7/dist-packages/#{distinfo}"
  to "#{pyenv_dir}/lib/python2.7/site-packages/#{distinfo}"
end

link 'tacker_dir' do
  target_file '/usr/local/lib/python2.7/dist-packages/tacker'
  to "#{pyenv_dir}/lib/python2.7/site-packages/tacker"
end

python_package 'tacker' do
  version tacker_server_version
  notifies :run, 'execute[tacker-db-manage upgrade head]', :immediately
  notifies :create, 'link[distinfo_dir]', :immediately
  notifies :create, 'link[tacker_dir]', :immediately
  # Add tacker.vim_ping_action to mistral
  notifies :run, 'execute[mistral-db-manage_populate]', :immediately
  notifies :restart, 'service[mistral-api]', :immediately
  notifies :restart, 'service[mistral-engine]', :immediately
  notifies :restart, 'service[mistral-executor]', :immediately
  notifies :run, 'execute[openstack-dashboard collectstatic]'
end

tdm_cmd = File.join(pyenv_dir, 'bin/tacker-db-manage')
execute 'tacker-db-manage upgrade head' do
  command "#{tdm_cmd} --config-file #{tacker_conf_path} upgrade head"
  action :nothing
end
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# TODO: replace policy file edits via sed with something better
flavor_key = 'resource_types:OS::Nova::Flavor'
execute 'Allow users in non-admin projects with admin roles to create flavors.' do
  command "sudo sed -i.bak 's|\"#{flavor_key}.*|\"#{flavor_key}\": \"role:admin\",|' /etc/heat/policy.json"
  not_if "grep '#{flavor_key}.*role:admin' " '/etc/heat/policy.json'
end
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Install systemd service file and start service
%w(server conductor).each do |unit|
  template "/etc/systemd/system/tacker-#{unit}.service" do
    source 'systemd-tacker.service.erb'
    owner 'root'
    group 'root'
    mode 0644
    variables(
      name: "tacker-#{unit}",
      tacker_user: tacker_system_user,
      tacker_group: tacker_system_group,
      tacker_conf_file: "#{pyenv_dir}/etc/tacker/tacker.conf",

      executable: File.join(pyenv_dir, '/bin/python2.7') +
                  " #{pyenv_dir}/bin/tacker-#{unit}"
    )
    notifies :run, 'execute[daemon-reload]', :immediately
    notifies :restart, "service[tacker-#{unit}]", :delayed
  end
end

execute 'daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

service 'tacker-server' do
  action [:enable, :start]
end

service 'tacker-conductor' do
  action [:enable, :start]
end
