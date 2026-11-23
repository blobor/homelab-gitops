<?php
// Nextcloud copies these values into config.php: a key removed here stays active there.
$CONFIG = [
  'trusted_domains' => [
    'drive.private.home.lobor.dev',
    'nextcloud.nextcloud.svc.cluster.local',
  ],
  'memcache.distributed' => '\OC\Memcache\Redis',
  'memcache.locking' => '\OC\Memcache\Redis',
  'redis' => [
    'host' => getenv('VALKEY_HOST'),
    'port' => 6379,
    'password' => (string) getenv('VALKEY_PASSWORD'),
  ],
];
