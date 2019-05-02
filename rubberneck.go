package main

import (
  "encoding/json"
  "fmt"
  "io/ioutil"
  "net/http"
  "os"
  "path"
  "path/filepath"
  "strings"
  "sync"
  "time"
  "github.com/aws/aws-sdk-go/aws"
  "github.com/aws/aws-sdk-go/service/ec2"
  "github.com/patrickmn/go-cache"
  "gopkg.in/src-d/go-git.v4"
  "gopkg.in/src-d/go-git.v4/plumbing"
  "gopkg.in/src-d/go-git.v4/plumbing/object"
)

func main() {
  c := cache.New(5*time.Minute, 10*time.Minute)

  observationDirectory, err := ioutil.TempDir("", fmt.Sprintf("rubberneck-git-%v", observationBranch))
  if err != nil {
    fmt.Println("error:", err)
  }
  defer os.RemoveAll(observationDirectory)
  r, err := git.PlainClone(observationDirectory, false, &git.CloneOptions{
    URL: observationRepository,
    ReferenceName: plumbing.NewBranchReferenceName(observationBranch),
    SingleBranch: true,
  })
  if err != nil {
    fmt.Println("clone error:", err)
  }
  ref, err := r.Head()
  if err != nil {
    fmt.Println("head error:", err)
  }
  fmt.Println(ref.Hash())
  w, err := r.Worktree()
  if err != nil {
    fmt.Println("worktree error:", err)
  }
  files, err := filepath.Glob(fmt.Sprintf("%v/**/*.json", observationDirectory))
  if err != nil {
    fmt.Println("json files glob error:", err)
  }
  for _, f := range files {
    if err := os.Remove(f); err != nil {
      fmt.Println("error:", err)
    }
  }

  instances := make([]Instance, 0)
  var cloudWaitGroup sync.WaitGroup
  cloudWaitGroup.Add(2)
  go func() {
    defer cloudWaitGroup.Done()
    computeService, err := gcpComputeService()
    if err != nil {
      return
    }
    var projectWaitGroup sync.WaitGroup
    projectWaitGroup.Add(len(gcpProjects))
    for projectIndex, _ := range gcpProjects {
      go func(projectIndex int) {
        defer projectWaitGroup.Done()
        var workerTypeWaitGroup sync.WaitGroup
        workerTypeWaitGroup.Add(len(gcpWorkerTypes))
        for workerTypeIndex, _ := range gcpWorkerTypes {
          gcpZones, err := gcpZoneList(computeService, gcpProjects[projectIndex])
          if err != nil {
            fmt.Println("error:", err)
          } else {
            go func(workerTypeIndex int) {
              defer workerTypeWaitGroup.Done()
              var zoneWaitGroup sync.WaitGroup
              zoneWaitGroup.Add(len(gcpZones))
              for zoneIndex, _ := range gcpZones {
                go func(zoneIndex int) {
                  defer zoneWaitGroup.Done()
                  machines, err := gcpMachineList(computeService, gcpProjects[projectIndex], gcpZones[zoneIndex], append(gcpFilters, fmt.Sprintf("labels.worker-type = %v", gcpWorkerTypes[workerTypeIndex])))
                  if err != nil {
                    fmt.Println(fmt.Sprintf("error retrieving %v machine list for gcp %v in zone %v", gcpWorkerTypes[workerTypeIndex], gcpProjects[projectIndex], gcpZones[zoneIndex]), err)
                  } else {
                    //fmt.Printf("%v machine count for gcp %v in zone %v is: %v\n", gcpWorkerTypes[workerTypeIndex], gcpProjects[projectIndex], gcpZones[zoneIndex], len(machines))
                    var machineWaitGroup sync.WaitGroup
                    machineWaitGroup.Add(len(machines))
                    for machineIndex, _ := range machines {
                      go func(machineIndex int) {
                        defer machineWaitGroup.Done()
                        instance, _ := ObserveInstance(c, machines[machineIndex], gcpWorkerTypes[workerTypeIndex], observationDirectory)
                        if (instance.Worker.FirstClaim.IsZero()) {
                          instanceRevision, err := GetInstanceRevision(ref.Hash(), instance.Worker.Type, instance.Worker.Id)
                          if err == nil && !instanceRevision.Worker.FirstClaim.IsZero() {
                            jsonInstance, err := json.MarshalIndent(instanceRevision, "", "  ")
                            if err != nil {
                              fmt.Println("json marshall indent error:", err)
                            } else {
                              jsonFile := path.Join(observationDirectory, instance.Worker.Type, fmt.Sprintf("%v.json", instance.Worker.Id))
                              err = ioutil.WriteFile(jsonFile, jsonInstance, 0644)
                              if err != nil {
                                fmt.Println("file write error:", err)
                              } else {
                                instance = instanceRevision
                              }
                            }
                          }
                        }
                        instances = append(instances, instance)
                      }(machineIndex)
                    }
                    machineWaitGroup.Wait()
                  }
                }(zoneIndex)
              }
              zoneWaitGroup.Wait()
            }(workerTypeIndex)
            if stat, err := os.Stat(path.Join(observationDirectory, gcpWorkerTypes[workerTypeIndex])); err == nil && stat.IsDir() {
              _, err = w.Add(gcpWorkerTypes[workerTypeIndex])
              if err != nil {
                fmt.Println("git add error:", observationDirectory, gcpWorkerTypes[workerTypeIndex], err)
              }
            }
          }
        }
        workerTypeWaitGroup.Wait()
      }(projectIndex)
    }
    projectWaitGroup.Wait()
  }()
  go func() {
    defer cloudWaitGroup.Done()
    var workerTypeWaitGroup sync.WaitGroup
    workerTypeWaitGroup.Add(len(ec2WorkerTypes))
    for workerTypeIndex, _ := range ec2WorkerTypes {
      go func(workerTypeIndex int) {
        defer workerTypeWaitGroup.Done()
        var regionWaitGroup sync.WaitGroup
        regionWaitGroup.Add(len(ec2Regions))
        for regionIndex, _ := range ec2Regions {
          go func(regionIndex int) {
            defer regionWaitGroup.Done()
            machines, err := ec2InstanceList(ec2Regions[regionIndex], append(ec2Filters, &ec2.Filter { Name: aws.String("tag:Name"), Values: []*string{aws.String(ec2WorkerTypes[workerTypeIndex])}}))
            if err != nil {
              fmt.Println(fmt.Sprintf("error retrieving %v machine list for ec2 in region %v", ec2WorkerTypes[workerTypeIndex], ec2Regions[regionIndex]), err)
            } else {
              //fmt.Printf("%v machine count for ec2 in region %v is: %v\n", ec2WorkerTypes[workerTypeIndex], ec2Regions[regionIndex], len(machines))
              var machineWaitGroup sync.WaitGroup
              machineWaitGroup.Add(len(machines))
              for machineIndex, _ := range machines {
                go func(machineIndex int) {
                  defer machineWaitGroup.Done()
                  instance, _ := ObserveInstance(c, machines[machineIndex], ec2WorkerTypes[workerTypeIndex], observationDirectory)
                  if (instance.Worker.FirstClaim.IsZero()) {
                    instanceRevision, err := GetInstanceRevision(ref.Hash(), instance.Worker.Type, instance.Worker.Id)
                    if err == nil && !instanceRevision.Worker.FirstClaim.IsZero() {
                      jsonInstance, err := json.MarshalIndent(instanceRevision, "", "  ")
                      if err != nil {
                        fmt.Println("json marshall indent error:", err)
                      } else {
                        jsonFile := path.Join(observationDirectory, instance.Worker.Type, fmt.Sprintf("%v.json", instance.Worker.Id))
                        err = ioutil.WriteFile(jsonFile, jsonInstance, 0644)
                        if err != nil {
                          fmt.Println("file write error:", err)
                        } else {
                          instance = instanceRevision
                        }
                      }
                    }
                  }
                  instances = append(instances, instance)
                }(machineIndex)
              }
              machineWaitGroup.Wait()
            }
          }(regionIndex)
        }
        regionWaitGroup.Wait()
      }(workerTypeIndex)
      if stat, err := os.Stat(path.Join(observationDirectory, ec2WorkerTypes[workerTypeIndex])); err == nil && stat.IsDir() {
        _, err = w.Add(ec2WorkerTypes[workerTypeIndex])
        if err != nil {
          fmt.Println("git add error:", observationDirectory, ec2WorkerTypes[workerTypeIndex], err)
        }
      }
    }
    workerTypeWaitGroup.Wait()
  }()
  cloudWaitGroup.Wait()

  m := make(map[string]map[string]int)
  for i := range instances {
    if (m[instances[i].Worker.Type] == nil) {
      m[instances[i].Worker.Type] = make(map[string]int)
      m[instances[i].Worker.Type]["pending"] = 0
      m[instances[i].Worker.Type]["waiting"] = 0
      m[instances[i].Worker.Type]["working"] = 0
      pendingTaskCount, _ := GetPendingTaskCount(instances[i].Worker.Provisioner, instances[i].Worker.Type)
      m[instances[i].Worker.Type]["tasks"] = pendingTaskCount
    }
    m[instances[i].Worker.Type]["running"] = m[instances[i].Worker.Type]["running"] + 1
    if (instances[i].State != "") {
      m[instances[i].Worker.Type][instances[i].State] = m[instances[i].Worker.Type][instances[i].State] + 1
    }
  }
  fm, err := json.MarshalIndent(m, "", "  ")
  if err != nil {
    fmt.Println("json marshall indent error:", err)
  }
  fmt.Println(string(fm))
  err = ioutil.WriteFile(path.Join(observationDirectory, "worker-type-counts.json"), fm, 0644)
  if err != nil {
    fmt.Println("file write error:", err)
  }
  _, err = w.Add(".")
  if err != nil {
    fmt.Println("git add error:", err)
  }
  statii, err := w.Status()
  if err != nil {
    fmt.Println("read git status error:", err)
  }
  for path, status := range statii {
    if ((status.Worktree == git.Deleted) && (status.Staging == git.Unmodified)) {
      _, err = w.Remove(path)
      if err != nil {
        fmt.Println("git remove error:", err)
      }
    }
    //buf := bytes.NewBuffer(nil)
    //fmt.Fprintf(buf, "%c%c %s", status.Staging, status.Worktree, path)
    //fmt.Println(buf.String())
  }
  
  commit, err := w.Commit("updated worker-type counts", &git.CommitOptions{
    Author: &object.Signature{
      Name:  observationAuthorName,
      Email: observationAuthorEmail,
      When:  time.Now(),
    },
  })
  if err != nil {
    fmt.Println("git commit error:", err)
  }
  obj, err := r.CommitObject(commit)
  if err != nil {
    fmt.Println("read git commit error:", err)
  }
  fmt.Println(obj)
  err = r.Push(&git.PushOptions{})
  if err != nil {
    fmt.Println("git push error:", err)
  }
  /*fileList, err := ioutil.ReadDir(observationDirectory)
  if err != nil {
    fmt.Println("read dir error:", err)
  }
  for _, f := range fileList {
    fmt.Println(path.Join(observationDirectory, f.Name()))
  }*/
}

func RemoveContents(dir string) error {
  d, err := os.Open(dir)
  if err != nil {
    return err
  }
  defer d.Close()
  names, err := d.Readdirnames(-1)
  if err != nil {
    return err
  }
  for _, name := range names {
    err = os.RemoveAll(filepath.Join(dir, name))
    if err != nil {
      return err
    }
  }
  return nil
}

func ObserveInstance(c *cache.Cache, machine Machine, workerType string, observationDirectory string) (Instance, error) {
  instance := Instance {
    Machine: machine,
    Worker: Worker {
      Id: func() string {
        if (machine.Cloud == "gcp") {
          if strings.Contains(workerType, "linux") {
            return machine.Id
          } else {
            return machine.Name
          }
        } else if machine.Cloud == "ec2" {
          return machine.Name
        } else {
          return ""
        }
      }(),
      Provisioner: func() string {
        if (machine.Cloud == "gcp") {
          if strings.Contains(workerType, "linux") {
            return "gce"
          } else {
            return "releng-hardware"
          }
        } else if machine.Cloud == "ec2" {
          return "aws-provisioner-v1"
        } else {
          return ""
        }
      }(),
      Type: workerType,
      Group: func() string {
        if (machine.Cloud == "gcp") {
          if strings.Contains(workerType, "linux") {
            return machine.Zone
          } else {
            return machine.Region
          }
        } else if machine.Cloud == "ec2" {
          return machine.Region
        } else {
          return ""
        }
      }(),
      Implementation: func() string {
        if (machine.Cloud == "gcp") {
          if strings.Contains(workerType, "linux") {
            return "docker-worker"
          } else {
            return "generic-worker"
          }
        } else if machine.Cloud == "ec2" {
          if strings.Contains(workerType, "win") {
            return "generic-worker"
          } else {
            return "docker-worker"
          }
        } else {
          return ""
        }
      }(),
    },
  }
  message := fmt.Sprintf("cloud: %v, zone: %v, name: %v, instance: %v, machine: %v, worker: %v/%v/%v, created: %v",
    instance.Machine.Cloud,
    instance.Machine.Zone,
    instance.Machine.Name,
    instance.Machine.Id,
    instance.Machine.Type,
    instance.Worker.Type,
    instance.Worker.Group,
    instance.Worker.Id,
    instance.Machine.Spawned)
  workerState, err := GetWorkerState(c, instance.Worker.Provisioner, instance.Worker.Type, instance.Worker.Group, instance.Worker.Id)
  if err != nil {
    fmt.Println("error", err)
  } else {
    if workerState.FirstClaim.IsZero() {
      instance.State = "pending"
    } else {
      instance.Worker.FirstClaim = workerState.FirstClaim
      instance.State = "waiting"
      message = message + fmt.Sprintf(", first claim: %v", instance.Worker.FirstClaim)
    }
    if workerState.RecentTasks != nil && len(workerState.RecentTasks) > 0 {
      tasks := make([]Task, 0)
      for _, task := range workerState.RecentTasks {
        tasks = append(tasks, Task { Id: task.TaskId, Run: task.RunId })
      }
      instance.Worker.Tasks = tasks
      instance.State = "working"
      message = message + fmt.Sprintf(", last task: %v/%v", instance.Worker.Tasks[len(instance.Worker.Tasks) - 1].Id, instance.Worker.Tasks[len(instance.Worker.Tasks) - 1].Run)
    }
  }
  fmt.Println(message)
  jsonInstance, err := json.MarshalIndent(instance, "", "  ")
  if err != nil {
    fmt.Println("json marshall indent error:", err)
  }
  os.MkdirAll(path.Join(observationDirectory, instance.Worker.Type), os.ModePerm)
  jsonFile := path.Join(observationDirectory, instance.Worker.Type, fmt.Sprintf("%v.json", instance.Worker.Id))
  err = ioutil.WriteFile(jsonFile, jsonInstance, 0644)
  if err != nil {
    fmt.Println("file write error:", err)
  }
  return instance, nil
}

func GetInstanceRevision(sha plumbing.Hash, workerType string, workerId string) (Instance, error) {
  endpoint := fmt.Sprintf("https://raw.githubusercontent.com/grenade/rubberneck/%v/%v/%v.json",
    sha,
    workerType,
    workerId,
  )
  var instance Instance
  response, err := http.Get(endpoint)
  if err != nil {
    return instance, err
  } else {
    
    data, _ := ioutil.ReadAll(response.Body)
    err := json.Unmarshal(data, &instance)
    if err != nil {
      return instance, err
    }
    return instance, nil
  }
}
