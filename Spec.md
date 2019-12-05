# Initial client spec

## Structure

Basic response format is a status object and a response object. The response can only be relied to be non-null when the overall status was successful (i.e 2xx)

```json
{
  "status": {
    "code": 200,
    "message": "OK"    
  },
  "response": ...
}
```

```json
{
  "status": {
    "code": 504,
    "message": "Timeout"    
  }
}
```

Addtionally addition context may be returned

```json
{
  "status": {
    "code": 200,
    "message": "OK"    
  },
  "response": { "data": "here" },
  "context": {
    "logs": [],
    "exit_status": 0,
    "invocation": {},
    "timing": {}
  }
}
```

For errored requests, the status hash may include additional structured information about the error (both in the status `error` field and also detailed within `context` .

e.g. 

```json
{
  "status": {
    "code": 513,
    "message": "Failure in container invocation",
    "error": {...}    
  },
  "context": {
    "error_detail": {},
    "timing": {}
  }
}
```

## Status codes 

Codes have been chosen to follow HTTP style ranges but fall into 4 broad classes

### Class I - platform routing errors

The platform client (PipelineClient) is currently configured to retry on failure. Generally speaking, it should not retry on 4xx codes, and it's probably not woth retry for 501 and 502.

503 and 504 can be retried with an appropriate backoff

 - 500 generic platform error, ideally not used. 
 - 501 unrecognised action (platform didn't recognise action type)
 - 502 malformed request (message will contain detail)
 - 503 no worker available (there is no worker - either generic or scoped - available to serve your request)
 - 504 request timed out while waiting for a worker to complete

### Class II - Platform worker errors

Unless there is a deployment in progress, it is unlikely that any of these codes will benefit from retry. Two possible exceptions are 512 (which might be due to a recoverable network glitch) and 511 if (and only if) the targeted version is known to have been recently released.

 - 510 generic worker error, ideally unused, but context will be provided in message and potentially in logging
 - 511 container_version unavailable - the requested language:version pair isn't deployed. It may be in future
 - 512 failure in container setup (container not spawned, maybe we're out of disk or s3 transfer failed)
 - 513 failure in container invocation (container exited with non zero code)
 - 514 output missing (container exited with a zero exit - so successfully - but the expected output was not written)


### Class III - Worker Errors (potentially) derived from user input

It is expected that all 4xx error codes are context independent. Repeated submissions will continue to error in the same way, so retrying is pointless.

 - 400 bad input (generic, as yet not used - but we could preliminary scan for vulnerabilities for instance)
 - 401 forced exit due to timeout
 - 402 forced exit due to excessive IO
 - 403 forced exit - other

### Class IV - successful container run

 - 200 ok, successful invocation. There is a value in 'response', it may indicate a successful or failed or errored test run, but the platform considers the test_runner as having completed its work correctly. Data in response is ready for returning to upstream systems.
 
### Class V - Consumer errors

These errors are not sent back by the platform, but are instead are errors if the response from the platform cannot be processed.

- 101 Client Timeout
- 102 Missing response - The response from the platform was nil
- 103 Malformed response - The response from the platform was malformed
