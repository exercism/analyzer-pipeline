

## Overview

The platform has a single 'router' process and one or more worker processes.

Worker processes come in 4 main flavours

- builder (these can 'build' containers and release them to ECR)
- static-analyser (these run 'x-analyzer' language analyzers)
- recommender (these run 'x-analyzer' language analyzers)
- test-runner (these run 'x-analyzer' language analyzers)

For the latter 3, it's also possible to scope a worker to a particular track. Messages
will be delivered to a track-scoped worker (if available), else to a generic worker
(if available). If no workers are available (either due to scoping, or there not
being any of the suitable type) then a request will error.

## Requirements

- A Linux environment
- The runc and img binaries available
- zeromq native library (and headers) available

## Local running example

To run locally a routing daemon, a generic test runner, and a 'ruby' test runner

First spawn the router. It will need a location for it's configuration file, and
can create a missing file from a 'seed' template. This configuration will be updated
if clients request new container versions to be released.

```
$> bundle exec bin/router /tmp/pipeline.yml --seed config/pipeline.yml --force-worker-restart
```

Next we spawn a generic test-runner. This runner will bootstrap off the router process (which is addressed as an
  argument) and will then prepare all the containers it needs (downloading images as needed from ECR).

Worker state will be maintained in the working directory (here /tmp/envs-w1) which should not be
shared between processes.

```
$> bundle exec bin/worker listen worker-1 tcp://localhost:5555/test_runners /tmp/envs-w1
```

Next we spawn a ruby test-runner. This runner will also bootstrap off the router process but will
only prepare containers required to run ruby tests. It therefore starts quicker on initial bootstrap.
Once up, this worker will take all relevant ruby work on the test_runners channel.

```
$> bundle exec bin/worker listen worker-2 tcp://localhost:5555/test_runners?topic=ruby /tmp/envs-w2
```

The router should load balance, so if we're seeing a lot of ruby traffic, we might want a second worker. E.g.

```
$> bundle exec bin/worker listen worker-3 tcp://localhost:5555/test_runners?topic=ruby /tmp/envs-w3
```
