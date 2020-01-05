
# Install Docker for Desktop

1. Download [Docker for Desktop for Mac](https://www.docker.com/products/docker-desktop)

2. Install application

3. Enable Kubernetes on Docker Desktop
    - `CMD` +`,` open Preference panel
    - switch to `Kubernetes` tap
    - tick `Enable Kubernetes` and wait for a few minutes

# Install MiniKube

With Minikube we can set up and operate a single node Kubernetes cluster as a local development environment.

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




# Build Asp.NetCore App

## Create WebApi project

Make sure you have `dotnet` installed on your machine already
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

## Create docker image

Create a docker image for the `dotnet-app` appliction which we just created.

Create a dockerfile at the root foler

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

Once then image buit, chec the image:

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

# Setup a local Docker Registry

We are going to use a local [Docker Registry](https://docs.docker.com/registry/) ranther then DockerHub or online registry. So we run our own local Registry by docker.

Start the registry container by docker

```shell
docker run -d -p 5000:5000 --name registry --restart always registry:2
```

Tag our docker image with an additional tag – local repository address.

``` shell
docker tag dotnet-app localhost:5000/dotnet-app
```

Check the images, we see that we get an another `dotnet-app` image named `localhost:5000/dotnet-app`.

``` shell
docker iamges
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

Stop your registry and remove all data once you finished all the practise.

``` shell
docker container stop registry && docker container rm -v registry
```

# Deply dotnet app to Kubernetes

Create a namespace in Kubernates.

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

Create a kubernetes deployment yaml file for our demo application.

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

Deploy the app to local Kubernetes.

```shell
kubectl create -f deployment.yaml

# the output will be
deployment.extensions/dotnet-app created
service/dotnet-app created
```

Now we can verify our deployment.

```bash
kubectl get service -n netcore

NAME         TYPE       CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
dotnet-app   NodePort   10.107.195.245   <none>        80:32531/TCP   115s
```

The dotnet-app is mapping to port `32531`. Let's visit by localhost address, `http://localhost:32531/WeatherForecast`.

Some use for cammand which can help to dignosise issues:

``` shell
kubectl get namespace
kubectl get service -n younamespace
kubectl get deployment -n younamespace
kubectl get pods -n yournamespace
kubectl describe [resource] -n yournamespace
```

Also you can permanently save the namespace for all subsequent kubectl commands in that context. Then you can omit the trailing `"-n netcore"`.

```shell
kubectl config set-context --current --namespace=netcore
```

Read more at [Kubectl Cheatsheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

