import React from 'react'
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome'
import ProgressBar from 'react-bootstrap/ProgressBar';

const WorkerTypeCounts = ({ workerTypeCounts }) => {
  return (
    <div className="container-fluid">
      <div className="row">
        <button type="button" className="btn btn-outline-secondary">
          <FontAwesomeIcon icon={['fab', 'apple']} />
        </button>
        <button type="button" className="btn btn-outline-secondary">
          <FontAwesomeIcon icon={['fab', 'android']} />
        </button>
        <button type="button" className="btn btn-outline-secondary">
          <FontAwesomeIcon icon={['fab', 'linux']} />
        </button>
        <button type="button" className="btn btn-outline-secondary">
          <FontAwesomeIcon icon={['fab', 'windows']} />
        </button>
      </div>
      {
        ['android', 'osx', 'linux', 'win'].map((os, osIndex) => (
          ['-b-', '-t-'].map((kind, kindIndex) => (
            <div className="row" key={osIndex + '-' + kindIndex}>
              <div className="card">
                <div className="card-body">
                  <span>
                    {
                      os === 'osx'
                        ? (<FontAwesomeIcon icon={['fab', 'apple']} />)
                        : os === 'linux'
                          ? (<FontAwesomeIcon icon={['fab', 'linux']} />)
                          : os === 'win'
                            ? (<FontAwesomeIcon icon={['fab', 'windows']} />)
                            : os === 'android'
                              ? (<FontAwesomeIcon icon={['fab', 'android']} />)
                              : (<FontAwesomeIcon icon={['fas', 'desktop']} />)
                    }
                    <br />
                    {
                      kind === '-t-'
                        ? (<FontAwesomeIcon icon={['fas', 'clipboard-check']} />)
                        : (<FontAwesomeIcon icon={['fas', 'hammer']} />)
                    }
                  </span>
                </div>
              </div>
              {
                Object.keys(workerTypeCounts).filter(workerType => { return workerType.includes(os) && workerType.includes(kind); }).map((workerType, workerTypeIndex) => (
                  <div className="card" key={workerTypeIndex}>
                    <div className="card-body">
                      <center>
                        <h3 className="card-title">
                          {
                            workerType.includes("osx")
                              ? (<FontAwesomeIcon icon={['fab', 'apple']} />)
                              : workerType.includes("linux")
                                ? (<FontAwesomeIcon icon={['fab', 'linux']} />)
                                : workerType.includes("win")
                                  ? (<FontAwesomeIcon icon={['fab', 'windows']} />)
                                  : workerType.includes("android")
                                    ? (<FontAwesomeIcon icon={['fab', 'android']} />)
                                    : (<FontAwesomeIcon icon={['fas', 'desktop']} />)
                          }
                        </h3>
                      </center>
                      <h5 className="card-title">
                        {workerType}
                      </h5>
                      <hr />
                      <h6 className="card-title">
                        <FontAwesomeIcon className="text-muted" icon={['fas', 'server']} />
                        instances
                      </h6>
                      <p className="card-text">
                        <FontAwesomeIcon className="text-muted" icon={['fas', 'power-off']} />
                        pending: {workerTypeCounts[workerType].pending}<br />

                        <FontAwesomeIcon className="text-muted" icon={['fas', 'recycle']} />
                        waiting: {workerTypeCounts[workerType].waiting}<br />

                        <FontAwesomeIcon className="text-muted" icon={['fas', 'wrench']} />
                        working: {workerTypeCounts[workerType].working}
                      </p>
                      <ProgressBar>
                        <ProgressBar striped variant="success" now={workerTypeCounts[workerType].working / workerTypeCounts[workerType].running * 100} key={1} />
                        <ProgressBar variant="warning" now={workerTypeCounts[workerType].waiting / workerTypeCounts[workerType].running * 100} key={2} />
                        <ProgressBar striped variant="danger" now={workerTypeCounts[workerType].pending / workerTypeCounts[workerType].running * 100} key={3} />
                      </ProgressBar>
                      <hr />
                      <h6 className="card-title">
                        <FontAwesomeIcon className="text-muted" icon={['fas', 'tasks']} />
                        tasks
                      </h6>
                      <p className="card-text">
                        <FontAwesomeIcon className="text-muted" icon={['fas', 'clock']} />
                        pending: {workerTypeCounts[workerType].tasks}
                      </p>
                    </div>
                  </div>
                ))
              }
            </div>
          ))
        ))
      }
    </div>
  )
};

export default WorkerTypeCounts