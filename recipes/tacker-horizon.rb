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
#------------------------------------------------------------------------------
