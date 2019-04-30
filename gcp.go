package main

import (
  "golang.org/x/net/context"
  "google.golang.org/api/compute/v1"
  "golang.org/x/oauth2/google"

  "fmt"
  "strconv"
  "strings"
  "time"
)


func gcpComputeService() (*compute.Service, error) {
  ctx := context.Background()
  client, err := google.DefaultClient(ctx, compute.ComputeScope)
  if err != nil {
    return nil, err
  }
  return compute.New(client)
}

func gcpMachineList(computeService *compute.Service, project string, zone string, filters []string) ([]Machine, error) {
  r := strings.Split(zone, "-")
  region := fmt.Sprintf("%v-%v", r[0], r[1])
  instanceListCall := computeService.Instances.List(project, zone)
  instanceListCall.Filter(strings.Join(filters[:], " "))
  instanceList, err := instanceListCall.Do()
  if err != nil {
    return nil, err
  } else {
    machines := make([]Machine, len(instanceList.Items))
    for i, instance := range instanceList.Items {
      m := strings.Split(instance.MachineType, "/")
      t, _ := time.Parse(time.RFC3339, instance.CreationTimestamp)
      machines[i] = Machine {
        Id: strconv.FormatUint(instance.Id, 10),
        Name: instance.Name,
        Type: m[len(m)-1],
        ImageId: "",
        Cloud: "gcp",
        Zone: zone,
        Region: region,
        Spawned: t,
      }
    }
    return machines, nil
  }
}

func gcpZoneList(computeService *compute.Service, project string) ([]string, error) {
  zoneListCall := computeService.Zones.List(project)
  zoneList, err := zoneListCall.Do()
  if err != nil {
    return nil, err
  } else {
    zones := make([]string, len(zoneList.Items))
    for i, zone := range zoneList.Items {
      zones[i] = zone.Name
    }
    return zones, nil
  }
}