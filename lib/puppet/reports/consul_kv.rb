require 'puppet'
require 'net/https'
require 'uri'
require 'json'
require 'yaml'
require 'time'

Puppet::Reports.register_report(:consul_kv) do
  def process
    configdir = File.dirname(Puppet.settings[:config])
    configfile = File.join(configdir, 'consul_kv.yaml')
    raise(Puppet::ParseError, "Consul KV report config file #{configfile} not readable") unless File.file?(configfile)

    @config = YAML.load_file(configfile)
    uri = URI.parse(@config["consul_url"] || 'http://localhost:8500')
    @consul = Net::HTTP.new(uri.host, uri.port)

    put_value(@consul, key_path("last_provisioned"), Time.now.iso8601)
    report = JSON.pretty_generate(build_report)
    put_value(@consul, key_path("last_report"), report)
    Puppet.notice("Report finished: %s" % self.host)

    if event = @config["event_name"]
      if res = put_value(@consul, event_path(event), report)
        Puppet.notice("Event successfully kicked: %s, Event ID: %s" % [self.host, res["ID"]])
      else
        Puppet.notice("Event kick failed... skipping: %s" % self.host)
      end
    end
  end

  def put_value(consul, path, v)
    req = Net::HTTP::Put.new(key_path(k))
    req.body = v
    res = consul.request(req)
    case res
    when Net::HTTPOK
      Puppet.notice("PUT to consul saved to %s, body: %s" % [path, res.body])
      case res.body.chomp
      when /^true|false$/
        res.body =~ /true/
      else
        json = JSON.parse(res.body)
        json.is_a?(Array) ? json.first : json
      end
    else
      Puppet.err("PUT to consul failed: %s=%s, error: %s(%s)" % [path, v, res.body, res.inspect])
      nil
    end
  end

  def key_path(slug=nil)
    "/" + ["v1", "kv", "puppet_reports", self.host, slug].compact.join("/")
  end

  def event_path(name=nil)
    "/" + ["v1", "event", "fire", name].compact.join("/")
  end

  def build_report
    report = {
      "host" => self.host,
      "kind" => self.kind,
      "status" => self.status,
      "environment" => self.environment,
      "puppet_version" => self.puppet_version,
      "configuration_version" => self.configuration_version,
      "start_time" => (self.logs.first.time.utc.iso8601 rescue ""),
      "end_time" => (self.logs.last.time.utc.iso8601 rescue ""),
      "master_certname" => Puppet.settings[:certname],
    }
    if rev = @config[:revision_file]
      if File.exist?(rev)
        report.merge!("revision" => File.read(rev).chomp)
      else
        Puppet.warn("No REVISION file %s, skipping." % rev)
      end
    end

    report
  end
end
