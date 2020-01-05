FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS build
WORKDIR /app

# copy csproj and restore as distinct layers
# COPY *.sln .
COPY dotnet-app/*.csproj ./dotnet-app/
RUN dotnet restore dotnet-app

# copy everything else and build app
COPY dotnet-app/. ./dotnet-app/
WORKDIR /app/dotnet-app
RUN dotnet publish -c Release -o out


FROM mcr.microsoft.com/dotnet/core/aspnet:3.1 AS runtime
WORKDIR /app
COPY --from=build /app/dotnet-app/out ./
ENTRYPOINT ["dotnet", "dotnet-app.dll"]