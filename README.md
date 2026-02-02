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
          image: dotnet-docker-demo:latest
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
          env:
            - name: ASPNETCORE_URLS
              value: http://0.0.0.0:8080
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
  type: NodePort
  selector:
    app: dotnet-demo
  ports:
    - port: 80
      targetPort: 8080
      nodePort: 30080

note: http://<NODE-IP>:30080/swagger

from Minikube: minikube service dotnet-demo-svc -n dotnet-demo-ns
verify deploy -- kubectl get all -n dotnet-demo-ns
check pod logs -- kubectl logs -n dotnet-demo-ns deploy/dotnet-demo
o/p -- Now listening on: http://[::]:8080

----Pod stuck in CrashLoopBackOff (quick fixes) ------
kubectl describe pod -n dotnet-demo-ns <pod-name>
kubectl logs -n dotnet-demo-ns <pod-name>
