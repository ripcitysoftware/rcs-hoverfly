#!/bin/bash

RCS_DEBUG=${RCS_DEBUG:-0}
[[ $RCS_DEBUG -gt 0 ]] && set -x

HOVERFLY_MODE=${HOVERFLY_MODE:-capture}
HOVERFLY_JSON=${HOVERFLY_JSON:-simulation.json}
HOVERFLY_JSON_PATH="/hoverfly/output/$HOVERFLY_JSON"
CUSTOM_SCRIPT=${CUSTOM_SCRIPT:-none}
CUSTOM_SCRIPT_PATH=/hoverfly/script/${CUSTOM_SCRIPT:-none}

if [ -z "$HOVERFLY_MODE" ] || [[ ! "$HOVERFLY_MODE" =~ ^(capture|simulate)$ ]]; then
  echo "You provided the wrong value for HOVERFLY_MODE, valid values are:"
  echo "capture or simulate, you specified '$HOVERFLY_MODE'"
  exit 1
fi

if [ "$HOVERFLY_MODE" == "simulation" ] && [[ ! -f "$HOVERFLY_JSON_PATH" ]]; then
    echo "The simulation file you specified $HOVERFLY_JSON_PATH cannot be found."
    ls -alFs /hoverfly/output
    exit 1
fi

if [[ $CUSTOM_SCRIPT != "none" ]] && [[ ! -x $CUSTOM_SCRIPT_PATH ]]; then
  echo "Cannot find custom script: ${CUSTOM_SCRIPT} OR it's not executable"
  echo "Did you map a local directory with ${CUSTOM_SCRIPT} to the /hoverfly/script volume?"
  echo "If you mapped the volume correctly, make sure your scirpt has the executable bit set."
  exit 1
fi

# http://blog.milesmaddox.com/2016/10/31/Docker_Shutdown_Hooks/
function gracefulShutdown {
    echo "shutting down!"
    if [ "$HOVERFLY_MODE" == "capture" ]; then
      echo "writing simulation output to $HOVERFLY_JSON"
      /hoverfly/hoverctl export $HOVERFLY_JSON_PATH
      /hoverfly/hoverctl stop
      echo "termination of hoverfly complete!"
      exit 143;
    else
      echo "ending hoverfly simulation"
      exit 143;
    fi
}

# trigger function on SIGTERM (aka graceful shutdown)
trap gracefulShutdown SIGTERM


if [ "$HOVERFLY_MODE" == "capture" ]; then
    echo "starting hoverfly"
    /hoverfly/hoverctl start --listen-on-host=0.0.0.0
    echo "when exported, the simulation output will be written to: $HOVERFLY_JSON"
    /hoverfly/hoverctl mode capture
else
    echo "starting hoverfly webserver"
    /hoverfly/hoverctl start webserver --listen-on-host=0.0.0.0
    echo "running hoverfly in simulation mode, using simulation file: $HOVERFLY_JSON_PATH"
    /hoverfly/hoverctl import $HOVERFLY_JSON_PATH
    echo "hoverfly in simulation mode"
fi

if [ "$CUSTOM_SCRIPT" == "none" ]; then
  # https://medium.com/@gchudnov/trapping-signals-in-docker-containers-7a57fdda7d86
  while true; do
    tail -f /dev/null & wait ${!}
  done
else
  echo "running custom script: ${CUSTOM_SCRIPT}"
  $CUSTOM_SCRIPT_PATH
  gracefulShutdown
fi