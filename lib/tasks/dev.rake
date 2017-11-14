# frozen_string_literal: true
require 'solr_wrapper'
require 'open4'

namespace :server do
  desc "Start redis server"
  task :redis do
    pid, _redisin, _redisout, _rediserr = Open4.popen4 'redis-server'
    $stderr.puts "Redis running on 127.0.0.1:6379"
    Signal.trap("INT") do |signo|
      $stderr.print "Shutting down redis..."
      Process.kill(signo, pid)
    end
    Process.waitpid2 pid
    $stderr.puts "done."
  end

  desc "Start solr server for testing"
  task :test do
    SolrWrapper.wrap(shared_solr_opts.merge(port: 8984, instance_dir: 'tmp/blacklight-core-test')) do |solr|
      solr.with_collection(name: "blacklight-core-test", dir: File.expand_path("../../../solr/config", __FILE__).to_s) do
        $stderr.puts solr_message(solr)
        loop { sleep 1 }
        $stderr.print "Shutting down solr..."
      end
    end
    $stderr.puts "done."
  end

  desc "Cleanup test servers"
  task :clean_test do
    SolrWrapper.instance(shared_solr_opts.merge(port: 8984, instance_dir: 'tmp/blacklight-core-test')).remove_instance_dir!
    puts "Cleaned up test solr server."
  end

  desc "Start solr server for development"
  task :development do
    SolrWrapper.wrap(shared_solr_opts.merge(port: 8983, instance_dir: 'tmp/blacklight-core')) do |solr|
      solr.with_collection(name: "blacklight-core", dir: File.expand_path("../../../solr/config", __FILE__).to_s) do
        $stderr.puts solr_message(solr)
        loop { sleep 1 }
        $stderr.print "Shutting down solr..."
      end
    end
    $stderr.puts "done."
  end

  def solr_message(solr)
    port = solr.config.options[:port]
    core = solr.config.options[:instance_dir].split('/').last
    "Solr running on http://127.0.0.1:#{port}/solr/#{core}"
  end

  def shared_solr_opts
    opts = { managed: true, verbose: true, persist: false, download_dir: "tmp" }
    opts[:version] = ENV['SOLR_VERSION'] if ENV['SOLR_VERSION']
    opts
  end
end
