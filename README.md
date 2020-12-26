KUBE MESHY - Linkerd version
=========

## What for

This project wants to some basic funtionalities of service mesh in Kubernetes.

## Components

1. Kubernetes deployed locally with KinD [https://kind.sigs.k8s.io/](https://kind.sigs.k8s.io/)
 
   For semplicity I used KinD, but can use Minikube, or every other kind of Kubernetes implementation.

   > Kubernetes Version 1.19.1.

2. Private Docker Registry

   Not mandatory.

3. Nginx ingress controller

   Installed through simple yaml file, avoided Helm for the moment.

4. Simple echo-server deployment

   Just a microservice example for the sake of the test. It accepts every request and respondes echoing the request received at every path.

5. **Linkerd service mesh**

   Installation taken from docs, nothing more.

   | Components injected | Notes |
   | ------------------- |:-----:|
   | nginx-ingress-controller| Linkerd's `Default mode` ingress injection |
   | echo-server | *none* |

## Installation

Let asdf be executable:

``

then run it:

``

and wait.

Once done you can deploy everything you want.

Before that, use that private registry:

```console
foo@bar:~$ docker tag [YOUR-IMAGE]:[TAG] localhost:${REGISTRY_EXT_PORT}/[YOUR-IMAGE]:[TAG]
```

```console
foo@bar:~$ docker push localhost:5000/[YOUR-IMAGE]:[TAG]
```

Regarding Linkerd deploy, install it.
On MacOS, with Homebrew:

```console
foo@bar:~$ brew install linkerd
```

or, if you had installed before, upgrade it:

```console
foo@bar:~$ brew upgrade linkerd
```

You can install it through command line on both Linux or MacOS:

```console
foo@bar:~$ curl -sL https://run.linkerd.io/install | sh && export PATH=$PATH:$HOME/.linkerd2/bin
```

Then do a preflight check:

```console
foo@bar:~$ linkerd check --pre
```

If everything is ok, then deploy linkerd into the cluster through its cli:

```console
foo@bar:~$ linkerd install | kubectl apply -f -
```

Watch the deployment progress:

```console
foo@bar:~$ watch -n1 kubectl -n linkerd get deploy
```

To get to the dashboard:

```console
foo@bar:~$ linkerd dashboard &
```

If you have something to deploy and you want to inject it with linkerd sidecars:

```console
foo@bar:~$ linkerd inject k8s.yml | kubectl apply -f -
```

otherwise, you can inject any running deployment with:

```console
foo@bar:~$ kubectl get deploy -o yaml | linkerd inject - | kubectl apply -f -
```


