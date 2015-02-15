#
class apt(
  $always_apt_update    = false,
  $apt_update_frequency = 'reluctantly',
  $purge_sources_list   = false,
  $purge_sources_list_d = false,
  $purge_preferences    = false,
  $purge_preferences_d  = false,
  $update_timeout       = undef,
  $update_tries         = undef,
  $sources              = undef,
) inherits ::apt::params {

  if $::osfamily != 'Debian' {
    fail('This module only works on Debian or derivatives like Ubuntu')
  }

  include apt::update

  $frequency_options = ['always','daily','weekly','reluctantly']
  validate_re($apt_update_frequency, $frequency_options)

  validate_bool($purge_sources_list, $purge_sources_list_d,
                $purge_preferences, $purge_preferences_d)

  $sources_list_content = $purge_sources_list ? {
    false => undef,
    true  => "# Repos managed by puppet.\n",
  }

  if $always_apt_update == true {
    Exec <| title=='apt_update' |> {
      refreshonly => false,
    }
  }

  file { '/etc/apt/apt.conf.d/15update-stamp':
    ensure  => 'file',
    content => template('apt/_header.erb', 'apt/15update-stamp.erb'),
    group   => 'root',
    mode    => '0644',
    owner   => 'root',
  }

  $root           = $apt::params::root
  $apt_conf_d     = $apt::params::apt_conf_d
  $sources_list_d = $apt::params::sources_list_d
  $preferences_d  = $apt::params::preferences_d
  $provider       = $apt::params::provider

  file { 'sources.list':
    ensure  => present,
    path    => "${root}/sources.list",
    owner   => root,
    group   => root,
    mode    => '0644',
    content => $sources_list_content,
    notify  => Exec['apt_update'],
  }

  file { 'sources.list.d':
    ensure  => directory,
    path    => $sources_list_d,
    owner   => root,
    group   => root,
    purge   => $purge_sources_list_d,
    recurse => $purge_sources_list_d,
    notify  => Exec['apt_update'],
  }

  if $purge_preferences {
    file { 'apt-preferences':
      ensure => absent,
      path   => "${root}/preferences",
    }
  }

  file { 'preferences.d':
    ensure  => directory,
    path    => $preferences_d,
    owner   => root,
    group   => root,
    purge   => $purge_preferences_d,
    recurse => $purge_preferences_d,
  }

  # Need anchor to provide containment for dependencies.
  anchor { 'apt::update':
    require => Class['apt::update'],
  }

  # manage sources if present
  if $sources != undef {
    validate_hash($sources)
    create_resources('apt::source', $sources)
  }
}
