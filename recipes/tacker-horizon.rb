#
# Cookbook:: openstack-nfv-orchestration
# Recipe:: tacker-horizon
#
# Copyright 2017, x-ion GmbH

#------------------------------------------------------------------------------
pyenv_dir = node['openstack-nfv-orchestration']['pyenv_dir']
#------------------------------------------------------------------------------
# Install tacker-horizon

python_virtualenv pyenv_dir

tacker_horizon_version = node['openstack-nfv-orchestration']['tacker_horizon_version']

python_package 'tacker-horizon' do
  version tacker_horizon_version
  notifies :run, 'execute[openstack-dashboard collectstatic]'
end

link '/usr/local/lib/python2.7/dist-packages/tacker_horizon' do
  to "#{pyenv_dir}/lib/python2.7/site-packages/tacker_horizon"
end

distinfo_dir = "tacker_horizon-#{tacker_horizon_version}.dist-info"

link "/usr/local/lib/python2.7/dist-packages/#{distinfo_dir}" do
  to "#{pyenv_dir}/lib/python2.7/site-packages/#{distinfo_dir}"
end

link '/usr/share/openstack-dashboard/openstack_dashboard/enabled/_80_nfv.py' do
  to "#{pyenv_dir}/lib/python2.7/site-packages/tacker_horizon/enabled/_80_nfv.py"
end

file '/usr/local/lib/python2.7/dist-packages/tacker_horizon/__init__.py' do
  owner 'root'
  group 'root'
  mode '0644'
  content ''
end
