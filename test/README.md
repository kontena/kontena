# Kontena E2E Test Suite


## Running tests

Note: you need to setup environment first.

```
$ rake
```

or

```
$ bundle exec rspec spec/
```


## Local test environment using Docker Compose

This environment is built from sources.

Setup:

```
$ rake compose:setup
```

Teardown:

```
$ rake compose:teardown
```

## Local test environment using Vagrant

This environment uses official images. Version can be defined via `VERSION` environment variable (default: edge).

Setup:

```
$ rake vagrant:setup
```

Teardown:

```
$ rake vagrant:teardown
```
