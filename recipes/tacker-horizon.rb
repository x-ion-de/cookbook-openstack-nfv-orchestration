#
# Cookbook:: openstack-nfv-orchestration
# Recipe:: tacker-horizon
#
# Copyright 2017, x-ion GmbH

#------------------------------------------------------------------------------

package 'python-pip'
#------------------------------------------------------------------------------
# Install tacker-horizon
tacker_horizon_version = node['openstack-nfv-orchestration']['tacker_horizon_version']

execute 'install_tacker_horizon' do
  command "pip install tacker-horizon==#{tacker_horizon_version}"
  creates '/usr/local/lib/python2.7/dist-packages/tacker_horizon'
end
#------------------------------------------------------------------------------
