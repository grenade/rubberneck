import React, { Component } from 'react';
import WorkerTypeCounts from './components/workerTypeCounts';

import './App.css';
import { library } from '@fortawesome/fontawesome-svg-core'
import { faDesktop, faRecycle, faWrench, faPowerOff, faClock, faServer, faTasks, faClipboardCheck, faHammer } from '@fortawesome/free-solid-svg-icons'
import { faAndroid, faApple, faLinux, faWindows } from '@fortawesome/free-brands-svg-icons'

library.add(
  faHammer,
  faClipboardCheck,
  faTasks,
  faServer,
  faClock,
  faDesktop,
  faRecycle,
  faWrench,
  faPowerOff,
  faAndroid,
  faApple,
  faLinux,
  faWindows
)

class App extends Component {
  constructor() {
    super();
    this.state = {
      workerTypeCounts: {}
    };
    fetch('https://raw.githubusercontent.com/grenade/rubberneck/observe/worker-type-counts.json')
    .then(res => res.json())
    .then((data) => {
      this.setState({ workerTypeCounts: data })
    })
    .catch(console.log);
  }
  render () {
    return (
      <WorkerTypeCounts workerTypeCounts={this.state.workerTypeCounts} />
    );
  }
}

export default App;
