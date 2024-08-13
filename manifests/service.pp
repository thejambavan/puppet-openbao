#
# @api private
#
class openbao::service {
  if $openbao::manage_service {
    service { $openbao::service_name:
      ensure   => $openbao::service_ensure,
      enable   => $openbao::service_enable,
      provider => $openbao::service_provider,
    }
  }
}
