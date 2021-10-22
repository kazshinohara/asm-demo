## Multi-cluster Ingress and Anthos Service Mesh demo

A demo with the following Google Cloud Products.

- [Multi Cluster Ingress (MCI)](https://cloud.google.com/kubernetes-engine/docs/concepts/multi-cluster-ingress)
- [Anthos Service Mesh (ASM)](https://cloud.google.com/anthos/service-mesh)
- [Google Kubernetes Engine (GKE)](https://cloud.google.com/kubernetes-engine)

### 1. Architecture
<img width="800" alt="Architecture" src="https://storage.googleapis.com/handson-images/mci-asm-architecture.png">

### 2. Resource relation
<img width="800" alt="resource relation" src="https://storage.googleapis.com/handson-images/mci-asm-resource-model.png">

### 3. Prerequisite
You must have a couple of GKE clusters which has ASM installed.  
Each cluster can be located at any Google Cloud region.  
The following demo procedure uses clusters below.
- asm-cluster-01 at asia-northeast1 region (Tokyo)
- asm-cluster-02 at asia-norhteast2 region (Osaaka)

For ASM installation, please check [ASM doc](https://cloud.google.com/service-mesh/docs/unified-install/managed-service-mesh).

Also don't forget to git clone this repo in the beginning.
```shell
❯ git clone git@github.com:kazshinohara/asm-demo.git
❯ cd ./asm-demo/mci-asm
```

### 4. Set up ASM environment
<font color="Red">You must do the following steps in both clusters</font>

#### 4-1. Set up a namespace for sample app
Create a namespace "asm-test" for the sample app.
```shell
❯ k apply -f namespace.yaml
namespace/asm-test created
```
Set a label to "asm-test" namespace for sidecar injection
In this demo, you use regular channel of MCP.
For ASM MCP, please check [ASM doc](https://cloud.google.com/service-mesh/docs/release-channels-managed-service-mesh).
```shell
❯ k label namespace asm-test istio-injection- istio.io/rev=asm-managed --overwrite
label "istio-injection" not found.
namespace/asm-test labeled
```

#### 4-2. istio-ingressgateway setup
By default, ASM does not have istio-ingressgateway for inbound traffic.  
You need to create it by yourself.
In this demo, you use "istio-system" namespace to host your istio-ingressgateway.

Set a label to "istio-system" namespace.
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

### 5. Set up MCI

For detail procedure, please check [MCI doc](https://cloud.google.com/kubernetes-engine/docs/how-to/multi-cluster-ingress-setup).

Note: This demo uses MCI standalone (not Anthos).

#### 5-1. Enable APIs
```shell
❯ gcloud services enable \                                                                         
    multiclusteringress.googleapis.com \
    gkehub.googleapis.com
```
#### 5-2. [optional] Register your clusters to Fleets
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

#### 5-3. Enable MCI and specify a config cluster
In this demo, you use asm-cluster-01 as a config cluster for MCI.
```shell
gcloud beta container hub ingress enable \
  --config-membership=asm-cluster-01
```

#### 5-4. Create MCI
<font color="Red">You must do this step in only asm-cluster-01</font>  

In advanced to this step, please make sure the following points.  

Note 1:  
you have to reserve a static external address(global) for VIP of MCI.  For the detailed procedure is 
[here](https://cloud.google.com/compute/docs/ip-addresses/reserve-static-external-ip-address).  

Note 2:  
Also you might have to configure your DNS server with your FQDN and the reserved address. 
In this demo, you use "mci1.gcpx.org" as FQDN for the sample app.  
If you don't do this step, please specify Host header in "4.Test"  

Note 3:  
Please update mci.yaml with your IP and FQDN accordingly.

Then let's apply MCI manifests.
```shell
❯ k apply -f mci.yaml
```

### 6. Apply ASM Configurations
<font color="Red">You must do the following steps in both clusters</font>
#### 6-1. Deploy the sample app
In this demo, you use [whereami](https://github.com/kazshinohara/whereami) as a sample app.
```shell
❯ k apply -f workload.yaml
deployment.apps/whereami created
service/whereami created
```

#### 6-2. Apply ASM configuration
```shell
❯ k apply -f asm.yaml
virtualservice.networking.istio.io/whereami configured
```

### 7. Test
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

If you have time to spare, let's see what's happen if you changed istio-ingressgateway replicas of asm-cluster-01 to Zero.
