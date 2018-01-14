#!/bin/bash
### Starts Intu container pattern, as deployed on Horizon
### input args:  $1="start|stop"

###########################
### Global variables (docker network name, container names, etc)
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
SYSTEM_ARCH=$(uname -m | sed -e 's/aarch64.*/arm64/' -e 's/x86_64.*/x86/' -e 's/armv.*/arm/')
echo "system_arch=$SYSTEM_ARCH"

## docker networks
intu_ntwk_name="intu-ntwk"

## docker images and container names
# video device broker
vid_cntnr_name="vdealer-intu"
vid_cntnr_img="openhorizon/$SYSTEM_ARCH-vdealer"

# face emotion classification (DL, video)
face_cntnr_img="openhorizon/$SYSTEM_ARCH-face-classification-intu:JetPack3.2-RC"
face_cntnr_name="face-emo-intu"
face_cfg_path="$SCRIPTPATH/config/face_classification/src"

# aural2 (DL, audio)
aural2_cntnr_img="openhorizon/$SYSTEM_ARCH-aural2-intu:test"
aural2_cntnr_name="aural2-intu"

# intu/self (embodiment)
intu_cntnr_img="openhorizon/$SYSTEM_ARCH-intu-self:edge"
intu_cntnr_name="intu-self"
intu_cfg_path="$SCRIPTPATH/config/self"

##############################
## Functions

# function to remove docker network if it exists
docker_network_remove() {
   network_name="$1"
   networks=`docker network ls | awk '{print $2}' | xargs | sed -e 's/ /,/g'`
   #echo $networks
   if [[ $networks == *"$network_name"* ]]; then
      docker network rm "$network_name"
   fi
}

# function to create docker network after checking if present, and removing existing
docker_network_create() {
   network_name="$1"
   echo "Creating docker network $network_name"
   docker_network_remove $network_name
   docker network create -d bridge "$network_name"
}

docker_container_stop_if_running() {

   container_name="$1"
   container=`docker ps -q -f name=$container_name`
   if [[ -n "${container// }" ]]; then   # container name found
   echo "docker container $container_name has exited. Stopping it..."
      docker stop "$container"
   fi
   container=`docker ps -aq -f name=$container_name`
   if [[ -n "${container// }" ]]; then
      echo "docker container $container_name has exited. Removing it..."
      docker rm "$container"
   fi
}

# function to start all required services, then Intu container itself
start() {
   ## Start streaming video endpoint container
   docker_container_stop_if_running $vid_cntnr_name
   echo "Starting container $vid_cntnr_name"
   docker run --name $vid_cntnr_name -td --rm --privileged --ipc=host --cap-add=ALL -v /dev:/dev -v /lib/modules:/lib/modules $vid_cntnr_img

   ## Create/remove Docker network for Intu
   docker_network_create $intu_ntwk_name
 
   ## Start Intu container
   sleep 1
   docker_container_stop_if_running $intu_cntnr_name
   echo "Starting container $intu_cntnr_name"
   docker run --name $intu_cntnr_name -td --rm --privileged -p 9443:9443 --net=$intu_ntwk_name -v $intu_cfg_path:/configs $intu_cntnr_img /bin/bash -c "ln -s -f /configs/bootstrap.json bin/linux/etc/shared/; ln -s -f /configs/alsa.conf /usr/share/alsa/; ./bin/linux/run_self.sh"

   ## Start face-classification container
   docker_container_stop_if_running $face_cntnr_name
   script_and_args="face_emotion.py -intu camera 6"
   if [ "$display" = true ]; then
      echo "Running face_classification without intu, with display window $display" 
      export DISPLAY=:0   
      script_and_args="face_emotion.py camera 6"
   fi
   echo "Starting container $face_cntnr_name, cmd=$script_and_args"
   export DISPLAY=:0
   xhost + && docker run --name $face_cntnr_name -td --rm --privileged --net=$intu_ntwk_name --ipc=host --cap-add=ALL -e DISPLAY=$DISPLAY -v /dev:/dev -v /tmp/.X11-unix:/tmp/.X11-unix -v $face_cfg_path:/root/src/face_classification/src $face_cntnr_img python3 $script_and_args

   ## Start Aural2 container
   docker_container_stop_if_running $aural2_cntnr_name
   echo "Starting container $aural2_cntnr_name"
   #docker run --name XXXXX -td --rm ...
}

stop() {
   
   ## Stop docker workloads
   docker_container_stop_if_running $intu_cntnr_name
   docker_container_stop_if_running $face_cntnr_name
   docker_container_stop_if_running $vid_cntnr_name
   docker_container_stop_if_running $aural2_cntnr_name

   ## Stop docker network(s)
   docker_network_remove $intu_ntwk_name
}

test() {
	
   echo "script path=$SCRIPTPATH"
   ## tests (remake)
   docker_network_create "test-network"
   echo "test network created"
   docker network ls
   docker network rm "test-network"
   echo "test network removed"
   docker network ls

   ## test container functions

}


### Main routine
usage="Usage: $0 {start|stop|test} display [optional, to show face-classification window]"
start_stop=$1
display=$2

# Notify user of display mode
echo "display=$display..."
if [[ $display == *"dis"* ]]; then
   echo "it's there!"
   display=true  # display used as bool (true/false) from now on
fi

# Execute the chosen option
if [[ -n "$start_stop" ]]; then
   case "$start_stop" in
       start)
            start
            ;;
       stop)
            stop
            ;;
       test)
            test
            ;;
       *)
            echo $"Usage: $0 {start|stop|test}"
            exit 1
esac
else
   echo "Usage: $0 {start|stop|test}"
fi

# Exit script
exit 0

