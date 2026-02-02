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

#ENV ASPNETCORE_URLS=http://0.0.0.0:8080
ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Development

COPY --from=build /app/publish .

#EXPOSE 8080
EXPOSE 5000

ENTRYPOINT ["dotnet", "DockerDotNetDemo.Api.dll"]

