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
  // A value of these keys in the database wins over this block. The hook deletes those at every start.
  'eurooffice' => [
    'DocumentServerUrl' => 'https://office.private.home.lobor.dev/',
    'DocumentServerInternalUrl' => 'http://office.office.svc.cluster.local/',
    'StorageUrl' => 'http://nextcloud.nextcloud.svc.cluster.local/',
    'jwt_secret' => (string) getenv('EUROOFFICE_JWT_SECRET'),
  ],
  'memcache.distributed' => '\OC\Memcache\Redis',
  'memcache.locking' => '\OC\Memcache\Redis',
  'redis' => [
    'host' => getenv('VALKEY_HOST'),
    'port' => 6379,
    'password' => (string) getenv('VALKEY_PASSWORD'),
  ],
];
