
Scripts in this directory help to run/test RHTAP pipeline.

### Prerequisits

1. `Red Hat OpenShift Pipelines` operator installed
2. `Advanced Cluster Security for Kubernetes` operator installed and configured:
    1. In Openshift console go to `Operators` -> `Installed Operators` and select `Advanced Cluster Security for Kubernetes`. Under `Details` tab, in `Provided API` section create `Central` instance.
    2. Get ACS password:
    ```
    oc -n rhacs-operator get secret central-htpasswd -o go-template='{{index .data "password" | base64decode}}'
    ```
    3. Find `Route` named `central` in `rhacs-operator` namespace and open it.
    Login with `admin` and password obtained in the previous step.
    Note, if the route cannot be open, check `central-db` deployment in `rhacs-operator` namespace.
    One might need to lower CPU and memory usage of the deployment.
    4. In the left sidebar click `Integrations` and scroll to `Authentication Tokens` section. Click `STackRox` `API Token` and `Generate Token` button. Set `rox-api-token` into name and `Continuous Integration` as role. Click `Generate`.
    5. Save the token.

### Preparation

1. Copy `build-config-template.env` as `build-config.env` and set your values.
2. Login into your Openshift cluster.
3. Create a namespace and make it current project:
```
oc create namespace test && oc project test
```
4. Configure cluster and namespace by running `prepare-build-resources.sh` script:
```
./hack/build/prepare-build-resources.sh
```
Note, if you need to run RHTAP pipelines in different namespace, make sure that `provisionNamespace` function from `prepare-build-resources.sh` script was run for each of the namespaces.

### Development

This could be skipped if you don't make changes to the RHTAP pipeline.

1. Make changes into your local build-definitions repository.
2. Configure path to it by exporting `BUILD_DEFINITIONS` environment variable:
```
export BUILD_DEFINITIONS=/path/to/local/build-definitions
```
3. Run `import-build-definitions` script to apply your changes from local build-definitions:
```
./hack/import-build-definitions
```
Alternatively, you can use `update-definitions.sh` script that will also apply the resources in the cluster,
so step 2 in testing section can be skipped.

### Testing RHTAP pipeline

1. Define the following environment variables:
  - `GIT_REPO_URL`
  - `GIT_REVISION`
  - `IMAGE_REPOSITORY`
  - `PIPELINE`

or open `run-build.sh` and set default values according to your use-case to avoid setting all or some environment variables.

2. Apply pipelines and tasks definitions into cluster:
```
oc apply -f ${ROOT_DIR}/pac/tasks
oc apply -f ${ROOT_DIR}/pac/pipelines
```

3. Run `run-build.sh` script:
```
export GIT_REPO_URL=https://github.com/devfile-samples/devfile-sample-go-basic
./hack/build/run-build.sh
```
If you need other parameters for the pipeline run, edit the definition in the script.

4. Check the corresponding `PipelineRun` in your namespace.
