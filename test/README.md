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

## Vagrant test environment using Docker Compose

This environment is built from sources with CoreOS running in Virtualbox.

Setup:

```
test $ vagrant up
test $ vagrant ssh
core@localhost $ cd ~/kontena/test
core@localhost ~/kontena/test $ docker-compose run --rm test rake compose:setup
```

Specs:

```
test $ vagrant ssh
core@localhost ~/kontena/test $ docker-compose run --rm test rake
```

Teardown:

```
test $ vagrant ssh
core@localhost ~/kontena/test $ docker-compose run --rm test rake compose:teardown
test $ vagrant destroy
```
