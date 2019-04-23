package main

import (
  //"bytes"
  "encoding/json"
  "fmt"
  "io/ioutil"
  "net/http"
  "time"
  //"strings"
)

type WorkerState struct {
  WorkerType    string `json:"workerType"`
  ProvisionerId string `json:"provisionerId"`
  WorkerId      string `json:"workerId"`
  WorkerGroup   string `json:"workerGroup"`
  RecentTasks   []struct {
    TaskId string `json:"taskId"`
    RunId  int    `json:"runId"`
  } `json:"recentTasks"`
  Expires    time.Time `json:"expires"`
  FirstClaim time.Time `json:"firstClaim"`
  Actions    []struct {
    Name        string `json:"name"`
    Title       string `json:"title"`
    Context     string `json:"context"`
    URL         string `json:"url"`
    Method      string `json:"method"`
    Description string `json:"description"`
  } `json:"actions"`
}

func GetWorkerState(provisionerId string, workerType string, workerGroup string, workerId string) (*WorkerState, error) {
  endpoint := fmt.Sprintf("https://queue.taskcluster.net/v1/provisioners/%v/worker-types/%v/workers/%v/%v",
    provisionerId,
    workerType,
    workerGroup,
    workerId,
  )
  response, err := http.Get(endpoint)
  var workerState WorkerState
  if err != nil {
    return nil, err
  } else {
    data, _ := ioutil.ReadAll(response.Body)
    err := json.Unmarshal(data, &workerState)
    if err != nil {
      return nil, err
    }
  }
  return &workerState, nil
}