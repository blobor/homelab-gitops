<?php
// Nextcloud copies these values into config.php: a key removed here stays active there.
$CONFIG = [
  'trusted_domains' => [
    'drive.private.home.lobor.dev',
    'nextcloud.nextcloud.svc.cluster.local',
  ],
  'token_auth_enforced' => true,
  // false: a provider user whose name is the name of a local account is refused, not logged in as that account
  'user_oidc' => [
    'soft_auto_provision' => false,
  ],
  'memcache.distributed' => '\OC\Memcache\Redis',
  'memcache.locking' => '\OC\Memcache\Redis',
  'redis' => [
    'host' => getenv('VALKEY_HOST'),
    'port' => 6379,
    'password' => (string) getenv('VALKEY_PASSWORD'),
  ],
];
