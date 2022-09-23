# Ribosome-P4
This repository contains the P4 implementation of Ribosome for Intel Tofino. 

# Project Structure
The main file is `rdma.p4`. It contains the implementation of the entire pipeline. 

The `ingress_controls` directory contains all the controls that Ribosome uses in the `Ingress` pipeline. 

The `egress_controls` directory contains all the controls that Ribosome uses in the `Egress` pipeline. 

The `include` directory contains parser and configuration files. 

The `run_pd_rpc` directory contains Python scripts for the control plane. 

