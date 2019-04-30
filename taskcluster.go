package main

import (
  "encoding/json"
  "fmt"
  "io/ioutil"
  "net/http"
  "strings"
  "time"
  "github.com/patrickmn/go-cache"
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

type WorkerTypeState struct {
  Workers []struct {
    WorkerGroup string    `json:"workerGroup"`
    WorkerId    string    `json:"workerId"`
    FirstClaim  time.Time `json:"firstClaim"`
    LatestTask  struct {
      TaskId string `json:"taskId"`
      RunId  int    `json:"runId"`
    } `json:"latestTask"`
  } `json:"workers"`
}

func GetWorkerState(c *cache.Cache, provisionerId string, workerType string, workerGroup string, workerId string) (*WorkerState, error) {
  if provisionerId == "gce" && strings.Contains(workerType, "linux") {
    workerTypeEndpoint := fmt.Sprintf("https://queue.taskcluster.net/v1/provisioners/%v/worker-types/%v/workers",
      provisionerId,
      workerType,
    )
    var workerTypeState WorkerTypeState
    x, cached := c.Get(workerTypeEndpoint)
    if cached {
      workerTypeState = x.(WorkerTypeState)
    } else {
      response, err := http.Get(workerTypeEndpoint)
      if err != nil {
        return nil, err
      } else {
        
        data, _ := ioutil.ReadAll(response.Body)
        err := json.Unmarshal(data, &workerTypeState)
        if err != nil {
          return nil, err
        }
        c.Set(workerTypeEndpoint, workerTypeState, cache.DefaultExpiration)
      }
    }
    for i := range workerTypeState.Workers {
      if strings.HasPrefix(workerTypeState.Workers[i].WorkerId, workerId[0:len(workerId)-4]) {
        workerId = workerTypeState.Workers[i].WorkerId
        break
      }
    }
  }
  endpoint := fmt.Sprintf("https://queue.taskcluster.net/v1/provisioners/%v/worker-types/%v/workers/%v/%v",
    provisionerId,
    workerType,
    workerGroup,
    workerId,
  )
  response, err := http.Get(endpoint)
  if err != nil {
    return nil, err
  } else {
    var workerState WorkerState
    data, _ := ioutil.ReadAll(response.Body)
    err := json.Unmarshal(data, &workerState)
    if err != nil {
      return nil, err
    }
    return &workerState, nil
  }
}