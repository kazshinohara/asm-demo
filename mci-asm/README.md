## Multi-cluster Ingress and Anthos Service Mesh demo

A demo application with the following Google Cloud Products.

- [Multi Cluster Ingress (MCI)](https://cloud.google.com/kubernetes-engine/docs/concepts/multi-cluster-ingress)
- [Anthos Service Mesh (ASM)](https://cloud.google.com/anthos/service-mesh)
- [Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine)

### Architecture
![architecture_diagram](https://storage.googleapis.com/handson-images/mci-asm-demo.png)

### 0. Prerequisite
You must have a couple of GKE clusters which has ASM installed.  
Each cluster can be located at any Google Cloud region.  
The following demo procedure is based upon the following clusters.
- asm-cluster-01 at asia-northeast1 region (Tokyo)
- asm-cluster-02 at asia-norhteast2 region (OSaka)

For ASM installation, please check [ASM doc](https://cloud.google.com/service-mesh/docs/unified-install/managed-service-mesh).

Also don't forget to git clone this repo in the beginning.
```shell
❯ git clone git@github.com:kazshinohara/asm-demo.git
❯ cd ./asm-demo
```

### 1. Set up ASM environment

#### 1-1. Set up a namespace for workload
Create a namespace "asm-test" for the sample app.
```shell
❯ k apply -f namespace.yaml
namespace/asm-test created
```
Set a label to the newly created namespace for sidecar injection
```shell
❯ k label namespace asm-test istio-injection- istio.io/rev=asm-managed --overwrite
label "istio-injection" not found.
namespace/asm-test labeled
```

#### 1-2. istio-ingressgateway setup
By default, ASM does not have istio-ingressgateway for inbound traffic.  
You need to create it by yourself.
In this demo, you use istio-system namespace to host your istio-ingressgateway.

Set a label to istio-system namespace.
```shell
❯ k label namespace istio-system istio-injection- istio.io/rev=asm-managed --overwrite
label "istio-injection" not found.
namespace/istio-system labeled
```

Create a service account for istio-ingressgateway.
```shell
❯ k apply -f asm-gateway/serviceaccount.yaml   
serviceaccount/istio-ingressgateway created
```

Create a role and bind your service account for istio-ingressgateway.
```shell
❯ k apply -f asm-gateway/role.yaml
role.rbac.authorization.k8s.io/istio-ingressgateway created
rolebinding.rbac.authorization.k8s.io/istio-ingressgateway created
```

Create your istio-ingressgateway.
```shell
❯ k apply -f asm-gateway/gateway.yaml 
deployment.apps/istio-ingressgateway created
poddisruptionbudget.policy/istio-ingressgateway created
```

### 2. Set up MCI

For detail procedure, please check [MCI doc](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress-setup)

Note: This demo uses MCI standalone (not Anthos).

#### 2-1. Enable APIs
```shell
❯ gcloud services enable \                                                                         
    multiclusteringress.googleapis.com \
    gkehub.googleapis.com \
```
#### 2-2. [optional] Register your clusters to Fleets
If you've already installed ASM to your clusters, you can skip the following steps.
```shell
gcloud container hub memberships register asm-cluster-01 \
    --gke-cluster asia-northeast1/asm-cluster-01 \
    --enable-workload-identity
```
```shell
gcloud container hub memberships register asm-cluster-02 \
    --gke-cluster asia-northeast2/asm-cluster-02 \
    --enable-workload-identity
```

#### 2-3. Set up a config cluster for MCI
In this demo, you use asm-cluster-01 as a config cluster for MCI.
```shell
gcloud beta container hub ingress enable \
  --config-membership=asm-cluster-01
```

#### 2-4. Create MCI
Note1: In advanced to this step, you have to reserve a global address for VIP of MCI.  
Note2: Also you have to configure your DNS server with your FQDN and the reserved address. 
In this demo, you use "mci1.gcpx.org" as FQDN for the sample app.

```shell
❯ k apply -f mci.yaml
```

### 3. Apply ASM Configuration
#### 3-1. Deploy the sample app
In this demo, you use [whereami](https://github.com/kazshinohara/whereami) as a sample app.
```shell
❯ k apply -f workload.yaml
deployment.apps/whereami created
service/whereami created
```

#### 3-2. Apply ASM configuration
```shell
❯ k apply -f asm.yaml
virtualservice.networking.istio.io/whereami configured
```

### 4. Test
You could see your traffic appropriately routes to Tokyo & Osaka GKE cluster.  

From Tokyo client
```shell
❯ while true; do curl -s http://mci1.gcpx.org/region | jq ; sleep 1; done
{
  "region": "asia-northeast1"
}
{
  "region": "asia-northeast1"
}
{
  "region": "asia-northeast1"
}
```

From Osaka client
```shell
❯ while true; do curl -s http://mci1.gcpx.org/region | jq ; sleep 1; done
{
  "region": "asia-northeast2"
}
{
  "region": "asia-northeast2"
}
{
  "region": "asia-northeast2"
}
```