
# Install Docker for Desktop

1. Download [Docker for Desktop for Mac](https://www.docker.com/products/docker-desktop)

2. Install application

3. Enable Kubernetes on Docker Desktop
    - `CMD` +`,` open Preference panel
    - switch to `Kubernetes` tap
    - tick `Enable Kubernetes` and wait for a few minutes

# Install MiniKube (Optional)

With Minikube we can set up and operate a single node Kubernetes cluster as a local development environment. It's optional since we can directly use `docker-desktop` as our local cluster.

Install minikube and kubectl by [Homebrew](https://brew.sh/)

``` shell
brew install minikube kubectl
```

After successful installation, you can start Minikube by executing the following command in your terminal:

``` shell
 minikube start
```

Now Minikube is started and you have created a Kubernetes context called `minikube`, which is set by default during startup. You can switch between contexts using the command:

``` shell
 kubectl config use-context minikube
```

# Build a dotnet core web application

## Create WebApi project

Make sure you have `dotnet` installed on your machine already. (Install dotnet-sdk by [homebrew cask](https://formulae.brew.sh/cask/dotnet-sdk#default))

Create a dotnet api application

```shell
dotnet new webapi --name dotnet-app
```

By default, dotnet cli creates us a `WeatherForecast` web api appliction. Open `Startup.cs` and comment the line which block us accessing on local.

``` C#
// app.UseHttpsRedirection();
```

Run the application and make sure the app running as expected.

``` shell
cd dotnet-app
dotnet run
```

Visit `http://localhost:5000/WeatherForecast` using browser, there you will get a json response.

## Dockerize the dotnet core application

Create a docker image for the `dotnet-app` appliction which we just created. Please note, in this demo, the docker file was put outside the dotnet app directory).

``` shell
touch Dockerfile
```

``` dockerfile
FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build
WORKDIR /app

# copy csproj and restore as distinct layers
# COPY *.sln .
COPY dotnet-app/*.csproj ./dotnet-app/
RUN dotnet restore dotnet-app

# copy everything else and build app
COPY dotnet-app/. ./dotnet-app/
WORKDIR /app/dotnet-app
RUN dotnet publish -c Release -o out


FROM mcr.microsoft.com/dotnet/core/aspnet:3.1 AS runtime
WORKDIR /app
COPY --from=build /app/dotnet-app/out ./
ENTRYPOINT ["dotnet", "dotnet-app.dll"]
```

Build our docker image with the dockerfile.

``` shell
docker build -t dotnet-app .
```

Once then image buit, check the image:

``` shell
docker images
```

You will see the image you just built.

``` shell
REPOSITORY                             TAG                 IMAGE ID            CREATED             SIZE
dotnet-app                             latest              26bae748895f        12 minutes ago      208MB
```

Run the docker image and verify it works.

``` shell
docker run -d -p 80:80 --name myapp dotnet-app
```

Verify the docker image is running.

``` shell
docker ps

CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                NAMES
77855df925bf        dotnet-app          "dotnet dotnet-app.d…"   6 minutes ago       Up 6 minutes        0.0.0.0:80->80/tcp   myapp
```

Open browser and visit `http://localhost/WeatherForecast`

Stop the running container

``` shell
docker kill 77855df925bf
```

Read more about:

- [Docker images for ASP.NET Core](https://docs.microsoft.com/en-us/aspnet/core/host-and-deploy/docker/building-net-docker-images)
- [Best practices for writing Dockerfiles](https://docs.docker.com/v17.09/engine/userguide/eng-image/dockerfile_best-practices/))

# Setup a local Docker Registry

Since we could not derectly deploy a local docker image to kubernetes, so we are going to use a local [Docker Registry](https://docs.docker.com/registry/) ranther then DockerHub or online registry. We start our own local Registry by docker.

Start the registry container, it will pull the docker registry on public [docker hub](https://hub.docker.com/_/registry?tab=description).

```shell
docker run -d -p 5000:5000 --name registry --restart always registry:2
```

We can see the docker rigistry is runing at localhost with port 5000.

```shell
CONTAINER ID        IMAGE               COMMAND                  CREATED             STATUS              PORTS                    NAMES
448aa1396778        registry:2          "/entrypoint.sh /etc…"   1 minute ago        Up 1 minute         0.0.0.0:5000->5000/tcp   registry
```

Tag our docker image with an additional tag – local repository address.

``` shell
docker tag dotnet-app localhost:5000/dotnet-app
```

Check the images, we see that we get an another `dotnet-app` image named `localhost:5000/dotnet-app`.

``` shell
docker images
REPOSITORY                             TAG                 IMAGE ID            CREATED             SIZE
dotnet-app                             latest              26bae748895f        25 minutes ago      208MB
localhost:5000/dotnet-app              latest              26bae748895f        25 minutes ago      208MB
```

Push the image to local registry

``` shell
docker push localhost:5000/dotnet-app
```

Verify the image is pushed.

``` shell
curl -X GET http://localhost:5000/v2/dotnet-app/tags/list
```

(Optionnal) Stop your registry and remove all data. Please make sure you finished ALL the demo practices when doing this step.

``` shell
docker container stop registry && docker container rm -v registry
```

Read more about [Deploy a registry server](https://docs.docker.com/registry/deploying/).

# Deply dotnet app to Kubernetes

## Create a namespace for dotnet app

Firstly, let's switch to `minikube` cluster.

```shell
# display list of contexts
kubectl config get-contexts

CURRENT   NAME                 CLUSTER          AUTHINFO         NAMESPACE
*         docker-desktop       docker-desktop   docker-desktop
          docker-for-desktop   docker-desktop   docker-desktop
          minikube             minikube         minikube

# set the default context
kubectl config use-context minikube

# display the current-context
kubectl config current-context
```

We can create a [namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/) for our application in Kubernates.

```shell
kubectl create namespace netcore
```

View the available namespace.

```shell
kubectl get namespace
NAME              STATUS   AGE
default           Active   24h
docker            Active   24h
kube-node-lease   Active   24h
kube-public       Active   24h
kube-system       Active   24h
netcore           Active   8s
```

## Create kubernetes resource description file

Create a kubernetes description [yaml file](https://kubernetes.io/docs/concepts/overview/working-with-objects/kubernetes-objects/#describing-a-kubernetes-object) for our demo application.

``` yaml
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: dotnet-app
  namespace: netcore
  labels:
    name: dotnet-app
spec:
  replicas: 1
  selector:
    matchLabels:
      name: dotnet-app
  template:
    metadata:
      labels:
        name: dotnet-app
    spec:
      containers:
        - name: dotnet-app
          image: localhost:5000/dotnet-app
          ports:
            - containerPort: 80
          imagePullPolicy: Always

---
apiVersion: v1
kind: Service
metadata:
  name: dotnet-app
  namespace: netcore
spec:
  type: NodePort
  ports:
    - port: 80
      targetPort: 80
  selector:
    name: dotnet-app

```

## Deploy to Kubernetes

Deploy the app to local Kubernetes.

```shell
kubectl create -f deployment.yaml -n netcore

deployment.extensions/dotnet-app created
service/dotnet-app created
```

> (Optional) Note: You can permanently save the namespace for all subsequent kubectl commands in that context. Then you can omit the trailing `"-n netcore"`.

```shell
kubectl config set-context --current --namespace=netcore
```

Now we can verify our deployment.

```bash
kubectl get service -n netcore

NAME         TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
dotnet-app   NodePort   10.107.195.245   <none>        80:32531/TCP   115s
```

The dotnet-app is mapping to port `32531`. Let's visit by localhost address, `http://localhost:32531/WeatherForecast`.

Destroy the deployments when you don't what them anymore.

```shell
kubectl delete -f deployment.yaml
```

## Scaling Resources

You can check the running replica pods by

```shell
kubectl get pods

NAME                         READY   STATUS    RESTARTS   AGE
dotnet-app-766d8687d-m5r94   1/1     Running   0          18m
```

At the moment, we have only 1 replica. We can scaling up the replicaset to `3` by

```shell
kubectl scale --replicas=3  deployment/dotnet-app -n netcore
```

Then we can see that we get 2 more running pods.

``` shell
kubectl get pods -n netcore
NAME                         READY   STATUS    RESTARTS   AGE
dotnet-app-766d8687d-m5r94   1/1     Running   0          19m
dotnet-app-766d8687d-7nk68   1/1     Running   0          7s
dotnet-app-766d8687d-sgw2q   1/1     Running   0          7s
```

Kubernetes doesn't support stop/pause of current state of pod and resume when needed. However, you can still achieve it by having no working deployments which is setting number of replicas to 0.

```shell
kubectl scale --replicas=0  deployment/dotnet-app -n netcore

kubectl get pods -n netcore
No resources found in netcore namespace.

kubectl get deployment -n netcore
NAME         READY   UP-TO-DATE   AVAILABLE   AGE
dotnet-app   0/0     0            0           20m
```

## Some useful cammands

Some use for cammand which can help to dignosise issues:

``` shell
kubectl get namespace
kubectl get service -n younamespace
kubectl get deployment -n younamespace
kubectl get pods -n yournamespace
kubectl describe [resource] -n yournamespace
```

Read more about kubectl commands at [Kubectl Cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
