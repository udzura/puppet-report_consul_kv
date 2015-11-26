# udzura-report_consul_kv

#### Table of Contents

1. [Overview](#overview)
2. [Setup - The basics of getting started with report_consul_kv](#setup)
3. [Usage - Configuration options and additional functionality](#usage)
4. [Development - Guide for contributing to the module](#development)

## Overview

Puppet reporter which save details to Consul KV

## Setup

Run:

```bash
puppet module install udzura-report_consul_kv
# or use librarian-puppet
```

## Usage

Create config file `/etc/puppet/consul_kv.yaml` on your master:

```yaml
---
consul_url: "http://consul.host:8500" # default to localhost:8500
event_name: "puppet-apply"
```

`event_name` is optional, and if it is set, puppet master kicks consul event
every time agent runs.

If you have any REVISION file(e.g. when you deployed manifests with Capistrano), please set `revision_file`.

Then set and restart puppetserver:

```toml
[master]
#...

report  = true
reports = consul_kv
```

After this, puppet will save the reports to consul keys:

* `"/puppet_reports/${hostname}/last_report"` for the time last provisioned
* `"/puppet_reports/${hostname}/last_report"` for detail

## Development

Fork, modify, pull request.

## License

See `LICENSE`
