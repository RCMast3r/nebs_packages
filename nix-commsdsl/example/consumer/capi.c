/*
 * Same round trip as main.cpp, driven through the "C" facade produced by
 * commsdsl2c, to prove that `find_package (nebs_demo_c)` yields a linkable
 * library and not just headers.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cc_c/nebs_base/field/NodeId.h"
#include "cc_c/nebs_base/field/Timestamp.h"
#include "cc_c/nebs_demo/ErrorStatus.h"
#include "cc_c/nebs_demo/MsgHandler.h"
#include "cc_c/nebs_demo/frame/Frame.h"
#include "cc_c/nebs_demo/message/Heartbeat.h"

static const nebs_base_field_Timestamp_ValueType Uptime = 1234567;
static const nebs_base_field_NodeId_ValueType Node = nebs_base_field_NodeId_ValueType_Sensor;

static void handleHeartbeat(nebs_demo_message_Heartbeat* msg, void* userData)
{
    int* handled = (int*)userData;

    nebs_base_field_Timestamp* uptime =
        nebs_demo_message_HeartbeatFields_Uptime_ref(nebs_demo_message_Heartbeat_field_uptime(msg));
    nebs_base_field_NodeId* node =
        nebs_demo_message_HeartbeatFields_Node_ref(nebs_demo_message_Heartbeat_field_node(msg));

    if ((nebs_base_field_Timestamp_getValue(uptime) == Uptime)
        && (nebs_base_field_NodeId_getValue(node) == Node)) {
        *handled = 1;
    }
}

int main(void)
{
    uint8_t buf[64];
    size_t msgLen = sizeof(buf);
    size_t consumed = 0;
    int handled = 0;

    nebs_demo_frame_Frame* frame = nebs_demo_frame_Frame_alloc();
    nebs_demo_message_Heartbeat* outMsg = nebs_demo_message_Heartbeat_alloc();
    nebs_demo_MsgHandler handler;

    if ((frame == NULL) || (outMsg == NULL)) {
        fprintf(stderr, "allocation failed\n");
        return EXIT_FAILURE;
    }

    nebs_base_field_Timestamp_setValue(
        nebs_demo_message_HeartbeatFields_Uptime_ref(nebs_demo_message_Heartbeat_field_uptime(outMsg)),
        Uptime);
    nebs_base_field_NodeId_setValue(
        nebs_demo_message_HeartbeatFields_Node_ref(nebs_demo_message_Heartbeat_field_node(outMsg)),
        Node);

    if (nebs_demo_frame_Frame_writeMessage(
            frame, nebs_demo_message_Heartbeat_toInterface(outMsg), buf, &msgLen)
        != nebs_demo_ErrorStatus_Success) {
        fprintf(stderr, "failed to write the frame\n");
        return EXIT_FAILURE;
    }

    memset(&handler, 0, sizeof(handler));
    handler.handle_nebs_demo_message_Heartbeat = &handleHeartbeat;

    consumed = nebs_demo_frame_Frame_processInputData(frame, buf, msgLen, &handler, &handled);

    nebs_demo_message_Heartbeat_free(outMsg);
    nebs_demo_frame_Frame_free(frame);

    if ((consumed != msgLen) || (handled == 0)) {
        fprintf(stderr, "round trip failed: consumed %zu of %zu, handled=%d\n", consumed, msgLen, handled);
        return EXIT_FAILURE;
    }

    printf("c: round tripped Heartbeat in %zu bytes\n", msgLen);
    return EXIT_SUCCESS;
}
