import React, { Component } from 'react';
import WorkerTypeCounts from './components/workerTypeCounts';
//import './App.css';

class App extends Component {
  componentDidMount() {
    this.fetch('https://raw.githubusercontent.com/grenade/rubberneck/observe/worker-type-counts.json')
    .then(res => res.json())
    .then((data) => {
      this.setState({ workerTypeCounts: data })
    })
    .catch(console.log)
  }
  render () {
    return (
      <WorkerTypeCounts workerTypeCounts={this.state.workerTypeCounts} />
    );
  }
}

export default App;
