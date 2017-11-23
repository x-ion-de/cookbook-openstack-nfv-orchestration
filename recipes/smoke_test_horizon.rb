#
# Cookbook:: openstack-nfv-orchestration
# Recipe:: smoke_test_horizon
#
# Copyright 2017, x-ion GmbH

#------------------------------------------------------------------------------
# Log into dashboard and verify that NFV Orchestration plugin is loaded
#------------------------------------------------------------------------------
# The openstack-dashboard cookbook has horizon bind to 0.0.0.0 by default;
# we test 127.0.0.1 in that case.
bind_ip = node['openstack']['bind_service']['dashboard_https']['host']
login_url = if bind_ip == '0.0.0.0'
              'https://127.0.0.1/auth/login/'
            else
              "https://#{bind_ip}/auth/login/"
            end
admin_user = node['openstack']['identity']['admin_user']
admin_pass = get_password 'user', admin_user

bash 'test tacker-horizon' do
  code <<-EOH
    curl -v -s -k -L -c cookies.txt -b cookies.txt #{login_url}
    cto=$(awk '/csrftoken/ { print $NF}' cookies.txt)
    curl -v -s -k -L -c cookies.txt -b cookies.txt --referer #{login_url} "-dcsrfmiddlewaretoken=$cto&username=#{admin_user}&password=#{admin_pass}" "#{login_url}" |grep "NFV Orchestration"
  EOH
end
#------------------------------------------------------------------------------
