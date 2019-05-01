import React from 'react'

const WorkerTypeCounts = ({ workerTypeCounts }) => {
  return (
    <div>
      <center><h1>Worker Type List</h1></center>
      {Object.keys(workerTypeCounts).map((workerType) => (
        <div class="card">
          <div class="card-body">
            <h5 class="card-title">{workerType}</h5>
            <h6 class="card-subtitle mb-2 text-muted">blah, blah</h6>
            <p class="card-text">blah</p>
            <dl>
              <dt>pending</dt>
              <dd>{workerTypeCounts[workerType].pending}</dd>
              <dt>waiting</dt>
              <dd>{workerTypeCounts[workerType].waiting}</dd>
              <dt>working</dt>
              <dd>{workerTypeCounts[workerType].working}</dd>
            </dl>
          </div>
        </div>
      ))}
    </div>
  )
};

export default WorkerTypeCounts