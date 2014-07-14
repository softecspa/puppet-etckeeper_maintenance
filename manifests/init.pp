# == Class: etckeeper_maintenance
#
# This class enhance etckeeper module feature. It add management of /etc/.git directory.
# You can specify a maximum dimension for this directory, once this dimension is exceeded the module make a git bundle,
# move it to a cluod storage and reinit /etc directory versioning.
#
# It require etckeeper module
#
# NB: actually, only s3 cloud storage is available
#
# === Parameters
#
# [*max_dimension*]
#   Maximum dimension (in MB) of /etc/.git directory before to be bundled. It must be an integer value
#   default: 300
#
# [*bundle_local_path*]
#   Local path where bundle file is archived before transfer in cluod. Once bundle is transfereed in the cluod, local copy will be deleted.
#   If directory don't exists it will be created
#   default: /var/local/git-bundle/
#
# [*bucket_type*]
#   Type of cloud storage used to backup bunble.
#   Accepted value: s3 (for Amazon s3).
#   default: s3
#
#   NB: if s3 is selected, module s3cmd is required and s3_bucket_name variable become mandatory. Otherwise s3_bucket_name variable will be ignored
#
# [*s3_bucket_name*]
#   If s3 is selected as bucket_type, this parameter set the s3 bucket name where to store backup.
#   By default this parameter take its value from $s3_etckeeper_bucket global variable.
#
#
# === Examples
#
# Example #1: all parameters has default value. /etc.git directory is bundled when it exceed dimension of 300MB. Bundle is temporary created on /var/local/git-bundle
# and moved to an s3 bucket. s3 bucket name is the value of $s3_etckeeper_bucket global variable.
#
# include etckeeper_maintenance
#
# Example #2: customized parameter
#
#  class {"etckeeper_maintenance":
#    max_dimension     => "500",
#    bucket_type       => 's3',
#    s3_bucket_name    => 'git-bundle',
#    bundle_local_path => "/tmp",
#  }
#
# === Authors
#
# Felice Pizzurro <felice.pizzurro@softecspa.it>
#
class etckeeper_maintenance (
  $s3_bucket_name     = $::s3_etckeeper_bucket,
  $max_dimension      = '300',
  $bucket_type        = 's3',
  $bundle_local_path  = '/var/local/git-bundle/',
) {

  include git
  include etckeeper

  if ! is_integer($max_dimension) {
    fail('variable max_dimension must have an integer value (MB)')
  }

  if $bucket_type == '' {
    fail('Please specify bucket_type (actually only s3 is available)')
  }

  if ( $bucket_type == 's3' and $s3_bucket_name =='' ) {
    fail ('Please specify s3_bucket_name!')
  }

  if ( $bundle_local_path =='' ) {
    fail ('Please specify bundle_local_path!')
  }

  file { $bundle_local_path:
    ensure  => directory,
    mode    => '0644',
    owner   => 'root',
    group   => 'root',
  }

  exec { 'git-etc-bundle':
    cwd       => '/etc',
    command   => "git bundle create ${bundle_local_path}/etc-`date +'%Y%m%d'`.bdl --all && /bin/rm -rf /etc/.git && git init",
    onlyif    => "true && [ `du -mcs /etc/.git | grep total | awk '{print \$1}'` -gt ${max_dimension} ]",
  }

  etckeeper_maintenance::put_to_bucket {'move-to-bucket':}

  exec { 'remove-local-bundle':
    cwd     => $bundle_local_path,
    command => 'rm -f *.bdl',
    onlyif  => "test $(find ${bundle_local_path} -name \"*.bdl\" | wc -l) -gt 0",
  }

  Class['etckeeper'] ->
  Exec['git-etc-bundle'] ->
  Etckeeper_maintenance::Put_to_bucket['move-to-bucket'] ->
  Exec['remove-local-bundle']
}
