---
title: Applications
---

# Applications

> Applications has been superceded by [Stacks](stacks.md).

Any kind of application can be easily deployed to Kontena using the Kontena `app` commands. With these commands, you can use Kontena like any regular PaaS platform. One of the most interesting features of Kontena is the ability to import projects from other common PaaS platforms.

Kontena app commands include:

* `kontena app init` - Initialize Application; Import from existing PaaS project
* `kontena app deploy` - Deploy Application
* `kontena app start` - Start Application
* `kontena app stop` - Stop Application
* `kontena app rm` - Remove Application
* `kontena app ps` - List Application Services
* `kontena app logs` - Display Application Logs
* `kontena app monitor` - Monitor Application Service Instances
* `kontena app show` - Display Application Service Details

## Initializing Application

The `kontena app init` command may be used to prepare your application to be run in Kontena. It will:

* Create a `Dockerfile` file for your project if not already exists.
* Create a `docker-compose.yml` file for your project if not already exists.
* Create a `kontena.yml` file for your project if not already exists.

The initialization will generate `Dockerfile`, `docker-compose.yml` and `kontena.yml` files automatically by inspecting the directory where the `kontena app init` command is executed. In the event that this directory contains files used by the [Heroku](https://www.heroku.com) PaaS platform, Kontena will automatically import Heroku settings.

### Importing Heroku PaaS Platform Projects

Heroku is one of the most widely used PaaS platform out there. Heroku projects are described with `app.json` and `Procfile` files located in the root of the project directory. When Kontena detects these files, it generates corresponding services, add-ons and environment variables for docker-compose.yml and kontena.yml. The functionality is very similar to Heroku's [Build and Deploy with Docker](https://devcenter.heroku.com/articles/docker)

**Example**

Given the following files:

**app.json**

```json
{
  "name": "Small Sharp Tool",
  "description": "This app does one little thing, and does it well.",
  "env": {
    "SECRET_TOKEN": {
      "description": "A secret key for verifying the integrity of signed cookies.",
      "generator": "secret"
    },
    "WEB_CONCURRENCY": {
      "description": "The number of processes to run.",
      "value": "5"
    }
  },
  "addons": ["heroku-redis","mongolab:shared-single-small"]
}
```

**Procfile**

```
web: rackup -p $PORT -E production
worker: RACK_ENV=production ruby ./worker.rb run
```

The command `kontena app init` will produce:

**docker-compose.yml**

```yaml
web:
  build: "."
  command: "/start web"
  env_file: ".env"
  links:
  - redis:redis
  - mongolab:mongolab
  environment:
  - REDIS_URL=redis://redis:6379
  - MONGOLAB_URI=mongolab:27017
redis:
  image: redis:latest
mongolab:
  image: mongo:latest
worker:
  build: "."
  command: "/start worker"
  env_file: ".env"
  links:
  - redis:redis
  - mongolab:mongolab
  environment:
  - REDIS_URL=redis://redis:6379
  - MONGOLAB_URI=mongolab:27017
```

**.env**

```
SECRET_TOKEN=41977498daabf8b0f0ffbae63ce8bb4cd137b4a5f89d28248abe27e49724da274794e6bcc7df60a2b2c54ecaf16487830eb6c65e1fcf5aabc6f9cab8d3e34d83
WEB_CONCURRENCY=5
```

**kontena.yml**

```yaml
---
web:
  extends:
    file: docker-compose.yml
    service: web
  image: registry.kontena.local/docker-twitter-stream:latest
redis:
  extends:
    file: docker-compose.yml
    service: heroku-redis
mongolab:
  extends:
    file: docker-compose.yml
    service: mongolab
worker:
  extends:
    file: docker-compose.yml
    service: worker
  image: registry.kontena.local/docker-twitter-stream:latest
```

## Deploying Application

Your application can be deployed to Kontena Nodes with a single command: `kontena app deploy`. The deploy process will look for the [kontena.yml](../references/kontena-yml.md) file (unless an alternative filename was specified), which is used to describe your application. Then, it will take care of everything needed to run your application. It will schedule services across your Nodes, pull required images, link services together, set environment variables, configure overlay networking, start the containers and more.

The usage of the `kontena app deploy` command is as follows:

```
Usage:
    kontena app deploy [OPTIONS] [SERVICE ...]

Options:
    -f, --file FILE               Specify an alternate kontena project file (default: kontena.yml)
    -p, --project-name NAME       Specify an alternate project name (default: directory name)
    -h, --help                    print help
```

**NOTE**: If you don't yet have the kontena.yml file in your project, you can get started with the `kontena app init` command.

### Using Custom File to Describe Application

By default, Kontena will search for the `kontena.yml` file in the current directory. If you want to specify the path to a custom file, you can use the `-f` switch.

```
$ kontena app deploy -f myapp.yml      # application described in myapp.yml file
```

### Project Name

When an application is deployed, Kontena will prefix all service names with the name of your application. By default, Kontena uses the name of the current working directory. If you want to use a custom project name (prefix your application), you can do so via the `-p` switch.

```
/foo/bar $ kontena app deploy          # project name is bar, all services are prefixed "bar"
/foo/bar $ kontena app deploy -p app   # project name is app, all services are prefixed "app"
```

### Deploying Partial Application

Sometimes you might want to deploy just some parts of your application. If that's the case, you can define the name of those specific services that you want deployed.

```
$ kontena app deploy wordpress         # only deploy services named "wordpress" and "lb"
```

### Example `kontena.yml`

Here's an example of a typical WordPress application described in `kontena.yml` file. See the complete kontena.yml reference [here](../references/kontena-yml.md).

```yaml
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

## Stopping Application

The `kontena app stop` command stops running services without removing them.

```
Usage:
    kontena app stop [OPTIONS] [SERVICE] ...

Parameters:
    [SERVICE] ...                 Services to stop

Options:
    -f, --file FILE               Specify an alternate Kontena compose file (default: "kontena.yml")
    -p, --project-name NAME       Specify an alternate project name (default: directory name)
    -h, --help                    print help
```

You can start services again with `kontena app start`

## Starting Application

The `kontena app start` command starts existing services.

```
Usage:
    kontena app start [OPTIONS] [SERVICE] ...

Parameters:
    [SERVICE] ...                 Services to start

Options:
    -f, --file FILE               Specify an alternate Kontena compose file (default: "kontena.yml")
    -p, --project-name NAME       Specify an alternate project name (default: directory name)
    -h, --help                    print help
```

## Remove Application

You can remove an application's services with `kontena app rm`.

```
Usage:
    kontena app rm [OPTIONS] [SERVICE] ...

Parameters:
    [SERVICE] ...                 Remove services

Options:
    -f, --file FILE               Specify an alternate Kontena compose file (default: "kontena.yml")
    -p, --project-name NAME       Specify an alternate project name (default: directory name)
    -h, --help                    print help
```

## List Services of Application

`kontena app ps` lists and displays details about services

```
Usage:
    kontena app ps [OPTIONS] [SERVICE] ...

Parameters:
    [SERVICE] ...                 Services to start

Options:
    -f, --file FILE               Specify an alternate Kontena compose file (default: "kontena.yml")
    -p, --project-name NAME       Specify an alternate project name (default: directory name)
    -h, --help                    print help
```

## Display Application Logs

`kontena app logs` displays combined log entries from services.

```
Usage:
    kontena app logs [OPTIONS] [SERVICE] ...

Parameters:
    [SERVICE] ...                 Services to start

Options:
    -f, --file FILE               Specify an alternate Kontena compose file (default: "kontena.yml")
    -p, --project-name NAME       Specify an alternate project name (default: directory name)
    -h, --help                    print help
```
