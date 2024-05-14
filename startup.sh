#!/usr/bin/env sh

LOCAL_PUID="${PUID:-1000}"
LOCAL_PGID="${PGID:-1000}"

echo "Creating a new group app with the ID ${LOCAL_PGID} ..."
grep -q -E ":${LOCAL_PGID}:" /etc/group || addgroup --gid "${LOCAL_PGID}" "app"

if [ $? -ne 0 ]
then
    echo "Cannot create the user app, please check the previous errors."
    exit 1
fi

echo "Creating a new user app with the ID ${LOCAL_PUID} ..."
grep -q -E ":${LOCAL_PUID}:" /etc/passwd || adduser --shell /bin/sh --uid "${LOCAL_PUID}" --home "/app" --gid $LOCAL_PGID --no-create-home --disabled-password --disabled-login --gecos "" "app"

if [ $? -ne 0 ]
then
    echo "Cannot create the group app, please check the previous errors."
    exit 1
fi

su - app
locale-gen && /app/bin/teslamate_philips_hue_gradient_signe_table_lamp start