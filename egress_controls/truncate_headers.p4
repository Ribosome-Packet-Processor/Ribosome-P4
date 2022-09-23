#ifndef _TRUNCATE_HEADERS_
#define _TRUNCATE_HEADERS_

#include "../include/types.p4"
#include "../include/configuration.p4"

control TruncateHeaders(inout headers_t hdr, inout eg_metadata_t meta) {
    apply {
        hdr.ethernet.src_addr[7:0] = 0x1;
        hdr.ethernet.dst_addr_2[7:0] = meta.mirror_truncate.server_index[7:0];
        hdr.ethernet.dst_addr_2[15:8] = meta.mirror_truncate.server_qp_index[7:0];

        hdr.payload_splitter.setValid();
        hdr.payload_splitter.marker = PAYLOAD_SPLITTER_MARKER;
        hdr.payload_splitter.payload_address = meta.mirror_truncate.payload_addr;
        hdr.payload_splitter.payload_len = meta.mirror_truncate.payload_len;
        hdr.payload_splitter.server_qp_index = meta.mirror_truncate.server_qp_index;
        hdr.payload_splitter.server_index = meta.mirror_truncate.server_index;

        hdr.payload_request.setValid();
        hdr.payload_request.padding = 0x0;
        hdr.payload_request.hdr_idx = meta.mirror_truncate.hdr_idx;

        hdr.ipv4.total_len = PKT_MIN_LENGTH - meta.mirror_truncate.minSizeInBytes() - hdr.ethernet.minSizeInBytes() +
            hdr.payload_splitter.minSizeInBytes() + hdr.payload_request.minSizeInBytes();

        if (hdr.udp.isValid()) {
            hdr.udp.length = PKT_MIN_LENGTH - meta.mirror_truncate.minSizeInBytes() - hdr.ethernet.minSizeInBytes() -
                 hdr.ipv4.minSizeInBytes() + hdr.payload_splitter.minSizeInBytes() + hdr.payload_request.minSizeInBytes();
        }
    }
}

#endif /* _TRUNCATE_HEADERS_ */