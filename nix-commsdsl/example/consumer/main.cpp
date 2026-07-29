// Round trips a message through the generated nebs_demo protocol definition.
//
// The point of this program is not the protocol logic, it is that a plain CMake
// project can `find_package (nebs_demo)` against the derivation produced by
// nix-commsdsl and get working headers plus the transitive cc::comms dependency.

#include <cstdint>
#include <cstdlib>
#include <iostream>
#include <vector>

#include "comms/comms.h"

#include "nebs_base/field/NodeIdCommon.h"
#include "nebs_demo/Message.h"
#include "nebs_demo/frame/Frame.h"
#include "nebs_demo/input/AllMessages.h"
#include "nebs_demo/message/Heartbeat.h"

namespace
{

using Interface = nebs_demo::Message<
    comms::option::app::ReadIterator<const std::uint8_t*>,
    comms::option::app::WriteIterator<std::uint8_t*>,
    comms::option::app::LengthInfoInterface,
    comms::option::app::IdInfoInterface,
    comms::option::app::NameInterface
>;

using Frame = nebs_demo::frame::Frame<Interface>;
using Heartbeat = nebs_demo::message::Heartbeat<Interface>;

constexpr std::uint64_t Uptime = 1234567;
constexpr auto Node = nebs_base::field::NodeIdCommon::ValueType::Sensor;

} // namespace

int main()
{
    Frame frame;

    Heartbeat outMsg;
    outMsg.field_uptime().setValue(Uptime);
    outMsg.field_node().setValue(Node);

    std::vector<std::uint8_t> buf(frame.length(outMsg));
    auto* writeIter = buf.data();
    if (frame.write(outMsg, writeIter, buf.size()) != comms::ErrorStatus::Success) {
        std::cerr << "failed to write " << outMsg.name() << '\n';
        return EXIT_FAILURE;
    }

    Frame::MsgPtr inMsg;
    const auto* readIter = static_cast<const std::uint8_t*>(buf.data());
    if (frame.read(inMsg, readIter, buf.size()) != comms::ErrorStatus::Success) {
        std::cerr << "failed to read back the frame\n";
        return EXIT_FAILURE;
    }

    if (!inMsg) {
        std::cerr << "no message was produced\n";
        return EXIT_FAILURE;
    }

    const auto* heartbeat = dynamic_cast<const Heartbeat*>(inMsg.get());
    if (heartbeat == nullptr) {
        std::cerr << "expected a Heartbeat, got " << inMsg->name() << '\n';
        return EXIT_FAILURE;
    }

    if ((heartbeat->field_uptime().getValue() != Uptime) ||
        (heartbeat->field_node().getValue() != Node)) {
        std::cerr << "round tripped fields do not match\n";
        return EXIT_FAILURE;
    }

    std::cout << "c++: round tripped " << inMsg->name() << " in " << buf.size() << " bytes\n";
    return EXIT_SUCCESS;
}
