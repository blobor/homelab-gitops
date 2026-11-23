#!/bin/sh
# Settings that Nextcloud keeps in its database. No failure here may stop the start.
[ "$(basename "$(dirname "$0")")" = before-starting ] || exit 0
occ() { php /var/www/html/occ "$@"; }
discovery=https://auth.home.lobor.dev/application/o/nextcloud/.well-known/openid-configuration

# In maintenance mode occ does not load the commands of apps.
if ! occ status --output=json 2>/dev/null | tail -n 1 \
    | php -r '$s = json_decode(stream_get_contents(STDIN), true); exit(($s["installed"] ?? false) && !($s["maintenance"] ?? true) && !($s["needsDbUpgrade"] ?? true) ? 0 : 1);'; then
  echo "app settings: skipped, the instance is in maintenance or needs an upgrade"
  exit 0
fi

[ -d /var/www/html/custom_apps/user_oidc ] || occ app:install user_oidc || echo "app settings: the install of user_oidc failed"
if occ app:enable user_oidc \
    && occ user_oidc:provider authentik \
      --clientid=nextcloud --clientsecret-env=OIDC_CLIENT_SECRET --discoveryuri="$discovery" \
      --scope="openid email profile" \
      --unique-uid=0 --mapping-uid=preferred_username --mapping-display-name=name --mapping-email=email \
      --group-provisioning=0 \
    && curl -fsS -m 10 -o /dev/null "$discovery"; then
  # /login then goes to the provider at once. The password form stays at /login?direct=1.
  occ config:app:set --type=string --value=0 user_oidc allow_multiple_user_backends || echo "app settings: the login redirect is not set"
else
  echo "app settings: user_oidc is not configured or the provider does not answer"
fi

occ config:app:set --type=boolean --value=false dav enableDefaultContact || echo "app settings: the sample contact stays on"
occ config:app:set --type=boolean --value=false dav create_example_event || echo "app settings: the sample event stays on"
exit 0
