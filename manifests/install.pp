#
# @api private
#
class openbao::install {
  assert_private()
  $openbao_bin = "${openbao::bin_dir}/bao"

  case $openbao::install_method {
    'archive': {
      if $openbao::manage_download_dir {
        file { $openbao::download_dir:
          ensure => directory,
        }
      }

      archive { "${openbao::download_dir}/${openbao::download_filename}":
        ensure       => present,
        extract      => true,
        extract_path => $openbao::bin_dir,
        source       => $openbao::real_download_url,
        cleanup      => true,
        creates      => $facts['openbao_version'] ? { # lint:ignore:selector_inside_resource
          undef   => $openbao_bin,
          default => versioncmp($openbao::version, $facts['openbao_version']) > 0 ? {
            true    => undef,
            default => $openbao_bin
          }
        },
        before       => File['openbao_binary'],
      }

      $_manage_file_capabilities = true
    }

    default: {
      fail("Installation method ${openbao::install_method} not supported")
    }
  }

  file { 'openbao_binary':
    path  => $openbao_bin,
    owner => 'root',
    group => 'root',
    mode  => '0755',
  }

  if !$openbao::disable_mlock and pick($openbao::manage_file_capabilities, $_manage_file_capabilities) {
    file_capability { 'openbao_binary_capability':
      ensure     => present,
      file       => $openbao_bin,
      capability => 'cap_ipc_lock=ep',
      subscribe  => File['openbao_binary'],
    }

    if $openbao::install_method == 'repo' {
      Package[$openbao::package_name] ~> File_capability['openbao_binary_capability']
    }
  }

  if $openbao::manage_user {
    user { $openbao::user:
      ensure => present,
    }
    if $openbao::manage_group {
      Group[$openbao::group] -> User[$openbao::user]
    }
  }
  if $openbao::manage_group {
    group { $openbao::group:
      ensure => present,
    }
  }
}
