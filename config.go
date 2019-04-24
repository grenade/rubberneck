package main

var gcpProjects = []string{
  "windows-workers",
}

var gcpFilters = []string{
  "status = RUNNING",
}

var gcpWorkerTypes = []string{
  "gecko-1-b-linux",
  "gecko-2-b-linux",
  "gecko-3-b-linux",
  "gecko-1-b-win2012-gamma",
  "gecko-2-b-win2012-gamma",
  "gecko-3-b-win2012-gamma",
}