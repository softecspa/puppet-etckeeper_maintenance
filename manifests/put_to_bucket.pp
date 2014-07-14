define etckeeper_maintenance::put_to_bucket {

  if  $etckeeper_maintenance::bucket_type == 's3' {

    if ! defined(Class["s3cmd"]) {
      class {"s3cmd":
        access_key  => $aws_access_key,
        secret_key  => $aws_secret_key,
      }
    }

    s3cmd::put {'put-git-bundle-to-s3':
      source      => "${etckeeper_maintenance::bundle_local_path}/*.bdl",
      bucket_name => $etckeeper_maintenance::s3_bucket_name,
      prefix      => $fqdn,
      require     => Class["s3cmd"],
    }
  }
}
