package main

import (

  "golang.org/x/net/context"
  "google.golang.org/api/compute/v1"
  "golang.org/x/oauth2/google"

  "fmt"
  "strings"
)

func GoogleCompute() {
  projects := [...]string{
    "windows-workers",
  }
  filters := [...]string{
    "status = RUNNING",
    "name != releng-gcp-provisioner-0",
    "name != releng-gcp-provisioner-1",
    "name != releng-gcp-provisioner-2",
    "name != releng-gcp-provisioner-3",
    "name != releng-gcp-provisioner-4",
    "name != releng-gcp-provisioner-5",
    "name != releng-gcp-provisioner-6",
    "name != releng-gcp-provisioner-7",
    "name != releng-gcp-provisioner-8",
    "name != releng-gcp-provisioner-9",
  }

  ctx := context.Background()
  client, err := google.DefaultClient(ctx,compute.ComputeScope)
  if err != nil {
    fmt.Println(err)
  }
  computeService, err := compute.New(client)
  for _, project := range projects {
    zoneListCall := computeService.Zones.List(project)
    zoneList, err := zoneListCall.Do()
    if err != nil {
      fmt.Println("Error", err)
    } else {
      for _, zone := range zoneList.Items {
        r := strings.Split(zone.Region, "/")
        instanceListCall := computeService.Instances.List(project, zone.Name)
        instanceListCall.Filter(strings.Join(filters[:], " "))
        instanceList, err := instanceListCall.Do()
        if err != nil {
          fmt.Println("Error", err)
        } else {
          for _, instance := range instanceList.Items {
            if workerType, isWorker := instance.Labels["worker-type"]; isWorker {
              m := strings.Split(instance.MachineType, "/")
              fmt.Printf("cloud: gcp, zone: %v, name: %v, instance id: %v, machine type: %v, worker type: %v, launch time: %v",
                zone.Name,
                instance.Name,
                instance.Id,
                m[len(m)-1],
                workerType,
                instance.CreationTimestamp)
              var provisionerId string
              if strings.Contains(workerType, "linux") {
                provisionerId = "gce"
              } else {
                provisionerId = "releng-hardware"
              }
              workerState, err := GetWorkerState(provisionerId, workerType, r[len(r)-1], instance.Name)
              if err != nil {
                fmt.Println("Error", err)
              } else {
                if !workerState.FirstClaim.IsZero() {
                  fmt.Printf(", first claim: %v", workerState.FirstClaim)
                }
                if workerState.RecentTasks != nil && len(workerState.RecentTasks) > 0 {
                  fmt.Printf(", last task: %v/%v",
                    workerState.RecentTasks[len(workerState.RecentTasks)-1].TaskId,
                    workerState.RecentTasks[len(workerState.RecentTasks)-1].RunId)
                }
                fmt.Printf("\n")
              }
            }
          }
        }
      }
    }
  }
}