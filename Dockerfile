FROM mcr.microsoft.com/dotnet/aspnet:5.0 AS base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:5.0 AS build
WORKDIR /src

COPY "TodoApi.sln" "TodoApi.sln"
COPY "TodoApi/TodoApi.csproj" "TodoApi/TodoApi.csproj"

RUN dotnet restore "TodoApi.sln"

COPY . .
WORKDIR TodoApi
RUN dotnet publish -c Release -o /app

FROM build AS publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app .
ENTRYPOINT ["dotnet", "TodoApi.dll"]
