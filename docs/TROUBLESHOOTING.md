# Troubleshooting Guide

This document details common issues encountered during the deployment of the Pickstream application to GKE and their solutions.

## Table of Contents

1. [ImagePullBackOff - Artifact Registry Permissions](#imagepullbackoff---artifact-registry-permissions)
2. [Backend CrashLoopBackOff - Health Probe Timing](#backend-crashloopbackoff---health-probe-timing)
3. [Frontend Permission Errors - Non-Root Container](#frontend-permission-errors---non-root-container)
4. [NetworkPolicy Blocking DNS](#networkpolicy-blocking-dns)
5. [Nginx DNS Resolution Failure](#nginx-dns-resolution-failure)

---

## ImagePullBackOff - Artifact Registry Permissions

### Symptoms
```
Events:
  Warning  Failed     pod/pickstream-backend-xxx   Failed to pull image: failed to pull and unpack image
  Warning  Failed     pod/pickstream-backend-xxx   Error: ImagePullBackOff
```

### Root Cause
GKE node service account (`pickstream-cluster-nodes-sa`) didn't have permission to pull images from Artifact Registry.

### Solution
Grant `roles/artifactregistry.reader` role to the GKE node service account:

```bash
gcloud projects add-iam-policy-binding gcp-terraform-demo-474514 \
    --member="serviceAccount:pickstream-cluster-nodes-sa@gcp-terraform-demo-474514.iam.gserviceaccount.com" \
    --role="roles/artifactregistry.reader"
```

### Prevention
Ensure node service accounts have appropriate Artifact Registry permissions during cluster setup.

---

## Backend CrashLoopBackOff - Health Probe Timing

### Symptoms
```
Events:
  Warning  Unhealthy  pod/pickstream-backend-xxx   Liveness probe failed: connection refused
  Warning  BackOff    pod/pickstream-backend-xxx   Back-off restarting failed container
```

Backend logs show application takes 75-100 seconds to start:
```
Started PickstreamApplication in 76.499 seconds (process running for 88.276)
```

### Root Cause
Health probe timing was too aggressive:
- Liveness probe `initialDelaySeconds: 60` - Started before application was ready
- Readiness probe `initialDelaySeconds: 30` - Too early for Spring Boot startup

### Solution
Updated health probe timings in `helm/pickstream/values.yaml`:

```yaml
backend:
  livenessProbe:
    initialDelaySeconds: 120  # Changed from 60
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
  
  readinessProbe:
    initialDelaySeconds: 90   # Changed from 30
    periodSeconds: 10
    timeoutSeconds: 5
    failureThreshold: 3
```

### Prevention
- Measure actual application startup time in development
- Set `initialDelaySeconds` to at least 1.5x the measured startup time
- Monitor startup times and adjust probes if they increase

---

## Frontend Permission Errors - Non-Root Container

### Symptoms
```
2025/11/20 14:32:15 [emerg] 1#1: mkdir() "/var/cache/nginx/client_temp" failed (13: Permission denied)
2025/11/20 14:32:15 [emerg] 1#1: open() "/etc/nginx/nginx.conf" failed (13: Permission denied)
```

### Root Cause
Nginx Alpine image runs as non-root user (`nginx`) but needs write access to:
- `/var/cache/nginx/*` - Temp directories for proxy/fastcgi
- `/etc/nginx/` - Configuration files
- `/var/run/` - PID file

### Solution
Modified `services/frontend/Dockerfile`:

```dockerfile
# Create writable directories with proper permissions
RUN mkdir -p /var/cache/nginx/client_temp /var/cache/nginx/proxy_temp \
             /var/cache/nginx/fastcgi_temp /var/cache/nginx/uwsgi_temp \
             /var/cache/nginx/scgi_temp /var/run /tmp/nginx && \
    chown -R nginx:nginx /var/cache/nginx /var/run /tmp/nginx /etc/nginx && \
    chmod -R 755 /var/cache/nginx /var/run /tmp/nginx
```

Updated `services/frontend/nginx.conf`:
```nginx
pid /tmp/nginx/nginx.pid;  # Changed from /var/run/nginx.pid
```

### Prevention
- Always test containers with non-root users during development
- Use writable directories like `/tmp` for runtime files
- Set proper ownership and permissions in Dockerfile

---

## NetworkPolicy Blocking DNS

### Symptoms
All pods unable to reach external services or perform DNS resolution:
```
2025/11/20 15:26:58 [error] pickstream-backend could not be resolved (3: Host not found)
```

DNS queries to kube-dns at `10.8.0.10` were being blocked.

### Root Cause
NetworkPolicy template was configured to block all egress traffic by default, including DNS queries to `kube-dns` in the `kube-system` namespace.

### Solution
1. **Immediate fix**: Deleted NetworkPolicy resources:
```bash
kubectl delete networkpolicy --all -n pickstream
```

2. **Permanent fix**: 
   - Removed `helm/pickstream/templates/networkpolicy.yaml`
   - Added cleanup step to CI/CD pipeline in `.github/workflows/ci-cd.yml`:
```yaml
- name: Delete NetworkPolicy if exists
  run: |
    kubectl delete networkpolicy --all -n pickstream --ignore-not-found=true
```

3. **Updated values**: Set `networkPolicy.enabled: false` in `helm/pickstream/values.yaml`

### Prevention
If NetworkPolicy is needed, ensure it allows:
```yaml
egress:
  # Allow DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
  
  # Allow internal cluster communication
  - to:
    - namespaceSelector: {}
```

---

## Nginx DNS Resolution Failure

### Symptoms
Frontend pod running but API calls failing with 502 Bad Gateway:
```
2025/11/20 15:28:19 [error] 12#12: pickstream-backend could not be resolved (3: Host not found)
10.0.0.3 - - [20/Nov/2025:15:28:19 +0000] "GET /api/health HTTP/1.1" 502 559
```

However, manual DNS resolution worked:
```bash
$ kubectl exec -n pickstream pickstream-frontend-xxx -- nslookup pickstream-backend
Server:    10.8.0.10
Address 1: 10.8.0.10 kube-dns.kube-system.svc.cluster.local

Name:      pickstream-backend
Address 1: 10.8.1.29 pickstream-backend.pickstream.svc.cluster.local
```

### Root Cause
**Multiple issues:**

1. **Incorrect envsubst syntax in Dockerfile** - Variables weren't being substituted:
```dockerfile
# BROKEN - Shell tries to expand $VARS during echo
echo 'envsubst "$BACKEND_SERVICE_HOST $BACKEND_SERVICE_PORT $DNS_IP"'

# FIXED - Single quotes prevent premature expansion
echo 'envsubst '"'"'$BACKEND_SERVICE_HOST $BACKEND_SERVICE_PORT $DNS_IP'"'"''
```

2. **Wrong awk syntax** - DNS IP extraction failed:
```bash
# BROKEN - Literal $2 instead of awk variable
awk "{print \$2}"

# FIXED - Proper awk variable syntax
awk '{print $2}'
```

3. **Short hostname vs FQDN** - GKE DNS prefers fully-qualified names for reliability

### Why This Worked in Docker Compose

Docker Compose explicitly set environment variables:
```yaml
frontend:
  environment:
    - BACKEND_SERVICE_HOST=backend
    - BACKEND_SERVICE_PORT=8080
```

So even with broken `envsubst`, the variables existed and Docker's embedded DNS resolved short names immediately.

In Kubernetes:
- Relied on Dockerfile ENV defaults
- `envsubst` silently failed due to syntax errors
- Nginx config had literal `${BACKEND_SERVICE_HOST}` strings
- Kubernetes DNS requires explicit resolver configuration

### Solution

**1. Fixed envsubst syntax in `services/frontend/Dockerfile`:**

```dockerfile
# Create a script to substitute environment variables and detect DNS IP
RUN echo '#!/bin/sh' > /docker-entrypoint.sh && \
    echo '# Get Kubernetes DNS IP from resolv.conf' >> /docker-entrypoint.sh && \
    echo 'DNS_IP=$(grep nameserver /etc/resolv.conf | head -n1 | awk '"'"'{print $2}'"'"')' >> /docker-entrypoint.sh && \
    echo 'export DNS_IP' >> /docker-entrypoint.sh && \
    echo 'echo "Using Kubernetes DNS IP: $DNS_IP"' >> /docker-entrypoint.sh && \
    echo 'envsubst '"'"'$BACKEND_SERVICE_HOST $BACKEND_SERVICE_PORT $DNS_IP'"'"' < /etc/nginx/nginx.conf.template > /tmp/nginx/nginx.conf' >> /docker-entrypoint.sh && \
    echo 'exec nginx -c /tmp/nginx/nginx.conf -g "daemon off;"' >> /docker-entrypoint.sh && \
    chmod +x /docker-entrypoint.sh
```

**Key changes:**
- Fixed awk syntax: `awk '{print $2}'`
- Fixed envsubst syntax: `envsubst '$VAR1 $VAR2 $VAR3'` (single quotes around dollar-prefixed variables)

**2. Used FQDN in `services/frontend/nginx.conf`:**

```nginx
resolver ${DNS_IP} valid=10s ipv6=off;

location /api/ {
    # Use FQDN for better reliability in Kubernetes
    set $backend_upstream "${BACKEND_SERVICE_HOST}.pickstream.svc.cluster.local:${BACKEND_SERVICE_PORT}";
    proxy_pass http://$backend_upstream;
}
```

### Verification

After fix, check that envsubst worked:
```bash
kubectl exec -n pickstream pickstream-frontend-xxx -- cat /tmp/nginx/nginx.conf | grep resolver
# Should show: resolver 10.8.0.10 valid=10s ipv6=off;

kubectl exec -n pickstream pickstream-frontend-xxx -- cat /tmp/nginx/nginx.conf | grep backend_upstream
# Should show: set $backend_upstream "pickstream-backend.pickstream.svc.cluster.local:8080";
```

Check logs for successful API calls:
```bash
kubectl logs -n pickstream pickstream-frontend-xxx --tail=5
# Should show: 200 OK responses, no "Host not found" errors
```

### Prevention

1. **Test environment variable substitution in Dockerfile**:
```bash
docker build -t test-frontend ./services/frontend
docker run --rm test-frontend cat /tmp/nginx/nginx.conf
# Verify no ${VARIABLE} literals remain
```

2. **Use FQDN for Kubernetes services** - More explicit and reliable than short names

3. **Add startup logs** to verify configuration:
```bash
echo "DNS_IP: $DNS_IP"
echo "Backend: $BACKEND_SERVICE_HOST:$BACKEND_SERVICE_PORT"
cat /tmp/nginx/nginx.conf | grep -E "(resolver|backend_upstream)"
```

4. **Test DNS resolution during development**:
```bash
kubectl run -it --rm debug --image=alpine --restart=Never -- sh
apk add bind-tools
nslookup service-name.namespace.svc.cluster.local
```

---

## GKE-Specific Considerations

### DNS IP Address
GKE uses a different DNS IP than standard Kubernetes:
- **GKE**: `10.8.0.10` (or cluster-specific)
- **Standard K8s**: `10.96.0.10`

Always detect dynamically from `/etc/resolv.conf`:
```bash
DNS_IP=$(grep nameserver /etc/resolv.conf | head -n1 | awk '{print $2}')
```

### Private Cluster Nodes
If GKE cluster nodes don't have external IPs:
- Use LoadBalancer service type for external access
- Configure Cloud NAT for outbound internet access
- Ensure proper firewall rules for LoadBalancer traffic

---

## Debugging Checklist

When troubleshooting deployment issues:

1. **Check pod status**:
```bash
kubectl get pods -n pickstream -o wide
kubectl describe pod -n pickstream <pod-name>
```

2. **Check logs**:
```bash
kubectl logs -n pickstream <pod-name> --tail=50
kubectl logs -n pickstream <pod-name> --previous  # If pod restarted
```

3. **Verify service and endpoints**:
```bash
kubectl get svc -n pickstream
kubectl get endpoints -n pickstream
```

4. **Test DNS resolution**:
```bash
kubectl exec -n pickstream <pod-name> -- nslookup <service-name>
kubectl exec -n pickstream <pod-name> -- nslookup <service-name>.<namespace>.svc.cluster.local
```

5. **Test connectivity**:
```bash
kubectl exec -n pickstream <frontend-pod> -- wget -O- http://pickstream-backend:8080/actuator/health
```

6. **Check NetworkPolicy**:
```bash
kubectl get networkpolicy -n pickstream
kubectl describe networkpolicy -n pickstream <policy-name>
```

7. **Port forward for local testing**:
```bash
kubectl port-forward -n pickstream svc/pickstream-backend 8080:8080
curl http://localhost:8080/api/random-name
```

---

## Additional Resources

- [Kubernetes DNS Debugging](https://kubernetes.io/docs/tasks/administer-cluster/dns-debugging-resolution/)
- [GKE Networking Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices/networking)
- [Nginx Dynamic DNS Resolution](https://www.nginx.com/blog/dns-service-discovery-nginx-plus/)
- [Container Security Best Practices](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
