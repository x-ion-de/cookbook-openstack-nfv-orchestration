#
# Cookbook:: openstack-nfv-orchestration
# Recipe:: sample-user
#
# Copyright 2017, x-ion GmbH

require 'uri'

class ::Chef::Recipe
  include ::Openstack
end

#------------------------------------------------------------------------------
# Create sample nfv-orchestration user
#------------------------------------------------------------------------------

identity_admin_endpoint = admin_endpoint 'identity'
auth_url = ::URI.decode identity_admin_endpoint.to_s
tacker_demo_user = 'nfvdemo'
tacker_demo_pass = get_password 'user', 'nfvdemo'

# admin role needed to use OS::Nova::Flavor when creating vnf
tacker_demo_role = 'admin'

# Should be demo-project, but we cannot rely on one being there
tacker_demo_project = 'service'

admin_user = node['openstack']['identity']['admin_user']
admin_pass = get_password 'user', admin_user
admin_project = node['openstack']['identity']['admin_project']
admin_domain = node['openstack']['identity']['admin_domain_name']

connection_params = {
  openstack_auth_url:     "#{auth_url}/auth/tokens",
  openstack_username:     admin_user,
  openstack_api_key:      admin_pass,
  openstack_project_name: admin_project,
  openstack_domain_name:  admin_domain,
}

# Register tacker demo user
openstack_user tacker_demo_user do
  project_name tacker_demo_project
  password tacker_demo_pass
  connection_params connection_params
end

# Grant role in project to tacker demo user
openstack_user tacker_demo_user do
  role_name tacker_demo_role
  project_name tacker_demo_project
  connection_params connection_params
  action :grant_role
end

# Do we need advanced service role for tacker_demo_user?
advanced_services_role = 'advsvc'

# Grant additional role in project
openstack_user tacker_demo_user do
  role_name advanced_services_role
  project_name tacker_demo_project
  connection_params connection_params
  action :grant_role
end
