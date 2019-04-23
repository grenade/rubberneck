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
        instanceListCall := computeService.Instances.List(project, zone.Name)
        instanceList, err := instanceListCall.Do()
        if err != nil {
          fmt.Println("Error", err)
        } else {
          for _, instance := range instanceList.Items {
            if workerType, isWorker := instance.Labels["worker-type"]; isWorker {
              m := strings.Split(instance.MachineType, "/")
              fmt.Printf("cloud: gcp, zone: %v, name: %v, instance id: %v, machine type: %v, worker type: %v, launch time: %v\n",
                zone.Name,
                instance.Name,
                instance.Id,
                m[len(m)-1],
                workerType,
                instance.CreationTimestamp)
            }
          }
        }
      }
    }
  }
}