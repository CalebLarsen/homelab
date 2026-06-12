#!/bin/bash
# Trigger a Kometa run by restarting its container via the Docker socket.
# Mounted into Radarr/Sonarr containers.

/usr/bin/curl --unix-socket /var/run/docker.sock -X POST http://localhost/v1.41/containers/kometa/restart
echo "Kometa restart triggered on import of $radarr_movie_title / $sonarr_series_title"
