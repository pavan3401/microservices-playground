# Jenkins Job DSL Configuration for your Application


## File structure

pipeline
    ├── jobs                    # DSL/Workflow script files
    ├── resources               # resources for DSL scripts (templates and bash scripts)
    ├── src
    │   ├── main
    │   │   ├── groovy          # support classes
    │   │   └── resources
    │   │       └── idea.gdsl   # IDE support for IDEA
    │   └── test
    │       └── groovy          # specs
    └── build.gradle            # build file

# Jobs

* (jobs/Infrastructure.groovy)   - Workflow pipeline to build the infrastructure in AWS, creating VPC, Subnet, ELB, ECS cluster.
* (jobs/WeatherServvice.groovy)  - Workflow pipeline to build and deploy the WeatherService in microservice-test environment on AWS
* (jobs/seed.dsl)                - JobDsl seed job to be upload on Jenkins to setup automatically the jobs
* (jobs/set-up-jobs.dsl)         - Definitions of the JobDsl jobs (pipelines skeleton)

## Testing

`./gradlew test` runs the specs.

[JobScriptsSpec](src/test/groovy/com/dslexample/JobScriptsSpec.groovy) 
will loop through all DSL files and make sure they don't throw any exceptions when processed.

## Debug XML 

`./gradlew debugXml -Dpattern=jobs/*.dsl` runs the DSL and writes the XML output to files to `build/debug-xml`.

This can be useful if you want to inspect the generated XML before check-in.

## Seed Job

You can create the example seed job via the Rest API Runner (** Recommended way ** see below) using the pattern `jobs/seed.dsl`.
Or manually create a job with the same structure:

* Invoke Gradle script → Use Gradle Wrapper: `true`
* Process Job DSLs → DSL Scripts: `pipeline/jobs/set-up-jobs.dsl`
* Process Job DSLs → Additional classpath: `src/main/groovy`

## REST API Runner

A gradle task is configured that can be used to create/update jobs via the Jenkins REST API, if desired. Normally
a seed job is used to keep jobs in sync with the DSL. This is the recommended way to upload the seed job
on the Jenkins server.

```./gradlew rest -Dpattern=<pattern> -DbaseUrl=<baseUrl> [-Dusername=<username>] [-Dpassword=<password>]```

* `pattern` - ant-style path pattern of files to include
* `baseUrl` - base URL of Jenkins server
* `username` - Jenkins username, if secured
* `password` - Jenkins password or token, if secured

### (Example):
```./gradlew rest -Dpattern=jobs/seed.dsl -DbaseUrl=http://microservices-jenkins.goe3.ca/ [-Dusername=<username>] [-Dpassword=<password>]```