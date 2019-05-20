#!/usr/bin/env ruby

require "aws-sdk-cloudwatchlogs"
require "aws-sdk-ecs"

class AwsLogger
  def initialize(cw)
    @cw = cw
    @msgs = []
  end

  def <<(msg)
    @msgs << {
      timestamp: (Time.now.utc.to_f.round(3) * 1000).to_i,
      message: msg,
    }
    puts msg
  end

  def flush
    token = @cw.describe_log_streams({
      log_group_name: "launch-timer",
      log_stream_name_prefix: "launcher",
      limit: 1,
    }).log_streams[0].upload_sequence_token

    @cw.put_log_events({
      log_group_name: "launch-timer",
      log_stream_name: "launcher",
      log_events: @msgs,
      sequence_token: token,
    })
  end
end

cw = Aws::CloudWatchLogs::Client.new(region: "eu-west-1")
logger = AwsLogger.new(cw)

timestamps = {}

ecs = Aws::ECS::Client.new(region: "eu-west-1")
new_task = ecs.run_task(
  cluster: "ecs-fargate-dev",
  task_definition: "scratch:2",
  launch_type: "FARGATE",
  network_configuration: {
    awsvpc_configuration: {
      subnets: ["subnet-000cca9cf53c5e02a", "subnet-0078e79ec6c3bf342"],
    },
  },
)
task_arn = new_task.tasks[0].task_arn

loop do
  task = ecs.describe_tasks(cluster: "ecs-fargate-dev", tasks: [task_arn]).tasks.first

  [
    :connectivity_at,
    :pull_started_at,
    :pull_stopped_at,
    :execution_stopped_at,
    :created_at,
    :started_at,
    :stopping_at,
    :stopped_at,
  ].each do |ts|
    timestamps[ts] ||= task.public_send(ts)
  end

  break if task.last_status == "STOPPED"
end

logger << "timestamps #{timestamps.sort_by { |k, v| k }.map { |k, v| "#{k}=#{v.to_i}" }.join(" ")}"

logger.flush
