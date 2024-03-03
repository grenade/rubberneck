#!/usr/bin/env bash

exit_code=$(systemctl show lava --property=ExecMainStatus)
echo "exit code: ${exit_code}"
