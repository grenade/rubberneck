package main

import (
  "github.com/aws/aws-sdk-go/aws"
  "github.com/aws/aws-sdk-go/aws/session"
  "github.com/aws/aws-sdk-go/service/ec2"

  "fmt"
)

func AwsEc2() {

  regions := []*string{
    aws.String("us-east-1"),
    aws.String("us-east-2"),
    aws.String("us-west-1"),
    aws.String("us-west-2"),
    aws.String("eu-central-1"),
  }

  // todo: get worker-types from provisioner config
  workerTypes := []*string{
    aws.String("gecko-1-b-win2012"),
    aws.String("gecko-1-b-win2012-beta"),
    aws.String("gecko-2-b-win2012"),
    aws.String("gecko-3-b-win2012"),

    aws.String("gecko-t-win10-64"),
    aws.String("gecko-t-win10-64-gpu"),
    aws.String("gecko-t-win10-64-beta"),
    aws.String("gecko-t-win10-64-gpu-b"),

    aws.String("gecko-t-win17-32"),
    aws.String("gecko-t-win17-32-gpu"),
    aws.String("gecko-t-win17-32-beta"),
    aws.String("gecko-t-win17-32-gpu-b"),

    aws.String("gecko-1-b-linux"),
    aws.String("gecko-2-b-linux"),
    aws.String("gecko-3-b-linux"),
  }

  for _, region := range regions {
    sess := session.Must(session.NewSessionWithOptions(session.Options{
      SharedConfigState: session.SharedConfigEnable,
      Config: aws.Config{Region: region},
    }))
    ec2Svc := ec2.New(sess)

    input := &ec2.DescribeInstancesInput{
      Filters: []*ec2.Filter{
        {
          Name: aws.String("tag:Name"),
          Values: workerTypes,
        },
        {
          Name: aws.String("instance-lifecycle"),
          Values: []*string{
            aws.String("spot"),
          },
        },
      },
    }
    result, err := ec2Svc.DescribeInstances(input)
    if err != nil {
      fmt.Println("Error", err)
    } else {
      //fmt.Println("Success", result)
      for _, reservation := range result.Reservations {
        for _, instance := range reservation.Instances {
          var workerType string
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
        }
      }
    }
  }
}