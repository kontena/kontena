# Kontena::Cli
[![Gem Version](https://badge.fury.io/rb/kontena-cli.svg)](http://badge.fury.io/rb/kontena-cli)

This is a command line tool for [Kontena](http://www.kontena.io).

## Installation
> Prerequisities: [Ruby](https://www.ruby-lang.org/en/) version 2.2.0 or greater.

Install it yourself as:

    $ gem install kontena-cli

To enable tab-completion for bash, add this to your `.bashrc` scripts (or `.zshrc` for zsh):

```
which kontena > /dev/null && . "$( kontena whoami --bash-completion-path )"
```

## Usage

First you need to register as a user:

    $ kontena register

Then you can login to master server:

    $ kontena login https://<master>:8080

To get list of all commands:

    $ kontena help

## Contributing

1. Fork it ( https://github.com/kontena/kontena-cli/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

Kontena is licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE.txt) for full license text.
