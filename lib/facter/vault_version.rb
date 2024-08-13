# frozen_string_literal: true

# Fact: openbao_version
#
# Purpose: Retrieve openbao version if installed
#
Facter.add(:openbao_version) do
  confine { Facter::Util::Resolution.which('openbao') }
  setcode do
    openbao_server_version_output = Facter::Util::Resolution.exec('bao version')
    match = openbao_server_version_output.match(%r{openbao v(\d+\.\d+\.\d+)})
    match&.captures&.first
  end
end
