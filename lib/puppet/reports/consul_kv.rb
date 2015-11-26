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
    uri = URI.parse(@config["consul_url"] || 'localhost:8500')
    @consul = Net::HTTP.new(uri.host, uri.port)

    put_value(@consul, "last_provisioned", Time.now.iso8601)
    put_value(@consul, "last_report", JSON.pretty_generate(build_report))
    Puppet.notice("Report saved and finished: %s" % self.host)
  end

  def put_value(consul, k, v)
    req = Net::HTTP::Put.new(key_path(k))
    req.body = v
    res = consul.request(req)
    case res
    when Net::HTTPOK
      Puppet.err("Report saved to key %s, %s" % [key_path(k), res.body])
    else
      Puppet.err("Report save failed: %s=%s, error: %s(%s)" % [key_path(k), v, res.body, res.inspect])
    end
  end

  def key_path(slug=nil)
    ["v1", "kv", "puppet_report", self.host, slug].compact.join("/")
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
