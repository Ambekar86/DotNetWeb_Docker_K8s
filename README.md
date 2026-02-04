# DotNetWeb_Docker_K8s
Dotnet Web application along with unit test case + Dockerfile + deployment files

Dotnet web with Dockerfile & K8s files

-------to build a sample DotNet project & Dockerfile with testing-----------
dotnet new sln -n DockerDotNetDemo
dotnet new webapi -n DockerDotNetDemo.Api
dotnet new xunit -n DockerDotNetDemo.Tests
dotnet sln DockerDotNetDemo.sln add DockerDotNetDemo.Api
dotnet sln DockerDotNetDemo.sln add DockerDotNetDemo.Tests
dotnet add DockerDotNetDemo.Tests reference DockerDotNetDemo.Api

dotnet restore
dotnet build --no-restore --configuration release
dotnet test --configuration release 

-----add a 'DockerDotNetDemo.Tests.cs' into root folder ------
using Xunit;
namespace DockerDotNetDemo.Tests
{
    public class UnitTest1
    {
        [Fact]
        public void Sample_Test_Should_Pass()
        {
            Assert.True(true);
        }
    }
}



-----add a Dockerfile into root folder------
# ----------------------------
# Build & Test stage
# ----------------------------
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy everything
COPY . .

# Restore dependencies
RUN dotnet restore DockerDotNetDemo.sln

# Run unit tests
RUN dotnet test DockerDotNetDemo.Tests/DockerDotNetDemo.Tests.csproj --no-restore

# Publish API
RUN dotnet publish DockerDotNetDemo.Api/DockerDotNetDemo.Api.csproj \
    -c Release \
    -o /app/publish \
    --no-restore

# ----------------------------
# Runtime stage
#-----------------------------
FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Development
COPY --from=build /app/publish .
EXPOSE 5000
ENTRYPOINT ["dotnet", "DockerDotNetDemo.Api.dll"]


Note:-- root/DockerDotNetDemo.Api/Program.cs replace with below code & save

var builder = WebApplication.CreateBuilder(args);
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
var app = builder.Build();
app.UseSwagger();
app.UseSwaggerUI();
// app.UseHttpsRedirection(); // disable for Docker/local
app.MapGet("/", () => "DockerDotNetDemo API is running");
app.MapGet("/health", () => Results.Ok("Healthy"));
app.Run();


--------o/p from local CMD----------
http://localhost:5000
http://localhost:5000/   -- (optional)
http://localhost:5000/health -- (optional)
http://localhost:5000/swagger

---------open/enable Docker Desktop & go to path/folder then run below commands from wsl--------
docker build -t dotnet-docker-demo .
docker run -d -p 5000:5000 --name dotnet-demo dotnet-docker-demo
docker logs dotnet-demo
curl http://localhost:5000/swagger

----------Docker container lifecycle: ------------
Created → Running → Exited → Deleted

-----If any issues(clean rebuild) ---------
docker stop dotnet-demo || true
docker rm dotnet-demo || true
docker rmi dotnet-docker-demo || true
docker build --no-cache -t dotnet-docker-demo .  (this is must)

-----------re-run(de-bug example) --------------
docker run -d -p 8080:8080 --name dotnet-demo dotnet-docker-demo
docker logs dotnet-demo
Test from WSL -- curl http://localhost:8080/swagger  (If this works → browser will also work)

Create these below files in root folder
------namespace.yml-----------
apiVersion: v1
kind: Namespace
metadata:
  name: dotnet-demo-ns

Note: kubectl apply -f namespace.yml

-----deployment.yml-----
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dotnet-demo
  namespace: dotnet-demo-ns
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dotnet-demo
  template:
    metadata:
      labels:
        app: dotnet-demo
    spec:
      containers:
        - name: dotnet-demo
          image: thukaram07/dotnetweb-docker:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
          env:
            - name: ASPNETCORE_URLS
              value: http://+:8080
          readinessProbe:
            httpGet:
              path: /swagger/index.html
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /swagger/index.html
              port: 8080
            initialDelaySeconds: 20
            periodSeconds: 20
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "250m"
              memory: "256Mi"

note: kubectl apply -f deployment.yml

--------service.yml------

apiVersion: v1
kind: Service
metadata:
  name: dotnet-demo-svc
  namespace: dotnet-demo-ns
spec:
  type: LoadBalancer
  selector:
    app: dotnet-demo
  ports:
    - name: http
      port: 80
      targetPort: 8080
      

Debugging:
----------------

run/try this below commands:
minikube tunnel (this should not be stop/close)

C:\Users\ThukaramRao>kubectl get pods -n dotnet-demo-ns
NAME                           READY   STATUS    RESTARTS   AGE
dotnet-demo-66788cd997-g6888   1/1     Running   0          17m

C:\Users\ThukaramRao>kubectl get svc -n dotnet-demo-ns
NAME              TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
dotnet-demo-svc   LoadBalancer   10.99.170.30   127.0.0.1     80:32751/TCP   38m

C:\Users\ThukaramRao>minikube ip
192.168.49.2

C:\Users\ThukaramRao>kubectl port-forward svc/dotnet-demo-svc 8081:80 -n dotnet-demo-ns
Forwarding from 127.0.0.1:8081 -> 8080
Forwarding from [::1]:8081 -> 8080

C:\Users\ThukaramRao>kubectl get endpoints dotnet-demo-svc -n dotnet-demo-ns
NAME              ENDPOINTS           AGE
dotnet-demo-svc   10.244.0.113:8080   56m

C:\Users\ThukaramRao>kubectl logs deployment/dotnet-demo -n dotnet-demo-ns
warn: Microsoft.AspNetCore.Hosting.Diagnostics[15]
      Overriding HTTP_PORTS '8080' and HTTPS_PORTS ''. Binding to values defined by URLS instead 'http://+:8080'.
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://[::]:8080
info: Microsoft.Hosting.Lifetime[0]
      Application started. Press Ctrl+C to shut down.
info: Microsoft.Hosting.Lifetime[0]
      Hosting environment: Development
info: Microsoft.Hosting.Lifetime[0]
      Content root path: /app

      
http://localhost:8081/swagger -- (final o/p from web browser)

Practices this below:
------------------------
from Minikube: minikube service dotnet-demo-svc -n dotnet-demo-ns
verify deploy -- kubectl get all -n dotnet-demo-ns
check pod logs -- kubectl logs -n dotnet-demo-ns deploy/dotnet-demo
o/p -- Now listening on: http://[::]:8080

----Pod stuck in CrashLoopBackOff (quick fixes) ------
kubectl describe pod -n dotnet-demo-ns <pod-name>
kubectl logs -n dotnet-demo-ns <pod-name>
