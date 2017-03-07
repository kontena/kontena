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

The `agent` and `server` sources are bind-mounted into the Docker containers, and restarting the containers is sufficient for re-running tests after code changes:

```
$ docker-compose restart api agent
```

However, if you update the `agent` or `server` build (`Dockerfile`, `Gemfile`) files, then you must also rebuild the Docker images:

```
$ rake compose:build
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
core@localhost $ cd /kontena/test
core@localhost /kontena/test $ docker-compose run --rm test rake compose:setup
```

Specs:

```
core@localhost /kontena/test $ docker-compose run --rm test rake
```

or

```
core@localhost /kontena/test $ docker-compose run --rm test rspec spec/
```

Teardown:

```
core@localhost /kontena/test $ docker-compose run --rm test rake compose:teardown
test $ vagrant destroy
```

The `cli` and `test` sources are bind-mounted into the `test` container, and any changes to the cli or test specs will have immediate effect on the next `docker-compose run`.
As for the `rake compose` in general, you can either restart or may need to `rake compose:build` the `server` and `agent` containers on changes.

Oneliner:

```
vagrant up && vagrant ssh -c 'cd /kontena/test && docker-compose up test'
```
