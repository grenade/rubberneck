package main

import (
  "fmt"
  "strings"
  "github.com/aws/aws-sdk-go/aws"
  "github.com/aws/aws-sdk-go/service/ec2"
)

func main() {
  instances := make([]Instance, 0)
  for _, gcpProject := range gcpProjects {
    gcpZones, err := gcpZoneList(gcpProject)
    if err != nil {
      fmt.Println("error:", err)
    } else {
      for _, gcpWorkerType := range gcpWorkerTypes {
        for _, gcpZone := range gcpZones {
          machines, err := gcpInstanceList(gcpProject, gcpZone, append(gcpFilters, fmt.Sprintf("labels.worker-type = %v", gcpWorkerType)))
          if err != nil {
            fmt.Println("error:", err)
          } else {
            fmt.Printf("%v gcp/%v machine count: %v\n", gcpWorkerType, gcpZone, len(machines))
            for _, machine := range machines {
              instance := Instance {
                Machine: machine,
                Worker: Worker {
                  Id: func() string { if strings.Contains(gcpWorkerType, "linux") { return machine.Id } else { return machine.Name } }(),
                  Provisioner: func() string { if strings.Contains(gcpWorkerType, "linux") { return "gce" } else { return "releng-hardware" } }(),
                  Type: gcpWorkerType,
                  Group: machine.Region,
                  Implementation: func() string { if strings.Contains(gcpWorkerType, "linux") { return "docker-worker" } else { return "generic-worker" } }(),
                },
              }
              message := fmt.Sprintf("cloud: %v, zone: %v, name: %v, instance: %v, machine: %v, worker: %v, created: %v",
                instance.Machine.Cloud,
                instance.Machine.Zone,
                instance.Machine.Name,
                instance.Machine.Id,
                instance.Machine.Type,
                instance.Worker.Type,
                instance.Machine.Spawned)
              workerState, err := GetWorkerState(instance.Worker.Provisioner, instance.Worker.Type, instance.Machine.Region, instance.Worker.Id)
              if err != nil {
                fmt.Println("error", err)
              } else {
                if workerState.FirstClaim.IsZero() {
                  instance.State = "pending"
                } else {
                  instance.Worker.FirstClaim = workerState.FirstClaim
                  instance.State = "waiting"
                  message = message + fmt.Sprintf(", first claim: %v", instance.Worker.FirstClaim)
                }
                if workerState.RecentTasks != nil && len(workerState.RecentTasks) > 0 {
                  tasks := make([]Task, 0)
                  for _, task := range workerState.RecentTasks {
                    tasks = append(tasks, Task { Id: task.TaskId, Run: task.RunId })
                  }
                  instance.Worker.Tasks = tasks
                  instance.State = "working"
                  message = message + fmt.Sprintf(", last task: %v/%v", instance.Worker.Tasks[len(instance.Worker.Tasks) - 1].Id, instance.Worker.Tasks[len(instance.Worker.Tasks) - 1].Run)
                }
              }
              fmt.Println(message)
              instances = append(instances, instance)
            }
          }
        }
      }
    }
  }
  for _, ec2WorkerType := range ec2WorkerTypes {
    for _, ec2Region := range ec2Regions {
      machines, err := ec2InstanceList(ec2Region, append(ec2Filters, &ec2.Filter { Name: aws.String("tag:Name"), Values: []*string{aws.String(ec2WorkerType)}}))
      if err != nil {
        fmt.Println("error:", err)
      } else {
        fmt.Printf("%v ec2/%v machine count: %v\n", ec2WorkerType, ec2Region, len(machines))
        for _, machine := range machines {
          instance := Instance {
            Machine: machine,
            Worker: Worker {
              Id: machine.Name,
              Provisioner: "aws-provisioner-v1",
              Type: ec2WorkerType,
              Group: machine.Region,
              Implementation: func() string { if strings.Contains(ec2WorkerType, "win") { return "generic-worker" } else { return "docker-worker" } }(),
            },
          }
          message := fmt.Sprintf("cloud: %v, zone: %v, name: %v, instance: %v, machine: %v, worker: %v, created: %v",
            instance.Machine.Cloud,
            instance.Machine.Zone,
            instance.Machine.Name,
            instance.Machine.Id,
            instance.Machine.Type,
            instance.Worker.Type,
            instance.Machine.Spawned)
          workerState, err := GetWorkerState(instance.Worker.Provisioner, instance.Worker.Type, instance.Machine.Region, instance.Worker.Id)
          if err != nil {
            fmt.Println("error", err)
          } else {
            if workerState.FirstClaim.IsZero() {
              instance.State = "pending"
            } else {
              instance.Worker.FirstClaim = workerState.FirstClaim
              instance.State = "waiting"
              message = message + fmt.Sprintf(", first claim: %v", instance.Worker.FirstClaim)
            }
            if workerState.RecentTasks != nil && len(workerState.RecentTasks) > 0 {
              tasks := make([]Task, 0)
              for _, task := range workerState.RecentTasks {
                tasks = append(tasks, Task { Id: task.TaskId, Run: task.RunId })
              }
              instance.Worker.Tasks = tasks
              instance.State = "working"
              message = message + fmt.Sprintf(", last task: %v/%v", instance.Worker.Tasks[len(instance.Worker.Tasks) - 1].Id, instance.Worker.Tasks[len(instance.Worker.Tasks) - 1].Run)
            }
          }
          fmt.Println(message)
          instances = append(instances, instance)
        }
      }
    }
  }
}