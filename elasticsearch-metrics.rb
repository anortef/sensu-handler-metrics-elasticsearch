#!/usr/bin/env ruby
#
# Sensu Elasticsearch Metrics Handler

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'net/http'
require 'timeout'
require 'digest/md5'
require 'date'

class ElasticsearchMetrics < Sensu::Handler
  def host
    settings['elasticsearch']['host'] || 'localhost'
  end

  def port
    settings['elasticsearch']['port'] || 9200
  end

  def es_index
    @event['check']['name'] || 'sensu-metrics'
  end

  def es_id
    rdm = ((0..9).to_a + ("a".."z").to_a + ("A".."Z").to_a).sample(3).join
    Digest::MD5.new.update("#{rdm}")
  end

  def time_stamp
    d = DateTime.now
    d.to_s
  end

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def check_es_type
    @event['check']['name']
  end

  def handle
     metrics ={}
     @event['check']['output'].split("\n").each do |line|
       v = line.split("\t")
       v.each do |actualResults|
         values = actualResults.split(" ")
       #if /percentage|five/ =~ v[0]
         valueMetric = values[1]
         metrics = {
            :@timestamp => time_stamp,
            :client => @event['client']['name'],
            :check_name => @event['check']['name'],
            :status => @event['check']['status'],
            :address => @event['client']['address'],
            :command => @event['check']['command'],
            :occurrences => @event['occurrences'],
            :key => values[0],
            :value => valueMetric.to_f
         }
         begin
           timeout(5) do
             uri = URI("http://#{host}:#{port}/#{es_index}/#{check_es_type}/#{es_id}")
             http = Net::HTTP.new(uri.host, uri.port)
             request = Net::HTTP::Post.new(uri.path, "content-type" => "application/json; charset=utf-8")
             request.body = JSON.dump(metrics)

             response = http.request(request)
             if response.code == '200' || response.code == '201'
               puts "request metrics #=> #{metrics}"
               puts "request body #=> #{response.body}"
               puts "elasticsearch post ok."
             else
               puts "request metrics #=> #{metrics}"
               puts "request body #=> #{response.body}"
               puts "elasticsearch post failure. status error code #=> #{response.code}"
             end
           end
         rescue Timeout::Error
           puts "elasticsearch timeout error."
         end
       #end
       end
    end
  end
end
