# Needed by openstack-ops-database for automatic DB creation
default['openstack']['common']['services']['nfv-orchestration'] = 'tacker'

default['openstack']['nfv-orchestration']['syslog']['use'] = false

# Versions for OpenStack release: Pike
# https://releases.openstack.org/teams/tacker.html
default['openstack-nfv-orchestration']['tacker_server_version'] = '0.8.0'
default['openstack-nfv-orchestration']['tacker_client_version'] = '0.10.0'
default['openstack-nfv-orchestration']['tacker_horizon_version'] = '0.10.0'

# Needs admin for heat policy element OS::Nova::Flavor
default['openstack']['nfv-orchestration']['service_role'] = 'admin'

# ************** OpenStack NFV Orchestration Endpoints ************************

# The OpenStack NFV Orchestration (Tacker) endpoints
%w(public internal admin).each do |ep_type|
  default['openstack']['endpoints'][ep_type]['nfv-orchestration']['scheme'] = 'http'
  default['openstack']['endpoints'][ep_type]['nfv-orchestration']['host'] = '127.0.0.1'
  default['openstack']['endpoints'][ep_type]['nfv-orchestration']['path'] = ''
  default['openstack']['endpoints'][ep_type]['nfv-orchestration']['port'] = 9890
end
