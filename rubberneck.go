package main

import (
  "encoding/json"
  "fmt"
  "strings"
  "sync"
  "github.com/aws/aws-sdk-go/aws"
  "github.com/aws/aws-sdk-go/service/ec2"
)

func main() {
  instances := make([]Instance, 0)
  var cloudWaitGroup sync.WaitGroup
  cloudWaitGroup.Add(2)
  go func() {
    defer cloudWaitGroup.Done()
    var projectWaitGroup sync.WaitGroup
    projectWaitGroup.Add(len(gcpProjects))
    for projectIndex, _ := range gcpProjects {
      go func(projectIndex int) {
        defer projectWaitGroup.Done()
        var workerTypeWaitGroup sync.WaitGroup
        workerTypeWaitGroup.Add(len(gcpWorkerTypes))
        for workerTypeIndex, _ := range gcpWorkerTypes {
          gcpZones, err := gcpZoneList(gcpProjects[projectIndex])
          if err != nil {
            fmt.Println("error:", err)
          } else {
            go func(workerTypeIndex int) {
              defer workerTypeWaitGroup.Done()
              var zoneWaitGroup sync.WaitGroup
              zoneWaitGroup.Add(len(gcpZones))
              for zoneIndex, _ := range gcpZones {
                go func(zoneIndex int) {
                  defer zoneWaitGroup.Done()
                  machines, err := gcpMachineList(gcpProjects[projectIndex], gcpZones[zoneIndex], append(gcpFilters, fmt.Sprintf("labels.worker-type = %v", gcpWorkerTypes[workerTypeIndex])))
                  if err != nil {
                    fmt.Println(fmt.Sprintf("error retrieving %v machine list for gcp %v in zone %v", gcpWorkerTypes[workerTypeIndex], gcpProjects[projectIndex], gcpZones[zoneIndex]), err)
                  } else {
                    //fmt.Printf("%v machine count for gcp %v in zone %v is: %v\n", gcpWorkerTypes[workerTypeIndex], gcpProjects[projectIndex], gcpZones[zoneIndex], len(machines))
                    var machineWaitGroup sync.WaitGroup
                    machineWaitGroup.Add(len(machines))
                    for machineIndex, _ := range machines {
                      go func(machineIndex int) {
                        defer machineWaitGroup.Done()
                        instance := Instance {
                          Machine: machines[machineIndex],
                          Worker: Worker {
                            Id: func() string { if strings.Contains(gcpWorkerTypes[workerTypeIndex], "linux") { return machines[machineIndex].Id } else { return machines[machineIndex].Name } }(),
                            Provisioner: func() string { if strings.Contains(gcpWorkerTypes[workerTypeIndex], "linux") { return "gce" } else { return "releng-hardware" } }(),
                            Type: gcpWorkerTypes[workerTypeIndex],
                            Group: func() string { if strings.Contains(gcpWorkerTypes[workerTypeIndex], "linux") { return machines[machineIndex].Zone } else { return machines[machineIndex].Region } }(),
                            Implementation: func() string { if strings.Contains(gcpWorkerTypes[workerTypeIndex], "linux") { return "docker-worker" } else { return "generic-worker" } }(),
                          },
                        }
                        message := fmt.Sprintf("cloud: %v, zone: %v, name: %v, instance: %v, machine: %v, worker: %v/%v/%v, created: %v",
                          instance.Machine.Cloud,
                          instance.Machine.Zone,
                          instance.Machine.Name,
                          instance.Machine.Id,
                          instance.Machine.Type,
                          instance.Worker.Type,
                          instance.Worker.Group,
                          instance.Worker.Id,
                          instance.Machine.Spawned)
                        workerState, err := GetWorkerState(instance.Worker.Provisioner, instance.Worker.Type, instance.Worker.Group, instance.Worker.Id)
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
                      }(machineIndex)
                    }
                    machineWaitGroup.Wait()
                  }
                }(zoneIndex)
              }
              zoneWaitGroup.Wait()
            }(workerTypeIndex)
          }
        }
        workerTypeWaitGroup.Wait()
      }(projectIndex)
    }
    projectWaitGroup.Wait()
  }()
  go func() {
    defer cloudWaitGroup.Done()
    var workerTypeWaitGroup sync.WaitGroup
    workerTypeWaitGroup.Add(len(ec2WorkerTypes))
    for workerTypeIndex, _ := range ec2WorkerTypes {
      go func(workerTypeIndex int) {
        defer workerTypeWaitGroup.Done()
        var regionWaitGroup sync.WaitGroup
        regionWaitGroup.Add(len(ec2Regions))
        for regionIndex, _ := range ec2Regions {
          go func(regionIndex int) {
            defer regionWaitGroup.Done()
            machines, err := ec2InstanceList(ec2Regions[regionIndex], append(ec2Filters, &ec2.Filter { Name: aws.String("tag:Name"), Values: []*string{aws.String(ec2WorkerTypes[workerTypeIndex])}}))
            if err != nil {
              fmt.Println(fmt.Sprintf("error retrieving %v machine list for ec2 in region %v", ec2WorkerTypes[workerTypeIndex], ec2Regions[regionIndex]), err)
            } else {
              //fmt.Printf("%v machine count for ec2 in region %v is: %v\n", ec2WorkerTypes[workerTypeIndex], ec2Regions[regionIndex], len(machines))
              var machineWaitGroup sync.WaitGroup
              machineWaitGroup.Add(len(machines))
              for machineIndex, _ := range machines {
                go func(machineIndex int) {
                  defer machineWaitGroup.Done()
                  instance := Instance {
                    Machine: machines[machineIndex],
                    Worker: Worker {
                      Id: machines[machineIndex].Name,
                      Provisioner: "aws-provisioner-v1",
                      Type: ec2WorkerTypes[workerTypeIndex],
                      Group: machines[machineIndex].Region,
                      Implementation: func() string { if strings.Contains(ec2WorkerTypes[workerTypeIndex], "win") { return "generic-worker" } else { return "docker-worker" } }(),
                    },
                  }
                  message := fmt.Sprintf("cloud: %v, zone: %v, name: %v, instance: %v, machine: %v, worker: %v/%v/%v, created: %v",
                    instance.Machine.Cloud,
                    instance.Machine.Zone,
                    instance.Machine.Name,
                    instance.Machine.Id,
                    instance.Machine.Type,
                    instance.Worker.Type,
                    instance.Worker.Group,
                    instance.Worker.Id,
                    instance.Machine.Spawned)
                  workerState, err := GetWorkerState(instance.Worker.Provisioner, instance.Worker.Type, instance.Worker.Group, instance.Worker.Id)
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
                }(machineIndex)
              }
            }
          }(regionIndex)
        }
      }(workerTypeIndex)
    }
  }()
  cloudWaitGroup.Wait()
  m := make(map[string]map[string]int)
  for i := range instances {
    if (m[instances[i].Worker.Type] == nil) {
      m[instances[i].Worker.Type] = make(map[string]int)
      m[instances[i].Worker.Type]["pending"] = 0
      m[instances[i].Worker.Type]["waiting"] = 0
      m[instances[i].Worker.Type]["working"] = 0
    }
    m[instances[i].Worker.Type]["running"] = m[instances[i].Worker.Type]["running"] + 1
    if (instances[i].State != "") {
      m[instances[i].Worker.Type][instances[i].State] = m[instances[i].Worker.Type][instances[i].State] + 1
    }
    
  }
  fm, err := json.MarshalIndent(m, "", "  ")
  if err != nil {
    fmt.Println("error:", err)
  }
  fmt.Println(string(fm))
}