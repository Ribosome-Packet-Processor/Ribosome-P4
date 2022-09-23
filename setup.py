import time
import json
import os
import subprocess

p4 = bfrt.rdma.pipe

# Pipe where Ribosome is running
PIPE_NUM = 0

# Port defines
NF_PORT = 36
SERVER_1_PORT = 0
SERVER_2_PORT = 20
SERVER_3_PORT = 16
SERVER_4_PORT = 32
SERVER_PORT_TO_IDX = {
    SERVER_1_PORT: 0,
    SERVER_2_PORT: 1,
    SERVER_3_PORT: 2,
    SERVER_4_PORT: 3
}

# Queue Pairs and Servers information
MAX_QP_NUM = 32
NUMBER_OF_SERVERS = 4
TOTAL_QP = MAX_QP_NUM * NUMBER_OF_SERVERS

# Path of the run_pd_rpc.py tool, should be changed to match local environment
RUN_PD_RPC_PATH = os.path.join("/home", "tofino", "tools", "run_pd_rpc.py")


def run_pd_rpc(cmd_or_code, no_print=False):
    """
    This function invokes run_pd_rpc.py tool. It has a single string argument
    cmd_or_code that works as follows:
       If it is a string:
            * if the string starts with os.sep, then it is a filename
            * otherwise it is a piece of code (passed via "--eval"
       Else it is a list/tuple and it is passed "as-is"

    Note: do not attempt to run the tool in the interactive mode!
    """
    import subprocess, RUN_PD_RPC_PATH

    command = [RUN_PD_RPC_PATH]
    if isinstance(cmd_or_code, str):
        if cmd_or_code.startswith(os.sep):
            command.extend(["--no-wait", cmd_or_code])
        else:
            command.extend(["--no-wait", "--eval", cmd_or_code])
    else:
        command.extend(cmd_or_code)

    result = subprocess.check_output(command).decode("utf-8")[:-1]
    if not no_print:
        print(result)

    return result


######################
##### PORT STATS #####
######################
# This section creates a timer that calls a callback to dump and print port stats.
# In particular, it dumps both RX/TX bps and pps from the NF server and from RDMA Server 1.
tolog = {
    '$OctetsTransmittedTotal': 'TX',
    '$OctetsReceived': 'RX',
    '$FramesReceivedAll': 'RXPPS',
    '$FramesTransmittedAll': 'TXPPS'
}
last = {}
last_srv = {}
for k in tolog.keys():
    last[k] = 0
    last_srv[k] = 0

start_ts = time.time()


def dump_counters():
    global bfrt, last, last_srv, start_ts, time, tolog, NF_PORT, SERVER_1_PORT

    port_stats = bfrt.port.port_stat.dump(from_hw=1, json=1)
    port_stats = json.loads(port_stats)

    ts = time.time() - start_ts

    nf_port_stats = list(filter(lambda x: x['key']['$DEV_PORT'] == NF_PORT, port_stats))[0]
    for key, name in tolog.items():
        val = nf_port_stats['data'][key]
        diff = val - last[key]
        last[key] = val
        print("TOF-%f-RESULT-TOF%s %d" % (ts, name, diff))

    rdma_server_stats = list(filter(lambda x: x['key']['$DEV_PORT'] == SERVER_1_PORT, port_stats))[0]
    for key, name in tolog.items():
        val = rdma_server_stats['data'][key]
        diff = val - last_srv[key]
        last_srv[key] = val
        print("SRV1-%f-RESULT-SRV1%s %d" % (ts, name, diff))


def counters_timer():
    import threading

    global counters_timer, dump_counters
    dump_counters()
    threading.Timer(1, counters_timer).start()


######################
##### QP RESTORE #####
######################
# This section creates a timer that calls a callback to restore disabled QPs.
# In particular, it reads the enabled_qp register and filters out the entries with value = 0.
# For each of such entries, it then set to 1 the relative entry in the restore_qp register.
def set_restore_qp():
    global p4, PIPE_NUM

    enabled_qp_register = p4.enabled_qp
    restore_qp_register = p4.restore_qp
    queue_pairs_register = p4.qp

    enabled_qp_register_entries = enabled_qp_register.dump(from_hw=1, json=1)
    if enabled_qp_register_entries is not None:
        enabled_qp_register_entries = json.loads(enabled_qp_register_entries)
        disabled_qps = list(filter(lambda x: x["data"]["enabled_qp.f1"][PIPE_NUM] == 0, enabled_qp_register_entries))
        print("There are %d disabled QPs" % len(disabled_qps))

        if len(disabled_qps) > 0:
            qp_register_entries = queue_pairs_register.dump(from_hw=1, json=1)
            if qp_register_entries is not None:
                qp_register_entries = json.loads(qp_register_entries)

            for disabled_qp in disabled_qps:
                register_idx = disabled_qp["key"]["$REGISTER_INDEX"]
                qp_num = qp_register_entries[register_idx]['data']['qp.f1'][PIPE_NUM]

                if qp_num > 0:
                    restore_qp_register.add(f1=1, REGISTER_INDEX=register_idx)


def restore_qp_timer():
    import threading

    global restore_qp_timer, set_restore_qp
    set_restore_qp()
    threading.Timer(1, restore_qp_timer).start()


##############################
##### OVERLOADED SERVERS #####
##############################
# This section creates a timer that calls a callback that check RDMA servers links bandwidth utilization.
# When a link carries above a user-configured back-off RDMA threshold (PORT_THRESHOLD),
# the system stops sending payloads to the overloaded server.
PORT_THRESHOLD = 50000000000  # 50Gbps

prev_port_rate = {
    key: 0 for key in SERVER_PORT_TO_IDX.keys()
}

active_server_indexes = list(SERVER_PORT_TO_IDX.values())


def disable_overloaded_servers():
    global bfrt, p4, NUMBER_OF_SERVERS, MAX_QP_NUM, SERVER_PORT_TO_IDX, PORT_THRESHOLD, prev_port_rate, \
        active_server_indexes

    port_stats = bfrt.port.port_stat.dump(from_hw=1, json=1)
    port_stats = json.loads(port_stats)

    qp_mapping_sel = p4.Ingress.qp_mapping_sel
    # qp_mapping_table = p4.Ingress.qp_mapping

    servers_port_stats = list(filter(lambda x: x['key']['$DEV_PORT'] in SERVER_PORT_TO_IDX.keys(), port_stats))
    for stats in servers_port_stats:
        server_port = stats['key']['$DEV_PORT']
        server_idx = SERVER_PORT_TO_IDX[server_port]

        current_rate = stats['data']['$OctetsTransmittedTotal']
        if prev_port_rate[server_port] <= 0:
            continue

        port_bps = (current_rate - prev_port_rate[server_port]) * 8
        if port_bps > PORT_THRESHOLD:
            if server_idx in active_server_indexes:
                print(f"Server {server_idx} overloaded.")
                active_server_indexes.remove(server_idx)

                qp_mapping_profile.mod_with_to_qp_and_server(
                    qp=offset_qp_idx, selected_qp=new_qp_idx, selected_server=active_server_indexes[i]
                )

                if len(active_server_indexes) > 0:
                    i = 0
                    for qp_idx in range(MAX_QP_NUM):
                        offset_qp_idx = qp_idx + (MAX_QP_NUM * server_idx)

                        new_qp_idx = qp_idx + (MAX_QP_NUM * active_server_indexes[i])
                        qp_mapping_table.mod_with_to_qp_and_server(
                            qp=offset_qp_idx, selected_qp=new_qp_idx, selected_server=active_server_indexes[i]
                        )
                        i = (i + 1) if i < len(active_server_indexes) - 1 else 0
        elif port_bps < PORT_THRESHOLD - 5000000000:
            if server_idx not in active_server_indexes:
                print(f"Server {server_idx} restored.")
                active_server_indexes.append(server_idx)
                for qp_idx in range(MAX_QP_NUM):
                    offset_qp_idx = qp_idx + (MAX_QP_NUM * server_idx)
                    qp_mapping_table.mod_with_to_qp_and_server(
                        qp=offset_qp_idx, selected_qp=offset_qp_idx, selected_server=server_idx
                    )

        prev_port_rate[server_port] = current_rate


def overloaded_servers_timer():
    import threading

    global overloaded_servers_timer, disable_overloaded_servers
    disable_overloaded_servers()
    threading.Timer(1, overloaded_servers_timer).start()


#################################
##### MIRROR SESSIONS TABLE #####
#################################
# In this section, we setup the mirror sessions of Ribosome.
# One session is used to truncate/send the headers to the NF.
# Other NUMBER_OF_SERVERS are used to send QP Refresh Packets to the proper RDMA server.
PKT_MIN_LENGTH = 71
HEADER_MIRROR_SESSION = 100
QP_REFRESH_MIRROR_SESSION = 200


def setup_mirror_sessions_table():
    global bfrt, NF_PORT, SERVER_PORT_TO_IDX, PKT_MIN_LENGTH, HEADER_MIRROR_SESSION, QP_REFRESH_MIRROR_SESSION

    mirror_cfg = bfrt.mirror.cfg

    print("Setting up Header Truncate Group %d -- Egress Port %d -- Truncate at %d bytes" %
          (HEADER_MIRROR_SESSION, NF_PORT, PKT_MIN_LENGTH))

    mirror_cfg.entry_with_normal(
        sid=HEADER_MIRROR_SESSION,
        direction="BOTH",
        session_enable=True,
        ucast_egress_port=NF_PORT,
        ucast_egress_port_valid=1,
        max_pkt_len=PKT_MIN_LENGTH
    ).push()

    for port, session in SERVER_PORT_TO_IDX.items():
        print("Setting up QP Refresh Group %d -- Egress Port %d -- Truncate at %d bytes" %
              (QP_REFRESH_MIRROR_SESSION + session, port, PKT_MIN_LENGTH))

        mirror_cfg.entry_with_normal(
            sid=QP_REFRESH_MIRROR_SESSION + session,
            direction="BOTH",
            session_enable=True,
            ucast_egress_port=port,
            ucast_egress_port_valid=1,
            max_pkt_len=PKT_MIN_LENGTH
        ).push()


############################
##### QP MAPPING TABLE #####
############################
# This function setups the entries in the qp_mapping table.
def setup_qp_mapping_table():
    global p4, NUMBER_OF_SERVERS, MAX_QP_NUM, TOTAL_QP

    qp_mapping_profile = p4.Ingress.qp_mapping_profile
    qp_mapping_sel = p4.Ingress.qp_mapping_sel
    qp_mapping_table = p4.Ingress.qp_mapping
    qp_mapping_table.clear()

    server_profiles = []
    for server_idx in range(NUMBER_OF_SERVERS):
        for qp_idx in range(MAX_QP_NUM):
            offset_qp_idx = qp_idx + (MAX_QP_NUM * server_idx)

            qp_mapping_profile.add_with_to_qp_and_server(
                ACTION_MEMBER_ID=offset_qp_idx,
                selected_qp=offset_qp_idx,
                selected_server=server_idx
            )

            server_profiles.append(offset_qp_idx)

    qp_mapping_sel.entry(SELECTOR_GROUP_ID=1,
                         MAX_GROUP_SIZE=TOTAL_QP,
                         ACTION_MEMBER_ID=server_profiles,
                         ACTION_MEMBER_STATUS=[True] * TOTAL_QP
                         ).push()

    qp_mapping_table.add(to_split=1, SELECTOR_GROUP_ID=1)

    bfrt.complete_operations()


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


#######################
##### TABLE SETUP #####
#######################
setup_mirror_sessions_table()

setup_blacklist_table()
setup_qp_mapping_table()

########################
##### TIMERS SETUP #####
########################
restore_qp_timer()
# overloaded_servers_timer()
counters_timer()  # Comment out to disable port stats

############################
##### RUN_PD_RPC SETUP #####
############################
lab_path = os.path.join(os.getcwd(), "run_pd_rpc/")
run_pd_rpc(os.path.join(lab_path, "setup.py"))
p = subprocess.Popen([os.path.join(os.environ['SDE'], "run_bfshell.sh"), '-f', os.path.join(lab_path, "access.txt")])
try:
    p.wait(3)
except subprocess.TimeoutExpired:
    p.kill()
