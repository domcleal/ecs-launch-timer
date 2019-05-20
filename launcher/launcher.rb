#!/usr/bin/env ruby

require "aws-sdk-ecs"

ecs = Aws::ECS::Client.new(region: "eu-west-1")
ecs.run_task(
  cluster: "ecs-fargate-dev",
  task_definition: "scratch:2",
  launch_type: "FARGATE",
  network_configuration: {
    awsvpc_configuration: {
      subnets: ["subnet-000cca9cf53c5e02a", "subnet-0078e79ec6c3bf342"],
    },
  },
)
