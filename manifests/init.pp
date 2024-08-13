#
# @summary install openbao
#
# @param user Customise the user openbao runs as, will also create the user unless `manage_user` is false.
#
# @param manage_user Whether or not the module should create the user.
#
# @param group Customise the group openbao runs as, will also create the user unless `manage_group` is false.
#
# @param manage_group Whether or not the module should create the group.
#
# @param bin_dir Directory the openbao executable will be installed in.
#
# @param config_dir Directory the openbao configuration will be kept in.
#
# @param config_mode Mode of the configuration file (config.json). Defaults to '0750'
#
# @param purge_config_dir Whether the `config_dir` should be purged before installing the generated config.
#
# @param download_url Manual URL to download the openbao zip distribution from.
#
# @param download_url_base base URL to download openbao zip distribution from.
#
# @param download_extension The extension of the openbao download
#
# @param service_name Customise the name of the system service
#
# @param service_provider Customise the name of the system service provider; this
#   also controls the init configuration files that are installed.
#
# @param service_options Extra argument to pass to `openbao server`, as per: `openbao server --help`
#
# @param manage_repo Configure the upstream repository. Only relevant when $nomad::install_method = 'repo'.
#
# @param manage_service Instruct puppet to manage service or not
#
# @param num_procs
#   Sets the GOMAXPROCS environment variable, to determine how many CPUs openbao
#   can use. The official openbao Terraform install.sh script sets this to the
#   output of ``nprocs``, with the comment, "Make sure to use all our CPUs,
#   because openbao can block a scheduler thread". Default: number of CPUs
#   on the system, retrieved from the ``processorcount`` Fact.
#
# @param api_addr
#   Specifies the address (full URL) to advertise to other openbao servers in the
#   cluster for client redirection. This value is also used for plugin backends.
#   This can also be provided via the environment variable openbao_API_ADDR. In
#   general this should be set as a full URL that points to the value of the
#   listener address
#
# @param version The version of openbao to install
#
# @param extra_config
# @param enable_ui
# @param arch
# @param os
# @param manage_download_dir
# @param download_dir
# @param package_ensure
# @param package_name
# @param install_method
# @param manage_file_capabilities
# @param disable_mlock
# @param max_lease_ttl
# @param default_lease_ttl
# @param telemetry
# @param disable_cache
# @param seal
# @param ha_storage
# @param listener
# @param manage_storage_dir
# @param storage
# @param manage_service_file
# @param service_ensure
# @param service_enable
# @param manage_config_file
# @param download_filename
# @param manage_config_dir enable/disable the directory management. not required for package based installations
class openbao (
  $user                                = 'openbao',
  $manage_user                         = true,
  $group                               = 'openbao',
  $manage_group                        = true,
  $bin_dir                             = $openbao::params::bin_dir,
  $manage_config_file                  = true,
  $config_mode                         = '0750',
  $purge_config_dir                    = true,
  $download_url                        = undef,
  $download_url_base                   = 'https://github.com/openbao/releases/download',
  $download_extension                  = 'zip',
  $service_name                        = 'openbao',
  $service_enable                      = true,
  $service_ensure                      = 'running',
  $service_provider                    = $facts['service_provider'],
  Boolean $manage_repo                 = $openbao::params::manage_repo,
  $manage_service                      = true,
  Optional[Boolean] $manage_service_file = $openbao::params::manage_service_file,
  Hash $storage                        = { 'file' => { 'path' => '/var/lib/openbao' } },
  $manage_storage_dir                  = false,
  Variant[Hash, Array[Hash]] $listener = { 'tcp' => { 'address' => '127.0.0.1:8200', 'tls_disable' => 1 }, },
  Optional[Hash] $ha_storage           = undef,
  Optional[Hash] $seal                 = undef,
  Optional[Boolean] $disable_cache     = undef,
  Optional[Hash] $telemetry            = undef,
  Optional[String] $default_lease_ttl  = undef,
  Optional[String] $max_lease_ttl      = undef,
  $disable_mlock                       = undef,
  $manage_file_capabilities            = undef,
  $service_options                     = '',
  $num_procs                           = $facts['processors']['count'],
  $install_method                      = $openbao::params::install_method,
  $config_dir                          = if $install_method == 'repo' and $manage_repo { '/etc/openbao.d' } else { '/etc/openbao' },
  $package_name                        = 'openbao',
  $package_ensure                      = 'installed',
  $download_dir                        = '/tmp',
  $manage_download_dir                 = false,
  $download_filename                   = 'openbao.zip',
  $version                             = '2.0.0',
  $os                                  = downcase($facts['kernel']),
  $arch                                = $openbao::params::arch,
  Optional[Boolean] $enable_ui         = undef,
  Optional[String] $api_addr           = undef,
  Hash $extra_config                   = {},
  Boolean $manage_config_dir           = $install_method == 'archive',
) inherits openbao::params {
  # lint:ignore:140chars
  $real_download_url = pick($download_url, "${download_url_base}${version}/${package_name}_${version}_${os}_${arch}.${download_extension}")
  # lint:endignore

  contain openbao::install
  contain openbao::config
  contain openbao::service

  Class['openbao::install'] -> Class['openbao::config']
  Class['openbao::config'] ~> Class['openbao::service']
}
