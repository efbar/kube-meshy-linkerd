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


