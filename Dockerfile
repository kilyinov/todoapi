FROM mcr.microsoft.com/dotnet/aspnet:5.0 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:5.0 AS build
WORKDIR /src

# DEBUG - Install donet debug tools
RUN dotnet tool install --tool-path /tools dotnet-trace
RUN dotnet tool install --tool-path /tools dotnet-counters
RUN dotnet tool install --tool-path /tools dotnet-dump

COPY "TodoApi.sln" "TodoApi.sln"
COPY "TodoApi/TodoApi.csproj" "TodoApi/TodoApi.csproj"

RUN dotnet restore "TodoApi.sln"

COPY . .
WORKDIR TodoApi
RUN dotnet publish -c Release -o /app

FROM build AS publish

FROM docker.io/appdynamics/dotnet-core-agent:21.5.1 AS appd

FROM base AS final
WORKDIR /app
COPY --from=publish /app .

# Copy appD files
RUN mkdir -p /opt/appdynamics
COPY --from=appd /opt/appdynamics/ /opt/appdynamics/

# DEBUG - Copy dotnet tools
COPY --from=build /tools /tools
ENV PATH="/tools:${PATH}"

# DEBUG - Install procdump step 0
RUN apt-get update && \
      apt-get install -y sudo nano zsh curl git wget gnupg procps
CMD /bin/bash

# DEBUG - Install procdump step 1
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.asc.gpg
RUN sudo mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/
RUN wget -q https://packages.microsoft.com/config/debian/10/prod.list
RUN sudo mv prod.list /etc/apt/sources.list.d/microsoft-prod.list
RUN sudo chown root:root /etc/apt/trusted.gpg.d/microsoft.asc.gpg
RUN sudo chown root:root /etc/apt/sources.list.d/microsoft-prod.list

# DEBUG - Install procdump step 2
RUN sudo apt-get update
RUN sudo apt-get install -y apt-transport-https
RUN sudo apt-get update
RUN sudo apt-get install -y procdump

ENV CORECLR_PROFILER={57e1aa68-2229-41aa-9931-a6e93bbc64d8} \
CORECLR_ENABLE_PROFILING=1 \
CORECLR_PROFILER_PATH=/opt/appdynamics/libappdprofiler.so \
ASPNETCORE_MODULE_DEBUG=TRACE \
LD_LIBRARY_PATH=/opt/appdynamics \
APPDYNAMICS_AGENT_APPLICATION_NAME=DotNetTest \
APPDYNAMICS_AGENT_TIER_NAME=todoapi \
APPDYNAMICS_CONTROLLER_SSL_ENABLED=true \
APPDYNAMICS_AGENT_REUSE_NODE_NAME=true \
APPDYNAMICS_AGENT_REUSE_NODE_NAME_PREFIX=node \
ENABLE_NLOG=true

#COPY ./TodoApi/AppDynamicsConfig.json /app/TodoApi.AppDynamicsConfig.json
COPY ./TodoApi/AppDynamicsConfig.json /opt/appdynamics/AppDynamicsConfig.json

ENTRYPOINT ["dotnet", "TodoApi.dll"]
