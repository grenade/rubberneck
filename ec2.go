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
      }
      machines = append(machines, reservationMachines...)
    }
    return machines, nil
  }
}