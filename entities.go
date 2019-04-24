package main

import (
  "time"
)

type Instance struct {
  Machine Machine `json:"machine"`
  Worker Worker `json:"worker"`
  State string `json:"state"`
}

type Machine struct {
  Id string `json:"id"`
  Name string `json:"name"`
  Type string `json:"type"`
  ImageId string `json:"imageId"`
  Cloud string `json:"cloud"`
  Zone string `json:"zone"`
  Region string `json:"region"`
  Spawned time.Time `json:"spawned"`
}

type Worker struct {
  Id string `json:"id"`
  Provisioner string `json:"provisioner"`
  Type string `json:"type"`
  Group string `json:"group"`
  Implementation string `json:"implementation"`
  Expires time.Time `json:"expires"`
  FirstClaim time.Time `json:"firstClaim"`
  Tasks []Task `json:"tasks"`
}

type Task struct {
  Id string `json:"id"`
  Run int `json:"run"`
}