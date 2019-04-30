package main

import (
  "github.com/aws/aws-sdk-go/aws"
  "github.com/aws/aws-sdk-go/service/ec2"
)

var observationRepository string = "git@github.com:grenade/rubberneck.git"
var observationBranch string = "observe"
var observationAuthorName string = "Rob Thijssen"
var observationAuthorEmail string = "rthijssen@gmail.com"

var gcpProjects = []string {
  "windows-workers",
}

var gcpFilters = []string {
  "status = RUNNING",
}

var gcpWorkerTypes = []string {
  "gecko-1-b-linux",
  "gecko-2-b-linux",
  "gecko-3-b-linux",

  "gecko-1-b-win2012-gamma",
  "gecko-2-b-win2012-gamma",
  "gecko-3-b-win2012-gamma",
}

// todo: get regions from provisioner config
var ec2Regions = []string {
  "us-east-1",
  "us-east-2",
  "us-west-1",
  "us-west-2",
  "eu-central-1",
}

// todo: get worker-types from provisioner config
var ec2WorkerTypes = []string {
  "gecko-1-b-android",
  "gecko-2-b-android",
  "gecko-3-b-android",

  "gecko-1-b-linux",
  "gecko-1-b-linux-large",
  "gecko-1-b-linux-xlarge",
  "gecko-2-b-linux",
  "gecko-2-b-linux-large",
  "gecko-2-b-linux-xlarge",
  "gecko-3-b-linux",
  "gecko-3-b-linux-large",
  "gecko-3-b-linux-xlarge",

  "gecko-1-b-macosx64",
  "gecko-2-b-macosx64",
  "gecko-3-b-macosx64",

  "gecko-1-b-win2012",
  "gecko-1-b-win2012-beta",
  "gecko-2-b-win2012",
  "gecko-3-b-win2012",
  "gecko-3-b-win2012-c4",
  "gecko-3-b-win2012-c5",

  "gecko-t-win10-64",
  "gecko-t-win10-64-alpha",
  "gecko-t-win10-64-beta",
  "gecko-t-win10-64-cu",
  "gecko-t-win10-64-gpu",
  "gecko-t-win10-64-gpu-a",
  "gecko-t-win10-64-gpu-b",

  "gecko-t-win7-32",
  "gecko-t-win7-32-beta",
  "gecko-t-win7-32-cu",
  "gecko-t-win7-32-gpu",
  "gecko-t-win7-32-gpu-b",

  "relops-image-builder",
}


var ec2Filters = []*ec2.Filter {
  {
    Name: aws.String("instance-lifecycle"),
    Values: []*string{
      aws.String("spot"),
    },
  },
}