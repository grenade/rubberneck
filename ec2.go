package main

import (
  "github.com/aws/aws-sdk-go/aws"
  "github.com/aws/aws-sdk-go/aws/session"
  "github.com/aws/aws-sdk-go/service/ec2"
)

func ec2InstanceList(region string, filters []*ec2.Filter) ([]Machine, error) {
  sess := session.Must(session.NewSessionWithOptions(session.Options{
    SharedConfigState: session.SharedConfigEnable,
    Config: aws.Config { Region: aws.String(region) },
  }))
  ec2Svc := ec2.New(sess)
  input := &ec2.DescribeInstancesInput { Filters: filters }
  result, err := ec2Svc.DescribeInstances(input)
  if err != nil {
    return nil, err
  } else {
    machines := make([]Machine, 0)
    //fmt.Println("Success", result)
    for _, reservation := range result.Reservations {
      reservationMachines := make([]Machine, len(reservation.Instances))
      for i, instance := range reservation.Instances {
        reservationMachines[i] = Machine {
          Id: *instance.InstanceId,
          Name: *instance.InstanceId,
          Type: *instance.InstanceType,
          ImageId: *instance.ImageId,
          Cloud: "ec2",
          Zone: *instance.Placement.AvailabilityZone,
          Region: region,
          Spawned: *instance.LaunchTime,
        }
        /*var workerType string
        for _, tag := range instance.Tags {
          if *tag.Key == "Name" {
            workerType = *tag.Value
            break
          }
        }
        fmt.Printf("cloud: ec2, az: %v, instance id: %v, instance type: %v, worker type: %v, image id: %v, launch time: %v",
          *instance.Placement.AvailabilityZone,
          *instance.InstanceId,
          *instance.InstanceType,
          workerType,
          *instance.ImageId,
          *instance.LaunchTime)
        workerState, err := GetWorkerState("aws-provisioner-v1", workerType, *region, *instance.InstanceId)
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
        */
      }
      machines = append(machines, reservationMachines...)
    }
    return machines, nil
  }
}