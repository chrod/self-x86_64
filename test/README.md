<img src="https://avatars0.githubusercontent.com/u/23140100?s=200&v=4" width="150">

### README.md
Readme for testing the Intu AI project deployment pattern. Intu/Self along with its associated edge deep learning workloads, can be executed on a Jetson TX2 using the script intu_pattern.sh

#### Requirements:
- Hardware [setup](https://github.com/chrod/self-jetsontx2/wiki/Getting-Started): NVIDIA Jetson TX2, webcam, USB Sound Card and Mic/Speaker
- Software: Latest JetPack3.1 (L4T28.1), and kernel rebuilt with the instructions in this [wiki](https://github.com/open-horizon/cogwerx-jetson-tx2/wiki)
- Kernel Module: For `intu_pattern.sh`, you'll need to build [umlauete's v4l2loopback](https://github.com/umlaeute/v4l2loopback) kernel module on the native system.  (requirement for 'vdealer', our little video brokering container) (not yet tested this pattern on TX1)
- IBM Cloud Services [setup](https://github.com/chrod/self-jetsontx2/wiki/Self:-Register-for-IBM-Watson-Cloud-Services): For Intu/Self AI, subscribe to IBM Cloud services (STT, TTS, Natural Language Processing...), and include these credentials in a bootstrap.json file. Copy the bootstrap.json file to the directory: self-jetsontx2/test/config/self.  (An example has been provided for you there)

#### Execution:
0. Configure your Jetson TX2 according to the requirements above
1. Test `v4l2loopback` on your Jetson TX2 to confirm it works (see examples at link above)
2. Clone this repo on your Jetson TX2 in the directory of your choice
3. Navigate to the local dir: self-jetsontx2/test
4. Change permissions of the script `chmod +x intu_pattern.sh`
5. Copy over your bootstrap.json file, containing IBM Cloud service credentials, to self-jetsontx2/test/config/self
6. Run the script with `./intu_pattern.sh start`. Intu and its related deep learning services will load.  (docker will pull workload containers as-needed the first time. This will take a while... some containers are 6GB+)
7. To interact with Intu, Browse to Intu's dashboard at http://<your TX2's local IP>:9443/www/dashboard#/ from another PC, or http://localhost:9443/www/dashboard#/ from the Jetson.
7. Stop the workload pattern with `./intu_pattern.sh stop`.  Docker containers will be shut down.

#### Tips and Troubleshooting:
- To monitor resource usage, docker container startup, and video device brokering, use the following commands in a terminal window:

| Command | Description |
|-|-|
| `htop` | Device resources  (device RAM and GPU RAM are lumped together) |
| `sudo ~/tegrastats` | RAM, CPU, GPU (GPU % load shows as 'GR3D', only when running with 'sudo') |
| `watch -n 1 ls /dev/video*` | Watch video devices come up and down as 'vdealer' allocates them |
| `watch -n 1 docker stats` | Watch docker containers come up and down, and resource utilization |

- Intu and face_classification will your webcam, which should show up as /dev/video1  (let us know if this turns out differently for you)
- Intu won't function without required credentials. See this [list]()
- Intu expects camera '6' as video input (a stream duplicate of /dev/video1->/dev/video6). This is defined in your bootstrap.json
- Intu expects audio device '2' as audio input (USB sound card).  This is defined in config/self/alsa.conf, which gets mapped into the intu docker container.  You can check to see that it's correct with `arecord -l` and `arecord -L` commands

