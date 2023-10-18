
nginx['enable'] = false
#nginx['redirect_http_to_https'] = true

letsencrypt['auto_renew'] = false
#letsencrypt['contact_emails'] = ['ops@thgttg.com']

web_server['external_users'] = ['nginx']

## gitlab
external_url "https://gitlab.thgttg.com"

## container registry
registry_external_url "https://registry.thgttg.com"
#registry_nginx['redirect_http_to_https'] = true

## mattermost
mattermost_external_url "https://mattermost.thgttg.com"
#mattermost_nginx['redirect_http_to_https'] = true
