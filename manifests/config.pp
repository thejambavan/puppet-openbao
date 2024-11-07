#
# @summary This class is called from openbao for service config
#
# @api private
#
class openbao::config {
  assert_private()
  if $openbao::manage_config_dir {
    file { $openbao::config_dir:
      ensure  => directory,
      purge   => $openbao::purge_config_dir,
      recurse => $openbao::purge_config_dir,
      owner   => $openbao::user,
      group   => $openbao::group,
    }
  }

  if $openbao::manage_config_file {
    $_config_hash = delete_undef_values({
        'listener'          => $openbao::listener,
        'storage'           => $openbao::storage,
        'ha_storage'        => $openbao::ha_storage,
        'seal'              => $openbao::seal,
        'telemetry'         => $openbao::telemetry,
        'disable_cache'     => $openbao::disable_cache,
        'default_lease_ttl' => $openbao::default_lease_ttl,
        'max_lease_ttl'     => $openbao::max_lease_ttl,
        'disable_mlock'     => $openbao::disable_mlock,
        'ui'                => $openbao::enable_ui,
        'api_addr'          => $openbao::api_addr,
    })

    $config_hash = stdlib::merge($_config_hash, $openbao::extra_config)

    file { "${openbao::config_dir}/config.json":
      content => stdlib::to_json_pretty($config_hash),
      owner   => $openbao::user,
      group   => $openbao::group,
      mode    => $openbao::config_mode,
    }

    # If manage_storage_dir is true and a file or raft storage backend is
    # configured, we create the directory configured in that backend.
    #
    if $openbao::manage_storage_dir {
      if $openbao::storage['file'] {
        $_storage_backend = 'file'
      } elsif $openbao::storage['raft'] {
        $_storage_backend = 'raft'
      } else {
        fail('Must provide a valid storage backend: file or raft')
      }

      if $openbao::storage[$_storage_backend]['path'] {
        file { $openbao::storage[$_storage_backend]['path']:
          ensure => directory,
          owner  => $openbao::user,
          group  => $openbao::group,
        }
      } else {
        fail("Must provide a path attribute to storage ${_storage_backend}")
      }
    }
  }

  # If nothing is specified for manage_service_file, defaults will be used
  # depending on the install_method.
  # If a value is passed, it will be interpretted as a boolean.
  if $openbao::manage_service_file == undef {
    case $openbao::install_method {
      'archive': { $real_manage_service_file = true }
      'repo':    { $real_manage_service_file = false }
      default:   { $real_manage_service_file = false }
    }
  } else {
    assert_type(Boolean,$openbao::manage_service_file)
    $real_manage_service_file = $openbao::manage_service_file
  }

  if $real_manage_service_file {
    case $openbao::service_provider {
      'systemd': {
        systemd::unit_file { 'openbao.service':
          content => template('openbao/openbao.systemd.erb'),
        }
      }
      default: {
        fail("openbao::service_provider '${openbao::service_provider}' is not valid")
      }
    }
  }
}
