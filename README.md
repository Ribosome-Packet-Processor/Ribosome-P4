# Ribosome-P4
This repository contains the P4 implementation of Ribosome for Intel Tofino. 

This implementation is tested with **SDE 9.7.0**.

## Project Structure

The main file is `ribosome.p4`. It contains the implementation of the entire pipeline. 

The `ingress_controls` directory contains all the controls that Ribosome uses in the `Ingress` pipeline. 

The `egress_controls` directory contains all the controls that Ribosome uses in the `Egress` pipeline. 

The `parsers` directory contains both the Ingress Parser/Deparser and Egress Parser/Deparser.

The `include` directory contains parser and configuration files. 

The file `setup.py` contains a `bfrt_python` script that configures ports, mirroring, and other several callbacks for the program.

## How to Build

Example command to build the code, it can vary depending on your SDE installation: 
```bash 
./p4_build.sh -DSPLIT=128 ribosome.p4 # Do not split packets with "length <= SPLIT"
```
You can specify the split threshold modifying the value of `SPLIT`. This parameter sets the threshold under which Ribosome does not split the packets. The threshold is expressed in bytes. 

You can add a custom split threshold by editing the `parsers/ingress_parser.p4` file, in the `check_ip_len` state.

## Requirements 

Before running Ribosome code, you need to fill the `access.txt` file with the commands to append 4 bytes (used as RDMA iCRC) at the end of packets.
In this repository, commands have been removed as they are under NDA.

## How to Run

Example commands to run Ribosome, they can vary depending on your SDE installation.
On a terminal, run `switchd`:
```bash 
$SDE/run_switchd.sh -p ribosome
```
On another terminal, launch the `setup.py` script using `bfshell`:
```bash 
$SDE/run_bfshell.sh -i -b /absolute/path/to/setup.py
```

## How to Configure Ribosome

### Add/Remove RDMA servers
This implementation of Ribosome leverages on RDMA servers as external buffers for payloads. 

The number of RDMA servers is set to 4. 
To add or remove servers, you have to: 

1. Edit the `include/configuration.p4` file, specifying the number of desired servers, for example: 

    ```p4
    #define NUMBER_OF_SERVERS 3 
    ```
2. Edit the `NUMBER_OF_SERVERS` variable in the `setup.py` file, specifying the new number of desired servers:
    ```python
    NUMBER_OF_SERVERS = 3
    ```
3. Recompile the P4 code. 

### Set Queue-Pairs numbers

This implementation of Ribosome leverages on 32 Queue-Pairs for each RDMA server connection.

To change the number of Queue-Pairs, you have to:

1. Edit the `include/configuration.p4` file, specifying the number of desired QPs, for example:

    ```p4
    #define MAX_QP_NUM 16
    ```
2. Edit the `MAX_QP_NUM` variable in the `setup.py` file, specifying the new number of desired QPs:
    ```python
    MAX_QP_NUM = 16
    ```
3. Recompile the P4 code.

### Specify how many bytes should be sent to the NF
You can set the number of bytes to send to the NF. To do so, you have to: 

1. Edit the `include/configuration.p4` file, specifying the length in bytes of the packet copy to send to the NF:

    ```p4
    #define PKT_MIN_LENGTH 71
    ```
2. Edit the `setup.py` file, changing the `PKT_MIN_LENGTH` variable: 

    ```python3
    #################################
    ##### MIRROR SESSIONS TABLE #####
    #################################
    # In this section, we setup the mirror sessions of Ribosome.
    # One session is used to truncate/send the headers to the NF.
    # Other NUMBER_OF_SERVERS are used to send QP Refresh Packets to the proper RDMA server.
    PKT_MIN_LENGTH = 71
    ```
3. Recompile the P4 code.

### Configure the Ports
You can find ports configuration in the `include/configuration.p4` file. Here you can set the port towards the NF and 
the RDMA servers. 
If you make changes, you need to update the ports value in the `setup.py` file accordingly. 

The outport ports specified in the files are used to send out the traffic after being processed. 
The current implementation sends out the packets randomly selecting one of the four output ports. 
To modify this behaviour you can:
1. Modify the sending rules of packets not split: editing the `ingress_control/default_switch.p4` file.
2. Modify the sending rules of reconstructed packets: editing the `ingress_control/packet_reconstruct.p4` file. 

:warning: If you add a new server, you also have to update the `SERVER_PORT_TO_IDX` dict in the `setup.py` file, specifying which Server IDX should be used to send QP Restore packets towards that server. More information about the Server IDX can be found in the [RDMA Server Agent repository](https://github.com/Ribosome-Packet-Processor/Ribosome-RDMA-Server-Agent).

### Specify traffic classes to not split
You can add entries to the `blacklist` table to disable payload splitting on specific traffic classes.
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
