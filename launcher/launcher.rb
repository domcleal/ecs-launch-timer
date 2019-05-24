#!/usr/bin/env ruby

require "aws-sdk-cloudwatchlogs"
require "aws-sdk-ecs"

class AwsLogger
  def initialize(cw, stream, log_group_name)
    @cw = cw
    @stream = stream
    @log_group_name = log_group_name
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
      log_group_name: @log_group_name,
      log_stream_name_prefix: @stream,
      limit: 1,
    }).log_streams[0].upload_sequence_token

    @cw.put_log_events({
      log_group_name: @log_group_name,
      log_stream_name: @stream,
      log_events: @msgs,
      sequence_token: token,
    })
  end
end

def lambda_handler(event:, context:)
  cluster = event["cluster"]
  log_group = event["log_group"]
  task_definition = event["task_definition"]
  cw = Aws::CloudWatchLogs::Client.new(region: "eu-west-1")
  logger = AwsLogger.new(cw, cluster, log_group)

  timestamps = {}

  ecs = Aws::ECS::Client.new(region: "eu-west-1")
  new_task = ecs.run_task(
    cluster: cluster,
    task_definition: task_definition,
    launch_type: cluster.include?("fargate") ? "FARGATE" : "EC2",
    network_configuration: {
      awsvpc_configuration: {
        subnets: ["subnet-000cca9cf53c5e02a", "subnet-0078e79ec6c3bf342"],
      },
    },
  )
  task_arn = new_task.tasks[0].task_arn

  loop do
    task = ecs.describe_tasks(cluster: cluster, tasks: [task_arn]).tasks.first

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

    sleep 5

    break if task.last_status == "STOPPED"
  end

  logger << "timestamps #{timestamps.sort_by { |k, v| k }.map { |k, v| "#{k}=#{v.to_i}" }.join(" ")}"

  logger.flush
end
