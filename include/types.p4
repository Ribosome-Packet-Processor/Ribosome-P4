#ifndef _TYPES_
#define _TYPES_

/* IP Addresses */
#define RDMA_IP 0xc0a828fe

/* Stores L4 ports */
struct l4_lookup_t {
    bit<16> src_port;
    bit<16> dst_port;
}

/* Ethernet */
enum bit<16> ether_type_t {
    IPV4 = 0x0800,
    IPV6 = 0x86DD,
    RDMA_INFO = 0x1234,
    CLIENT_QP_REFRESH = 0x4321
}

typedef bit<48> mac_addr_t;

/* RDMA Info */
enum bit<8> rdma_info_code_t {
    QP = 0x00,
    MEM = 0x01,
    ETH = 0x02
}

/* IPv4 */
enum bit<8> ipv4_protocol_t {
    TCP = 0x06,
    UDP = 0x11
}

typedef bit<32> ipv4_addr_t;

/* InfiniBand */
enum bit<8> ib_opcode_t {
    RDMA_READ_RESPONSE = 0x10,
    RDMA_ACK = 0x11,
    RDMA_WRITE = 0x0a,
    RDMA_READ = 0x0c,
    NOOP = 0xff
}

const bit<16> UDP_PORT_ROCEV2 = 4791;

/* Payload Splitter Marker */
const bit<32> PAYLOAD_SPLITTER_MARKER = 0x55991177;

/* Payload Buffer registered on RDMA connection (2GB) */
const bit<32> MAX_BUFFER_SIZE = 0x80000000;

/* Mirroring */
typedef bit<8> pkt_type_t;
const pkt_type_t PKT_TYPE_MIRROR_TRUNCATE = 0xfe;
const pkt_type_t PKT_TYPE_MIRROR_QP_RESTORE = 0xff;

typedef bit<3> mirror_type_t;
const mirror_type_t TRUNCATE_MIRROR_TYPE = 1;
const mirror_type_t QP_RESTORE_MIRROR_TYPE = 2;

const MirrorId_t TRUNCATE_MIRROR_SESSION = 100;
const MirrorId_t QP_RESTORE_MIRROR_SESSION = 200;

#endif /* _TYPES_ */