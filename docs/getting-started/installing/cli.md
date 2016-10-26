---
title: CLI
---

## Installing Kontena CLI

> Prerequisities: You'll need Ruby version 2.0 or later installed on your system. For more details, see the official [Ruby installation docs](https://www.ruby-lang.org/en/documentation/installation/).


You can install the Kontena CLI with Rubygems package manager (included in Ruby).

```
$ gem install kontena-cli
```

After the installation is complete, you can test the installation by checking the Kontena CLI version `kontena version`.

**OPTIONAL**

To enable tab-completion for bash, add this to your `.bashrc` scripts:

```
which kontena > /dev/null && . "$( kontena whoami --bash-completion-path )"
```
