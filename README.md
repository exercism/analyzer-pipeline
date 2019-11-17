

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

## Versioning containers for running

As it currently stands, it's possible to build from an arbitrary git-sha, the 'master' branch, or a tag. Built containers
are referenced by a Docker tag of the form `git-SHA1_OF_GIT_COMMIT` and calling client code can request the version
that a job (e.g. a test run) should run with. It is expected that the orchestration of deciding what container is 'live'
will be external to the router process.

## Building example

To build a container version, submit a message of the form

```json
{
      "action": "build_container",
      "track_slug": "ruby",
      "channel": "test_runners",
      "git_reference": "REF"
}
```

Then, once built, it should be possible to request it to be deployed

```json
{
      "action": "deploy_container_version",
      "track_slug": "ruby",
      "channel": "test_runners",
      "new_version": "git-xxxxxxxxx"
}
```

The deployment may take a little while as each worker is asynchronous, however
within a few seconds it should be possible to then invoke it. e.g.

```json
{
    "action": "test_solution",
    "id": "RUN_IDENTIFIER",
    "track_slug": "ruby",
    "exercise_slug": "two-fer",
    "s3_uri": "s3://path/to/input/files/",
    "container_version": "git-xxxxxxxxx"
}
```

Ruby bindings for a 'pipeline client' are being built for integration
