---
title: Authentication
---

# Authentication

Kontena Master API uses [OAuth2 Bearer token authentication](https://tools.ietf.org/html/rfc6749).

## First user

When a fresh Kontena Master installation starts up, an internal administrator account with a temporary one time authorization code will be created. This initial authorization code is then used to obtain an access token for authenticating as the internal administrator. If you use the Kontena CLI to install the Kontena Master, this will happen automatically. If you install manually, you need to provide the initial authorization code via the environment variable `INITIAL_ADMIN_CODE`. To login using this code use:

```
$ kontena master login --code <INITIAL_ADMIN_CODE> <master_url>
```

## Configuring Kontena Cloud as the authentication provider

If you are installing a fresh Kontena Master v0.16.0 or newer this happens automatically when using Kontena CLI for provisioining unless you select not to use the Kontena Cloud in the installer. You can authenticate from CLI to Kontena Cloud and register a new account by using the command:

```
$ kontena cloud login
```

If you have upgraded your Kontena Master from a previous version or installed Kontena without Kontena CLI plugins you can configure it to use Kontena Cloud by using the command:

```
$ kontena master init-cloud
```

## Adding users

To invite more users you first need to configure the Kontena Master to use an authentication provider. If you use the provisioning tools offered by Kontena CLI this will be done automatically during installation unless selected otherwise.

To add new users you use the invite command:

```
$ kontena master users invite user@example.com
* Invite code: abcd123456
```

The user can then join the master by using the `kontena master join` command:

```
$ kontena master join https://master_ip invitation_code
```

## Using an external authentication provider

Kontena Master can use any standards compliant OAuth2 provider to authenticate users.

If you want to use another authentication provider then the first step is to create an OAuth2 application in the authentication provider's user interface. The **Callback URL** in the application settings should be set to : `https://master_url/cb`. No other settings should be necessary. The next step is to configure the `oauth2.*` settings to Kontena Master.

### Master authentication provider configuration settings

These settings can be set by using the `kontena master config set` command:

```
$ kontena master config set setting.name=setting.value setting.name2=setting.value2
```

Or crafted as a JSON or YAML:

```
{
  "oauth2.client_id": "abcd1234",
  "oauth2.client_secret": "abcdefg",
}
```

and loading that using the `kontena master config import` command:

```
$ kontena master config import settings.json
```


#### `server.root_url`

The base URL to your Master Instance, used to build the callback url. You can use this setting if your master is accessible through a dns name such as `kontena-master.example.com`.

**Example:** `https://10.0.0.1:9292`

#### `oauth2.client_id`

OAuth2 application client id. The value for this setting can usually be obtained when creating an oauth2 application in the provider's user interface.

**Example:** `abcd12345`

#### `oauth2.client_secret`

OAuth2 application client secret. The value for this setting is usually comes from the same information as for the client id.

This value is stored in encrypted format to the configuration (using the `VAULT` encryption keys) to avoid exposing it in database backups.

**Example:** `abcdef1234567`

#### `oauth2.authorize_endpoint`

A full URL to the authentication provider's [OAuth2 authorization endpoint](https://tools.ietf.org/html/rfc6749#section-3.1).

This endpoint is used to request authorization for the Master to access the user's profile information.

The endpoint must support the `code` response_type.

**Example:** `https://authprovider.example.com/oauth2/authorize`

#### `oauth2.token_endpoint`

A full URL to the authentication provider's [OAuth2 token endpoint](https://tools.ietf.org/html/rfc6749#section-3.2)

This endpoint is used to exchange authorization codes for access tokens.

The endpoint must support the `authorization_code` grant_type.

**Example:** `https://authprovider.example.com/oauth2/token`

#### `oauth2.userinfo_scope`

An authorization scope that provides read access to basic user information at `oauth2.userinfo_endpoint`.

**Example:** `user:read`

#### `oauth2.userinfo_endpoint`

A full URL to a userinfo resource accessible using an access access_token with the `oauth2.userinfo_scope` scope for the user.

This endpoint must respond in JSON format and have at least values for user id and email address or username.

**Example:** `https://api.example.com/user`

Some providers may provide user information through a token info endpoint that takes an access token in the URL path. The userinfo endpoint URL setting can include the string `:access_token` which will be replaced with the user's access token:

**Example:** `https://api.example.com/tokeninfo/:access_token`

#### `oauth2.token_method`

The HTTP method to use when requesting access tokens from the token endpoint. Normally it's `POST` but some providers only support `GET` with authorization code as a query parameter in the URL.

**Example:** `post`

#### `oauth2.token_post_content_type`

Content-Type when performing a `POST` request to the token endpoint.

Possible options are:

 - application/json
 - application/x-www-form-urlencoded

**Example:** `application/json`

#### `oauth2.code_requires_basic_auth`

Some providers require that a HTTP Basic authentication header is used with client_id as the username and client_secret as the password when exchanging authorization codes for access tokens.

**Example:** `true`

#### `oauth2.userinfo_username_jsonpath`

A [JSONPath](http://goessner.net/articles/JsonPath/) query that returns a username from the userinfo endpoint json response.

It's possible to define multiple queries by separating them with a semicolon. The first one that returns a hit will be used.

**Example:** `$..username` (will return the value of the first field labeled "username" anywhere in the JSON)

#### `oauth2.userinfo_email_jsonpath`

Same as `oauth2.userinfo_username_jsonpath` but for reading a user's email address.

**Example:** `$..email` (will return the value of the first field labeled "email" anywhere in the JSON, or if the result is an array, the first item in that array)

#### `oauth2.userinfo_user_id_jsonpath`

Same as `oauth2.userinfo_username_jsonpath` but for reading a user's id.

**Example:** `$..uid`


## Authentication flow

This is what happens under the hood during an authentication request to the Kontena Master:

1. An administrator in the master has created an invitation for a user and has obtained an invitation code.
2. User issues the command `kontena master join <https://master_url> <invitation_code>`. If the email address in the invitation matches the one used on the authentication provider, the user can also use normal master login: `kontena master login <https://master_url>` without an invitation code.
3. CLI automatically starts a local web server in the background to listen for the OAuth2 callback in a random TCP port. This server is only accessible through the localhost interface and is not exposed to the internet. The final step of the authentication flow will redirect the user to `http://localhost:<port>/cb?code=<auth_code>` and the CLI's local web server then receives the authorization code from the parameters in that request.
4. CLI requests `https://master_url/authenticate?redirect_uri=http://localhost:<random_port>/cb&invite_code=<invite_code>`
5. Master validates the parameters and tries to find the user by using the invitation code. If an invitation code was not supplied, then the user matching will be performed in the userinfo step by comparing the email address supplied by the auth provider with one in the local user database.
6. Master creates an AuthorizationRequest record with a random `state` id, this will be used to match the callback coming from the auth provider with the original authentication request.
7. Master responds with a redirect to the authentication provider's authorization URL
8. CLI now receives a response to the request in step 4 and opens a browser to the returned authorization URL.
9. The user sees a consent prompt asking for agreement to give the Master access to the user's basic information
10. User clicks Agree, the authentication provider redirects the user back to `https://master_url/cb?code=<authorization_code>&state=<state>`
11. Master parses the query parameters and finds the existing authorization request using the state parameter
12. Master exchanges the authorization code for an access token from the authentication provider's token endpoint
13. Master requests user information using the received access token and updates the user's external id and username/email in the local user database.
14. Master creates a local access token with an authorization code
15. Master responds with a redirect to `http://localhost:<random_port>/cb?code=<authorization_code>`
16. The user's browser follows the redirect to the local webserver which then parses the code from the query parameters.
17. The local web server is terminated
18. The CLI exchanges the authorization code for an access token with the Master
19. The access token is saved to client's `$HOME/.kontena_client.json`
20. The CLI has now been authenticated to access the Master API.

If the user has already performed an authentication to the Master, an invitation code is no longer needed because the external user id for the user is already present. Subsequent authentications will be performed using the same flow without an invitation code and without having to click Agree because the application has already been approved.

## Authenticating without a local browser

Sometimes the user could be using the CLI over a terminal connection or some other non graphical user interface where it's impossible to open a local browser to perform the authentication web flow.

It's possible to perform the authorization web flow on another computer by using the `--remote` parameter :

```
$ kontena master login --remote <https://master_url>
or
$ kontena master join --remote <https://master_url> <invite_code>
```

The CLI will output a link that the user can open on some other computer. After the flow is completed the browser will display an authorization code that the user can use to complete the authentication:

```
$ kontena master login --code <authorization_code> <https://master_url>
```

It's also possible to use an access token created using another computer and complete the authentication without using a browser at all by using the `--code` parameter:

```
$ kontena master token create --code
$ kontena master login --code <code> <https://master_url>
```

## Resetting the internal administrator account

If you have lost access to the master, you will need to reset the Kontena Master internal administrator account.

This can be done by using SSH to connect to the master.

```
$ kontena master ssh
```

Or if your master is running on Vagrant:

```
$ kontena vagrant master ssh
```

Then run the following command:

```
$ docker exec -t kontena-server-api rake kontena:reset_admin
Internal administrator account has been reset.

To authenticate your kontena-cli use this command:
kontena master login --code <auth_code> <master_url>
```

Now you can authenticate from the CLI as the Kontena Master internal administrator by using the given command line. Exit the master ssh and enter the command:

```
$ kontena master login --code <auth_code> <master_url>
```
