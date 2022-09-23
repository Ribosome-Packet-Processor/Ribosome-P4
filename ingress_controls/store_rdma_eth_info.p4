#ifndef _STORE_RDMA_ETH_INFO_
#define _STORE_RDMA_ETH_INFO_

#include "../include/registers.p4"

control StoreRDMAEthInfo(inout headers_t hdr, in ingress_intrinsic_metadata_t ig_intr_md) {
    RegisterAction<bit<16>, _, bit<16>>(server_port) server_port_write = {
        void apply(inout bit<16> value, out bit<16> read_value) {
            value = (bit<16>) ig_intr_md.ingress_port;
        }
    };

    RegisterAction<bit<16>, _, bit<16>>(server_mac_address_1) server_mac_address_1_write = {
        void apply(inout bit<16> value, out bit<16> read_value) {
            value = hdr.rdma_eth_info.mac_address1;
        }
    };
    RegisterAction<bit<32>, _, bit<32>>(server_mac_address_2) server_mac_address_2_write = {
        void apply(inout bit<32> value, out bit<32> read_value) {
            value = hdr.rdma_eth_info.mac_address2;
        }
    };

    RegisterAction<ipv4_addr_t, _, ipv4_addr_t>(server_ip_address) server_ip_address_write = {
        void apply(inout ipv4_addr_t value, out ipv4_addr_t read_value) {
            value = hdr.rdma_eth_info.ip_address;
        }
    };

    apply {
        if (hdr.rdma_eth_info.isValid()) {
            server_port_write.execute(hdr.rdma_eth_info.server_id);

            server_mac_address_1_write.execute(hdr.rdma_eth_info.server_id);
            server_mac_address_2_write.execute(hdr.rdma_eth_info.server_id);

            server_ip_address_write.execute(hdr.rdma_eth_info.server_id);
        }
    }
}

#endif /* _STORE_RDMA_ETH_INFO_ */