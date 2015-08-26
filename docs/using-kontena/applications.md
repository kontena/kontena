---
title: Applications
toc_order: 1
---

# Applications

Any kind of applications can be easily deployed to Kontena using the Kontena CLI. An application may contain one or more services which are related to each other.

## Init

The `kontena app init` command may be used to prepare your application to be run in Kontena. It will:

* Create a `Dockerfile` file for your project if not already exists.
* Create a `docker-compose.yml` file for your project if not already exists.
* Create a `kontena.yml` file for your project if not already exists.

## Deploy

Your application can be deployed to Kontena Nodes with a single command: `kontena app deploy`. The deploy process will look for [kontena.yml](../references/kontena-yml.md) file (by default) which is used to describe your application. Then, it will take care of everything needed to run your application; it will schedule services across your nodes, pull required images, link services together, set environment variables, configure overlay network configuration, start the containers and more.

The usage of `kontena app deploy` command is as follows:

```
Usage:
    kontena app deploy [OPTIONS] [SERVICE ...]

Options:
    -f, --file FILE               Specify an alternate kontena project file (default: kontena.yml)
    -p, --project-name NAME       Specify an alternate project name (default: directory name)
    -h, --help                    print help
```

**NOTE**: If you don't have kontena.yml file yet in your project, you can get started with `kontena app init` command.

### Using Custom File to Describe Application

By default, Kontena will search for `kontena.yml` file in the current directory. If you want to specify the path to custom file, you can use the `-f` switch.

```
$~ kontena app deploy -f myapp.yml      # application described in myapp.yml file
```

### Project Name

When application is deployed, Kontena will prefix all service names with the name of your application. By default, Kontena is using the name of the current directory. In case you want to use custom project name (prefix your application), you can use the `-p` switch.

```
/foo/bar $~ kontena app deploy          # project name is bar, all services are prefixed "bar"
/foo/bar $~ kontena app deploy -p app   # project name is app, all services are prefixed "app"
```

### Deploying Partial Application

Sometimes you might want to deploy just some parts of your application. If that's the case, you can define the name of those services you want deployed.

```
$~ kontena app deploy wordpress         # only deploy services named "wordpress" and "lb"
```

### Example `kontena.yml`

Here's and example of typical WordPress application described in `kontena.yml` file.

```
wordpress:
  image: wordpress:4.1
  instances: 2
  stateful: true
  ports:
    - 8080:80
  links:
    - mysql:wordpress-mysql
  env_file: wordpress.env
  deploy:
    strategy: ha
    wait_for_port: 80
mysql:
  image: mariadb:5.5
  stateful: true
  environment:
   - MYSQL_ROOT_PASSWORD=secret
```
