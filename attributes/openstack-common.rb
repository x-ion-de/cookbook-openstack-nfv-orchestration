###################################################################
# Assign default mq attributes
# (copied from openstack-common attributes/messaging.rb to avoid having to add
# nfv-orchestration to that cookbook's services list)
###################################################################

rabbit_defaults = {
  rabbit_max_retries: 0,
  rabbit_retry_interval: 1,
  userid: node['openstack']['mq']['user'],
  vhost: node['openstack']['mq']['vhost'],
  port: node['openstack']['endpoints']['mq']['port'],
  host: node['openstack']['endpoints']['mq']['host'],
  ha: node['openstack']['mq']['rabbitmq']['ha'],
  heartbeat_timeout_threshold: node['openstack']['mq']['rabbitmq']['heartbeat_timeout_threshold'],
  heartbeat_rate: node['openstack']['mq']['rabbitmq']['heartbeat_rate'],
  use_ssl: node['openstack']['mq']['rabbitmq']['use_ssl'],
  kombu_ssl_version: node['openstack']['mq']['rabbitmq']['kombu_ssl_version'],
  kombu_ssl_keyfile: node['openstack']['mq']['rabbitmq']['kombu_ssl_keyfile'],
  kombu_ssl_certfile: node['openstack']['mq']['rabbitmq']['kombu_ssl_certfile'],
  kombu_ssl_ca_certs: node['openstack']['mq']['rabbitmq']['kombu_ssl_ca_certs'],
  kombu_reconnect_delay: node['openstack']['mq']['rabbitmq']['kombu_reconnect_delay'],
  kombu_reconnect_timeout: node['openstack']['mq']['rabbitmq']['kombu_reconnect_timeout'],
}

default['openstack']['mq']['nfv-orchestration']['service_type'] = node['openstack']['mq']['service_type']

default['openstack']['mq']['nfv-orchestration']['durable_queues'] =
  node['openstack']['mq']['durable_queues']
default['openstack']['mq']['nfv-orchestration']['auto_delete'] =
  node['openstack']['mq']['auto_delete']

rabbit_defaults.each do |key, val|
  default['openstack']['mq']['nfv-orchestration']['rabbit'][key.to_s] = val
end

###################################################################
# Database used by the OpenStack service
# (copied from openstack-common attributes/database.rb to avoid having to add
# nfv-orchestration to that cookbook (node['openstack']['common']['services']
# in attributes/default.rb)
###################################################################

service = 'nfv-orchestration'
project = 'tacker'

default['openstack']['db'][service]['service_type'] = node['openstack']['db']['service_type']
default['openstack']['db'][service]['host'] = node['openstack']['endpoints']['db']['host']
default['openstack']['db'][service]['port'] = node['openstack']['endpoints']['db']['port']
default['openstack']['db'][service]['db_name'] = project
default['openstack']['db'][service]['username'] = project
default['openstack']['db'][service]['options'] = node['openstack']['db']['options']

default['openstack']['db'][service]['slave_host'] = node['openstack']['endpoints']['db']['slave_host']
default['openstack']['db'][service]['slave_port'] = node['openstack']['endpoints']['db']['slave_port']

default['openstack']['db'][service]['socket'] = node['openstack']['db']['socket']
