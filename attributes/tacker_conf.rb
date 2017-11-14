default['openstack']['nfv-orchestration']['conf'].tap do |conf|
  # [DEFAULT] section
  if node['openstack']['nfv-orchestration']['syslog']['use']
    conf['DEFAULT']['log_config'] = '/etc/openstack/logging.conf'
  else
    conf['DEFAULT']['log_file'] = '/var/log/tacker/tacker.log'
  end

  # [paste_deploy] section
  conf['paste_deploy']['flavor'] = 'keystone'

  #  [keystone_authtoken] section
  conf['keystone_authtoken']['auth_type'] = 'v3password'
  conf['keystone_authtoken']['region_name'] = node['openstack']['region']
  conf['keystone_authtoken']['username'] = 'tacker'
  conf['keystone_authtoken']['project_name'] = 'service'
  conf['keystone_authtoken']['user_domain_name'] = 'Default'
  conf['keystone_authtoken']['project_domain_name'] = 'Default'

  # [oslo_policy] section
  conf['oslo_policy']['policy_file'] = File.join(
    node['openstack-nfv-orchestration']['pyenv_dir'], 'etc/tacker/policy.json'
  )
end
