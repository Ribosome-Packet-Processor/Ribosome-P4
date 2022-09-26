# Ribosome-P4
This repository contains the P4 implementation of Ribosome for Intel Tofino. 

# Project Structure
The main file is `ribosome.p4`. It contains the implementation of the entire pipeline. 

The `ingress_controls` directory contains all the controls that Ribosome uses in the `Ingress` pipeline. 

The `egress_controls` directory contains all the controls that Ribosome uses in the `Egress` pipeline. 

The `include` directory contains parser and configuration files. 

The `run_pd_rpc` directory contains Python scripts for the control plane. 

# How to Build
To build the code: 
```bash 
./p4_build.sh -DSPLIT=128 ~/labs/Ribosome-p4/ribosome.p4 #Do not split packets with "lenght <= SPLIT"
```
You can specify the `split threshold` modifying the value of `SPLIT`. This parameter set the threshold under which 
Ribosome does not split the packets. The threshold is expressed in `Byte`. 

# Add/Remove RDMA servers
This implementation of Ribosome leverages on RDMA servers as external buffers for payloads. 

The number of RDMA servers is set to 4. 
To add or remove servers you have to: 

1. Edit the `include/configuration.p4` file, specifying the number of desired servers: 
    ```p4
    #define NUMBER_OF_SERVERS 3 
    ```
2. Recompile the p4 code. 

# Specify how many bits should be sent to the NF
You can set the number of bits to send to the NF. To do so, you have to: 

1. Edit the `include/configuration.p4` file, specifying the number of desired servers:
    ```p4
    #define PKT_MIN_LENGTH 71
    ```
2. Edit the `setup.py` file, specifying the size of the `PKT_MIN_LENGTH` variable: 
    ```python3
    #################################
    ##### MIRROR SESSIONS TABLE #####
    #################################
    # In this section, we setup the mirror sessions of Ribosome.
    # One session is used to truncate/send the headers to the NF.
    # Other NUMBER_OF_SERVERS are used to send QP Refresh Packets to the proper RDMA server.
    PKT_MIN_LENGTH = 71
    ```
3. Recompile the p4 code.

# Configure the Ports
You can find ports configuration in the `include/configuration.p4` file. Here you can set the port towards the NF and 
the RDMA servers. 
If you make changes, you need to update the ports value in the `run_pd_rpc/setup.py` file accordingly. 

The outport ports specified in the files are used to send out the traffic after being processed. 
The current implementation sends out the packets selecting randomly one of the four output ports. 
To modify this behaviour you can:
1. Modify the sending rules of packets not split: editing the `ingress_control/default_switch` file.
2. Modify the sending rules of reconstructed packets: editing the `ingress_control/packet_reconstruct.p4` file. 

# Specify traffic classes to not split
You can add entries from the `blacklist` table to disable payload splitting on specific traffic classes.
You can set up the `blacklist` table from the `setup.py` file:
```python3
###########################
##### BLACKLIST TABLE #####
###########################
# This function setups the entries in the blacklist table.
# You can add/edit/remove entries to disable payload splitting on specific traffic classes.
def setup_blacklist_table():
    from ipaddress import ip_address
    global p4, NF_PORT

    blacklist_table = p4.Ingress.blacklist
    blacklist_table.clear()

    blacklist_table.add_with_drop(dst_addr=ip_address('224.0.0.0'), dst_addr_p_length=16)
    blacklist_table.add_with_send(dst_addr=ip_address('10.0.0.1'), dst_addr_p_length=32, port=0)
```
