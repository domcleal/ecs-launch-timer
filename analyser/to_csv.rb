#!/usr/bin/env ruby

require "aws-sdk-cloudwatchlogs"

cw = Aws::CloudWatchLogs::Client.new(region: "eu-west-1")

# TODO: should loop, will return max of 10k events or 1MB
logs = cw.get_log_events({
  log_group_name: ARGV[0],
  log_stream_name: ARGV[1],
  start_from_head: true,
})

header = nil
logs.events.each do |event|
  next unless event.message =~ /^timestamps ([\w_= ]+)/
  times = {}
  $1.split(" ").each do |kv|
    key, ts = kv.split("=")
    times[key] = ts
  end

  unless header
    header = times.keys.sort
    puts header.join(",")
  end

  puts header.map { |h| times[h] }.join(",")
end
