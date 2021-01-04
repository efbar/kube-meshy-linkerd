KUBE MESHY - Linkerd version
=========

## What for

This project wants to show some basic functionalities of service mesh in Kubernetes.
In this case we will use **Linkerd**.

## Components

1. _Kubernetes deployed locally with KinD_ ([https://kind.sigs.k8s.io/](https://kind.sigs.k8s.io/))
 
   I used KinD just for simplicity, but can use Minikube, or every other kind of Kubernetes implementation.

   > Kubernetes Version 1.19.1.

2. _Private Docker Registry_

   Not mandatory.

3. _Nginx ingress controller_

   Installed through simple yaml file, avoided Helm for the moment.

4. _Simple minimal-service deployment_

   Just a microservice example for the sake of the test. Here you can find the code [https://github.com/efbar/minimal-service](https://github.com/efbar/minimal-service)

5. _Linkerd service mesh_

   Installation taken from docs, nothing more.

   | Components injected | Notes |
   | ------------------- |:-----:|
   | nginx-ingress-controller| Linkerd `Proxy Ingress mode` |
   | minimal-service | [Dockerfile](https://github.com/efbar/minimal-service/blob/main/Dockerfile) |
   | bounced-service | [Dockerfile](https://github.com/efbar/minimal-service/blob/main/Dockerfile) |

## Installation

Let `kube-meshy-deploy.sh` be executable:

```bash
$ chmod +x kube-meshy-deploy.sh
```

then run it:

```bash
$ ./kube-meshy-deploy.sh
```

and wait.

Once done you can deploy everything you want.
Before that, use that private registry:

```bash
$ docker tag [YOUR-IMAGE]:[TAG] localhost:${REGISTRY_EXT_PORT}/[YOUR-IMAGE]:[TAG]
```

```bash
$ docker push localhost:5000/[YOUR-IMAGE]:[TAG]
```

Now let's install Linkerd, on MacOS, with Homebrew:

```bash
$ brew install linkerd
```

or, if you had installed before, upgrade it:

```bash
$ brew upgrade linkerd
```

You can install it through command line on both Linux or MacOS:

```bash
$ curl -sL https://run.linkerd.io/install | sh && export PATH=$PATH:$HOME/.linkerd2/bin
```

Then do a preflight check:

```bash
$ linkerd check --pre
```

If everything is ok, then deploy linkerd into the cluster through its cli:

```bash
$ linkerd install | kubectl apply -f -
```

Watch the deployment progress:

```bash
$ watch -n1 kubectl -n linkerd get deploy
```

To get to the dashboard:

```bash
$ linkerd dashboard &
```

### Play with mesh

#### Setup the mesh

##### Ingress Controller
The ingress traffic mode chosen is `Proxy Ingress Mode` (more [here](https://linkerd.io/2/tasks/using-ingress/#proxy-ingress-mode)).

```bash
$ kubectl get deployment ingress-nginx-controller -n ingress-nginx -o yaml | linkerd inject --ingress - | kubectl apply -f -
```

this will allow us to have the possibility to have Linkerd features (Metrics, Service Profiles, Traffic Splits, etc..) enabled for ingress controller

##### Workload
You can inject any running deployment with:

```bash
$ kubectl get deploy -o yaml | linkerd inject - | kubectl apply -f -
```

In our case we can deploy two deployments that will talk to each other, both of them have with injection enabled annotations.
They are called `minimal-service` and `bounced-service`.
For deploying them we need `Kustomize`, not the version inside `kubectl` but the official one since the merged one is not updated.
Install it with:

```bash
curl -s "https://raw.githubusercontent.com/\
kubernetes-sigs/kustomize/master/hack/install_kustomize.sh"  | bash
```

or on MacOS:

```bash
brew install kustomize
```

You can inspect what we're going to deploy with:

```bash
$ kustomize build test-services/overlays/minimal-service/
```

The output is composed by one deployment, one service and one ingress.
For the sake of tests, push `minimal-service` image in local registry as showed before (the image Dockerfile is located in the table at the beginning of the docs).

Then we can really deploying them *applying* the output of the last command:

```bash
$ kustomize build test-services/overlays/minimal-service/ | kubectl apply -f -
```

and for bounced microservice,

```bash
$ kustomize build test-services/overlays/bounced-service/ | kubectl apply -f -
```

#### Use mesh feature: SERVICE PROFILE and RETRIES

A good scenario that could happen in microservice environments could be when one service is not responding as expected, could drop communications due to bad release from devs, misconfigurations, network problems, etc...
We are now proving that service mesh could help us to prevent those kind of contingencies, and how easy is to implement it with Linkerd.

##### Service-to-Service use case
We can observe routes:

```bash
$ linkerd routes -n default deploy                                  
==> deployment/bounced-service <==
ROUTE               SERVICE   SUCCESS   RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99
[DEFAULT]   bounced-service         -     -             -             -             -

==> deployment/minimal-service <==
ROUTE               SERVICE   SUCCESS   RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99
[DEFAULT]   minimal-service         -     -             -             -             -
```

and stats:

```bash
$ linkerd stat -n default deploy 
NAME              MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
bounced-service      1/1   100.00%   0.4rps           1ms           1ms           1ms          1
minimal-service      1/1   100.00%   0.4rps           1ms           1ms           1ms          1
```

Then let's stress those services:
```bash
$ for i in {1..10000}; do curl -s -H "Host: minimal-service" http://localhost/bounce -d '{"rebound":"true","endpoint":"http://bounced-service.default.svc.cluster.local:9090"}' | jq '.["body"]' && sleep 1s; done
```

this for loop will execute, every second, a `POST` request to `minimal-service` that will perform a `GET` request to `bounced-service`.

Now notice that responses are negative, showing a lot of 500 errors.

```bash
$ for i in {1..10000}; do curl -s -H "Host: minimal-service" http://localhost/bounce -d '{"rebound":"true","endpoint":"http://bounced-service.default.svc.cluster.local:9090"}' | jq '.["body"]' && sleep 1s; done
"200 OK"
"200 OK"
"200 OK"
"500 Internal Server Error"
"200 OK"
"500 Internal Server Error"
"500 Internal Server Error"
"500 Internal Server Error"
"500 Internal Server Error"
"200 OK"
```

If you check metrics again you'll notice that the success rate for bounced-service is decreasing:
```bash
$ linkerd stat -n default deploy 
NAME              MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
bounced-service      1/1    46.88%   1.1rps           1ms           1ms           1ms          3
minimal-service      1/1   100.00%   1.1rps           7ms          10ms          10ms          3
```
We can now deploy a Linkerd ServiceProfile:

```bash
$ kubectl apply -f linkerd/service-profiles/bounced-service-sp.yaml
```

this object will instruct linkerd' sidecar to perform certain number of retries until it will receive a a response with 200 status code.

And you'll see that the bounced-service will return 200 responses.
```bash
$ for i in {1..10000}; do curl -s -H "Host: minimal-service" http://localhost/bounce -d '{"rebound":"true","endpoint":"http://bounced-service.default.svc.cluster.local:9090"}' | jq '.["body"]' && sleep 1s; done
"200 OK"
"200 OK"
"200 OK"
"200 OK"
"200 OK"
"200 OK"
"200 OK"
"200 OK"
"200 OK"
```

Metrics will confirm that success rate is still low while RPS (Request Per Second) is increasing thanks to the mesh sidecar:
```bash
$ linkerd stat -n default deploy 
NAME              MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
bounced-service      1/1    44.44%   2.5rps           1ms           1ms           1ms          3
minimal-service      1/1   100.00%   1.4rps           7ms          13ms          19ms          3
```

and in facts looking at routes we can notice the help from mesh sidecar:

```bash
$ linkerd routes -n default deploy/bounced-service
ROUTE               SERVICE   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99
GET /       bounced-service    33.80%   2.4rps           1ms           1ms           1ms
[DEFAULT]   bounced-service    50.00%   0.2rps           0ms           0ms           0ms
```

```bash
$ linkerd routes -n default deploy/bounced-service
ROUTE               SERVICE   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99
GET /       bounced-service    32.39%   2.9rps           1ms           1ms           1ms
[DEFAULT]   bounced-service         -        -             -             -             -
```

```bash
$ linkerd routes -n default deploy/bounced-service
ROUTE               SERVICE   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99
GET /       bounced-service    26.24%   3.7rps           1ms           1ms           1ms
[DEFAULT]   bounced-service         -        -             -             -             -
```



##### Ingress-to-Service use case

Stop the for loop and delete the ServiceProfile:

```bash
$ kubectl delete -f linkerd/service-profiles/bounced-service-sp.yaml
```

Have a look of ingress-nginx-controller stats:
```bash
$ linkerd stat -n ingress-nginx deploy 
NAME                       MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
ingress-nginx-controller      1/1   100.00%   0.2rps           1ms           2ms           2ms          1
```

and our microservice deployments:

```bash
$ linkerd stat -n default deploy       
NAME              MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
bounced-service      1/1   100.00%   0.4rps           1ms           1ms           1ms          1
minimal-service      1/1   100.00%   0.4rps           1ms           1ms           1ms          1
```

Now let's try to reach bounced-service directly, without minimal-service help:
```bash
$ for i in {1..10000}; do curl -s -H "Content-type:application/json" -H "Host: bounced-service" http://localhost/bounced-service | jq '.statuscode? // .' && sleep 1s; done
```

This will print `200` or `Internal Server Error`. 
Running that, we have back some 500 status in our responses. This will affect also Nginx ingress controller since it is the one that will receive 500 back first.

```bash
$ linkerd stat -n ingress-nginx deploy 
NAME                       MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
ingress-nginx-controller      1/1    45.24%   0.7rps           1ms           2ms           3ms          2
```

```bash
$ linkerd stat -n default deploy       
NAME              MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
bounced-service      1/1    56.94%   1.2rps           1ms           1ms           1ms          3
minimal-service      1/1   100.00%   0.4rps           1ms           1ms           1ms          1
```

We can now reapply a Linkerd ServiceProfile:

```bash
$ kubectl apply -f linkerd/service-profiles/bounced-service-sp.yaml
```

and notice instantly that we are not receiving `Internal Server Error` back anymore and in stats observation we can notice that success rate is still low but RPS is increasing:

```bash
$ linkerd stat -n default deploy/bounced-service
NAME              MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
bounced-service      1/1    38.71%   2.6rps           1ms           1ms           1ms          3
```

Nginx controller success percentage is increasing too, since it is now receiving 200 status back from mesh:
```bash
$ linkerd stat -n ingress-nginx deploy 
NAME                       MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
ingress-nginx-controller      1/1    74.29%   1.2rps           2ms          14ms          19ms          2
```

```bash
$ linkerd stat -n ingress-nginx deploy            
NAME                       MESHED   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99   TCP_CONN
ingress-nginx-controller      1/1   100.00%   1.2rps           2ms           7ms           9ms          2
```

retries are increasing too:

```bash
$ linkerd routes -n default deploy/bounced-service
ROUTE               SERVICE   SUCCESS      RPS   LATENCY_P50   LATENCY_P95   LATENCY_P99
GET /       bounced-service    27.19%   3.6rps           1ms           1ms           1ms
[DEFAULT]   bounced-service         -        -             -             -             -
```


