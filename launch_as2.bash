#!/bin/bash

usage() {
    echo "  options:"
    echo "      -s: simulated, choices: [true | false]"
    echo "      -g: use GPS, choices: [true | false]"
    echo "      -e: estimator_type, choices: [raw_odometry, mocap_pose]"
    echo "      -r: record rosbag"
    echo "      -t: launch keyboard teleoperation"
    echo "      -n: drone namespace, default is drone0"
}

# Arg parser
while getopts ":sge:rtn:" opt; do
  case ${opt} in
    s )
      simulated="true"
      ;;
    g )
      gps="true"
      ;;
    e )
      estimator_plugin="${OPTARG}"
      ;;
    r )
      record_rosbag="true"
      ;;
    t )
      launch_keyboard_teleop="true"
      ;;
    n )
      drone_namespace="${OPTARG}"
      ;;
    \? )
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
    : )
      if [[ ! $OPTARG =~ ^[sgrt]$ ]]; then
        echo "Option -$OPTARG requires an argument" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

source utils/tools.bash

# Shift optional args
shift $((OPTIND -1))

## DEFAULTS
simulated=${simulated:="false"}
gps=${gps:="false"}
estimator_plugin=${estimator_plugin:="raw_odometry"}
record_rosbag=${record_rosbag:="false"}
launch_keyboard_teleop=${launch_keyboard_teleop:="false"}
drone_namespace=${drone_namespace:="drone"}

if [[ ${simulated} == "true" ]]; then
  simulation_config="sim_config/world.json"
fi

# Generate the list of drone namespaces
drone_ns=()
num_drones=1
for ((i=0; i<${num_drones}; i++)); do
  drone_ns+=("$drone_namespace$i")
done

for ns in "${drone_ns[@]}"
do
  if [[ ${ns} == ${drone_ns[0]} ]]; then
    base_launch="true"
  else
    base_launch="false"
  fi 

  tmuxinator start -n ${ns} -p utils/aerostack.yml drone_namespace=${ns} gps=${gps} simulation=${simulated} estimator_plugin=${estimator_plugin} &
  wait
done

if [[ ${estimator_plugin} == "mocap_pose" ]]; then
  tmuxinator start -n mocap -p tmuxinator/mocap.yml &
  wait
fi

if [[ ${record_rosbag} == "true" ]]; then
  tmuxinator start -n rosbag -p utils/rosbag.yml drone_namespace=$(list_to_string "${drone_ns[@]}") &
  wait
fi

if [[ ${launch_keyboard_teleop} == "true" ]]; then
  tmuxinator start -n keyboard_teleop -p utils/keyboard_teleop.yml simulation=${simulated} drone_namespace=$(list_to_string "${drone_ns[@]}") &
  wait
fi

# if [[ ${simulated} == "true" ]]; then
#   tmuxinator start -n gazebo -p utils/gazebo.yml simulation_config=${simulation_config} &
#   wait
# fi

# Attach to tmux session ${drone_ns[@]}, window 0
tmux attach-session -t ${drone_ns[0]}:mission

#ros2 service call /drone0/platform_takeoff std_srvs/srv/SetBool "{data: True}"
#ros2 service call /drone0/set_arming_state std_srvs/srv/SetBool "{data: True}"
#ros2 service call /drone0/platform/state_machine_event as2_msgs/srv/SetPlatformStateMachineEvent "{event: {event: 2}}"
#