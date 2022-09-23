#ifndef _REGISTERS_
#define _REGISTERS_

#include "configuration.p4"

/* QP Status Registers */
Register<bit<32>, _>(TOTAL_QP) qp;
Register<bit<16>, _>(TOTAL_QP) enabled_qp;
Register<bit<1>, _>(TOTAL_QP) restore_qp;
/* Sequence Number and other RDMA Data */
Register<bit<32>, _>(TOTAL_QP) seq_n;
Register<bit<32>, _>(NUMBER_OF_SERVERS) remote_address_1;
Register<bit<32>, _>(NUMBER_OF_SERVERS) remote_address_2;
Register<bit<32>, _>(NUMBER_OF_SERVERS) remote_key;
/* Server interfaces info */
Register<bit<16>, _>(NUMBER_OF_SERVERS) server_mac_address_1;
Register<bit<32>, _>(NUMBER_OF_SERVERS) server_mac_address_2;
Register<ipv4_addr_t, _>(NUMBER_OF_SERVERS) server_ip_address;
Register<bit<16>, _>(NUMBER_OF_SERVERS) server_port;

/* Current QP to use, this is a RR counter */
Register<bit<16>, _>(1) current_qp;

/* Memory Region current offset */
Register<bit<32>, _>(NUMBER_OF_SERVERS) memory_offset;
Register<bit<32>, _>(NUMBER_OF_SERVERS) add_memory_offset;

/* Current index where store headers */
Register<bit<16>, _>(1) hdr_index;

/* Registers to temporary store headers before receiving RDMA READ */
Register<bit<32>, _>(HEADER_REGISTER_SIZE) hdr_block_0;
Register<bit<32>, _>(HEADER_REGISTER_SIZE) hdr_block_1;
Register<bit<32>, _>(HEADER_REGISTER_SIZE) hdr_block_2;
Register<bit<32>, _>(HEADER_REGISTER_SIZE) hdr_block_3;
Register<bit<32>, _>(HEADER_REGISTER_SIZE) hdr_block_4;
Register<bit<32>, _>(HEADER_REGISTER_SIZE) hdr_block_5;
Register<bit<32>, _>(HEADER_REGISTER_SIZE) hdr_block_6;
Register<bit<32>, _>(HEADER_REGISTER_SIZE) hdr_block_7;
Register<bit<32>, _>(HEADER_REGISTER_SIZE) hdr_block_8;
Register<bit<32>, _>(HEADER_REGISTER_SIZE) hdr_block_9;
Register<bit<16>, _>(HEADER_REGISTER_SIZE) hdr_block_10;
Register<bit<16>, _>(HEADER_REGISTER_SIZE) hdr_block_11;
Register<bit<32>, _>(HEADER_REGISTER_SIZE) hdr_block_12;
Register<bit<32>, _>(HEADER_REGISTER_SIZE) hdr_block_13;
Register<bit<16>, _>(HEADER_REGISTER_SIZE) hdr_block_14;

#endif /* _REGISTERS_ */