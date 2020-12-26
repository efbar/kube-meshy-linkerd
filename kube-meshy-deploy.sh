#! /bin/bash

set -e 

REGISTRY_NAME="private-registry1"
REGISTRY_EXT_PORT="5000"
KIND_CLUSTER_NAME="kube-1.19.1"

echo "Deploy Private Docker Registry"

docker run -d --restart=always -p "${REGISTRY_EXT_PORT}:5000" --name "${REGISTRY_NAME}" registry:2

echo
echo "Start KinD cluster"

kind create cluster  --name "${KIND_CLUSTER_NAME}" --config kind-configs/config.yaml

echo
echo "Waiting Kubernetes online.."

KUBEURL=$(kubectl cluster-info|sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g' | awk '/master/{print $6}')

while [ $(curl --output /dev/null --silent --head --fail $KUBEURL) != "403" ]; do
    printf '.'
    sleep 5
done

echo
echo "Kube UP!"
kubectl get nodes

echo
echo "Deploy Nginx-ingress"
kubectl apply -f nginx-ingress/nginx-ingress-deploy.yaml

echo
echo "Wait for Nginx-ingress controller to be ready."
POD=$(kubectl -n ingress-nginx get pods | awk '/contr/{print $1}')

while [ "$(kubectl -n ingress-nginx get pod ${POD} -o jsonpath='{.status.containerStatuses[0].ready}')" != "true" ]; do
    printf '.'
    sleep 5
done

echo -e '\e[0;32m

Now you can deploy everything you want!
Before that, use that private registry:

 $ docker tag [YOUR-IMAGE]:[TAG] localhost:${REGISTRY_EXT_PORT}/[YOUR-IMAGE]:[TAG]

 $ docker push localhost:5000/[YOUR-IMAGE]:[TAG]

For Linkerd deploy, install it.

On MacOS, with Homebrew:
 
 $ brew install linkerd

or, if you had installed before, upgrade it:
 
 $ brew upgrade linkerd

You can install it through command line on both Linux or MacOS:

 $ curl -sL https://run.linkerd.io/install | sh && export PATH=$PATH:$HOME/.linkerd2/bin

Then do a preflight check:

 $ linkerd check --pre

If everything is ok, then deploy linkerd into the cluster through its cli:

 $ linkerd install | kubectl apply -f -

Watch the deployment progress:

 $ watch -n1 kubectl -n linkerd get deploy

To get to the dashboard:

 $ linkerd dashboard &

If you have something to deploy and you want to inject it with linkerd sidecars:

 $ linkerd inject k8s.yml | kubectl apply -f -

otherwise, you can inject any running deployment with:

 $ kubectl get deploy -o yaml | linkerd inject - | kubectl apply -f -

\e[0m'
