---
title: kontena.yml variables reference
toc_order: 2
---

# Kontena.yml variables reference

Since Kontena version 1.0.0 and the introduction of [Stacks](../using-kontena/stacks.md) you can define variables to be used to fill in values and to create conditional logic in [kontena.yml](kontena-yml.md) files.

## Usage example

```
---
stack: user/wordpress
version: 1.0.0
description: Wordpress with an optional database
variables:
  mysql_root_pw: # variable name
    type: string  # type (string, integer, boolean, uri, enum)
    min_length: 8 # require at least 8 characters
    from: # where to obtain a value for this variable
      vault: ${STACK}-wp-mysql-root # try to get a value from the vault on kontena master
      env: MYSQL_ROOT # first try local env variable
      prompt: Enter a root password for MySQL or leave empty to auto generate # then ask for manual input
      random_string: 16 # still no value, auto generate a random string
    to:
      vault: ${STACK}-wp-mysql-root # send this value to the vault on kontena master
  mysql_version:
    type: enum # a list of predefined options
    default: latest # default value
    options:
      - 5.5
      - latest
  use_mariadb:
    type: boolean
    from:
      prompt: Use MariaDB?
  image_mysql:
    skip_if: use_mariadb # process this only if "use_mariadb" is falsey
    type: string
    value: mysql # set a fixed value
    to:
      env: db_image # place the value into local env variable "db_image"
  image_mariadb:
    only_if: use_mariadb # process this only if "use_mariadb" if truthy
    type: string
    value: mariadb
    to:
      env: db_image # place the value into local env variable "db_image"
services:
  mysql:
    image: ${db_image}:${mysql_version} # use the variables
    stateful: true
    secrets:
      - secret: wp-mysql-root # expose MYSQL_ROOT_PASSWORD to the container from vault key wp-mysql-root
        name: MYSQL_ROOT_PASSWORD
        type: env
```

End result: A MySQL stack where you can select to use MariaDB, select a version and place the root password into vault on Kontena Master.

## Anatomy of a variable definition

### The variable name

```
variables:
  this_is_the_name:
```

By default, a local environment variable with the same name gets populated with the variables value. You can then use it later in the yaml as: `${this_is_the_name}`.

```
  environment:
    - ENV_VAR=${this_is_the_name}
```

It is also used when referencing this variable in conditional statements.

### From

Define where a value for the variable is obtained from. A list of resolvers and their options can be found further in this documentation.

You can define multiple sources, for example:

```
  from:
    env: MYSQL_USER # First try local environment variable
    file: # Then try to read from a file
      path: /tmp/mysql_user.txt
      ignore_errors: true
    prompt: Enter MySQL username # finally ask for a value if still not found
```

### To

Define what to do with the value. The default behavior is to set it to local environment using the variable name. You can also use another environment variable name or write the value to the Vault on Kontena Master.

```
  to:
    env: MYSQL_USER # set to local env
    vault: foo-mysql-user # also send to vault
```

### Conditionals

Sometimes it's necessary to add some conditional logic that determine which variables are used or prompted from the user.

#### `only_if`

Process the variable or service only when provided conditions are true.

##### The most basic syntax:

```
  only_if: use_mariadb
  # Only process this variable if value of the variable "use_mariadb"
  # is not false, null or a string that says "false".
```

##### Multiple requirements (AND):

```
  only_if:
    - use_mariadb
    - mysql_username
  # Require both values to be something other than false, null or a string
  # saying "false".
```

##### Comparison

```
  only_if:
    use_mysql: true
    mysql_version: 5.5
  # Require use_mysql to be true and mysql_version to be "5.5"
```

#### `skip_if`

Works just the same as `only_if`, but opposite. The processing of this variable will be skipped if the conditions are true.

```
  skip_if: use_mysql # don't process this variable if use_mysql has a truthy value.
```

### Type

Data type for the variable, options are: string, integer, boolean, enum and uri.

```
  type: string
```

### Type handler options

Everything else is passed to the type handler as options:

```
username:
  type: string
  min_length: 10 # require length to be at least 10 characters
  max_length: 16 # and maximum of 16 characters
  downcase: true # make the string all lower case
```

## Data types

The data types can have several options, validations, sanitizations and transformations. For example, the minimum length of a string can be defined, the string can be converted to UPPER CASE characters and cleaned up of leading/trailing whitespace.

There's a global validation applicable to all data types:

```
  type: string
  in:  # require that the value is one of a, b or c.
    - a
    - b
    - c
```

### `boolean`

```
   truthy: ["true", "yes", "1", "on", "enabled", "enable"]
```

If the input value is one of these, set the value of this boolean to **True**. Everything else will be **false**.

```
    nil_is: false
```

If there is no value, set the value to **false** by default.

```
     blank_is: false
```

A blank but not null string will be set to **false** by default.

```
     as: string
```

By default, the output will be turned into a string that is either "true" or "false" depending on the value of the variable. You can also set it to "integer" to use 0 and 1 instead.

```
     false: "false"
     true: "true"
}
```

Define custom output for the values.

### `enum`

An enumerator data type, a list of predefined possible values that the user can select from.

```
  options:
    - usa
    - eu
    - asia
```

Or to define more readable labels for the values when prompting from the user:

```
  options:
    - value: usa
      label: United States
    - value: eu
      label: European Union
    - value: asia
      label: Asia
```

Complete example:

```
variables:
  zone:
    type: enum
    default: eu
    options:
      - usa
      - eu
      - asia
    from:
      env: STORAGE_ZONE
      prompt: Select zone

services:
  storage:
    image: storage:latest
    environment:
      - "STORAGE_ZONE=${zone}"
```

With this configuration you can set the storage zone by setting the environment variable `STORAGE_ZONE` before installing the stack. If you don't, the zone will be prompted and the default value in the selector will be "eu".

### `integer`

```
  min: 0 # minimum value, can be negative
  max: nil # maximum value
  nil_is_zero: false # null value will be turned into zero
```

### `string`

```
  min_length: nil # minimum length
  max_length: nil # maximum length
  hexdigest: nil  # hexdigest output. options: md5, sha1, sha256, sha384 or sha512.
  empty_is_nil: true, # if string contains whitespace only, make value null
  encode_64: false # encode content to base64
  decode_64: false # decode content from base64
  upcase: false # convert to UPPERCASE
  downcase: false # convert to lowercase
  strip: false # remove leading/trailing whitespace,
  chomp: false # remove trailing linefeed
  capitalize: false # convert to Capital case.

```

### `uri`

```
  schemes:
    - http
    - https
```

Only allow http:// and https:// uris by default.

## Resolvers (From:)

Resolvers are used to obtain a value for the variable from several inputs. If you define multiple sources, they will be processed one by one until one of them results in a non-null value.

Resolvers can take a "hint", for example the environment variable resolver takes the environment variable name as the hint.

### `env`
Hint is the environment variable name to read from. Defaults to the option's name.

### `file`

Read content from a file into a variable.

```
from:
  file: /tmp/password.txt
```

Or:

```
from:
  file:
    path: /tmp/password.txt
    ignore_errors: true # if the file does not exist, just return nil. Otherwise it would give a file not found error.
```

### `random_number`

Hint must be a hash containing `min: minimum_number, max: maximum_number`

Example:

```
from:
  random_number:
    min: 2
    max: 10
```

This will generate a random number between 2 and 10.

### `random_string`

Hint can be a number that defines the length for the generated string, the default charset 'alphanumeric' is then used.
Hint can also be a hash that defines the length and the charset to be used:

```
from:
  random_string:
    length: 32
    charset: hex_upcase
```

### `interpolate`

Hint must be a string. Variable references in that string template will be used to build the final value.

```
name:
  type: string
  value: World

greeting:
  type: string
  from:
    interpolate: Hello, ${name}!
```

### `evaluate`

Hint must be a string. Can be used to perform simple calculations using the values of other variables.

```
nodes:
  type: integer
  value: 3

quorum:
  type: integer
  from:
    evaluate: (${nodes}/2) + 1
```

##### Defined charsets:
 * numbers (0-9)
 * letters (a-z + A-Z)
 * downcase (a-z)
 * upcase (A-Z)
 * alphanumeric (0-9 + a-z + A-Z)
 * hex (0-9 + a-f)
 * hex_upcase (0-9 + A-F)
 * base64 (base64 charset (length has to be divisible by four when using base64))
 * ascii_printable (all printable ascii chars)
 * or a set of characters, for example: `length: 8, charset: '01'` will generate something like: **01001100**

### `random_uuid`
Ignores the hint completely.

Output is a 'random' UUID, such as `78b6decf-e312-45a1-ac8c-d562270036ba`

### `vault`

Use the Vault on kontena master. The hint is the key in the vault.

```
from:
  vault: wordpress-admin-password
```

You could set this value by using: `kontena vault write wordpress-admin-password p4ssw0rd1234`

### `service_instances`

Fetch value (service instances count) from given service instance. The hint is the service name within the stack.

```
from:
  service_instances: wordpress
```

This resolver is handy if you want to change scaling after the stack has been deployed.


### `prompt`

Ask the user interactively. The hint is the question text.

```
from:
  prompt: Enter username
```

## Setters (To:)

There are currently only two setters. Either send the value to a local environment variable or write it to the Vault on Kontena Master.

### `env`

Variable value will be placed into local environment.

```
to:
  env: MYSQL_USERNAME
# sets a local environment variable, not to be confused with setting an environment variable to
# the container
```

### `vault`

Variable value will be written to the Vault on Kontena Master

```
to:
  vault: wordpress-admin-password
```

## Default variables

### `${STACK}`

Contains the current stack name, for example when doing `kontena stack install -n <stack_name> file.yml`. This is useful to namespace vault variables.

### `${GRID}`

Contains the current grid. Useful for example when constructing urls, such as: `db.${STACK}.${GRID}.kontena.local`.

## Notes

The variables are interpolated into the raw YAML before parsing. This can cause the YAML to become invalid. Often you can avoid that by using quotes:

```
environment:
  - "PASSWORD=${random_password}"
```
