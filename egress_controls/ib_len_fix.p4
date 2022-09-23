#ifndef _IB_LEN_FIX_
#define _IB_LEN_FIX_

control IBLenFix(inout headers_t hdr) {
    apply {
        /* Update IPv4 and UDP length with payload length */
        hdr.ipv4.total_len = hdr.ipv4.total_len + hdr.ib_reth.dma_len2;
        hdr.udp.length = hdr.udp.length + hdr.ib_reth.dma_len2;
    }
}

#endif /* _IB_LEN_FIX_ */