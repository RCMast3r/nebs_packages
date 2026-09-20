// Exercises the installed headers and both link flavours: writes an MCAP file
// through a channel, then reads it back to prove the Rust core is really linked
// in and working, not just resolvable at link time.
#include <foxglove/channel.hpp>
#include <foxglove/context.hpp>
#include <foxglove/mcap.hpp>

#include <cstdio>
#include <cstdlib>
#include <string>

int main(int argc, char** argv) {
  // ctest runs the static and shared smoke tests in parallel from the same
  // working directory, so the output file has to be unique per binary. Use the
  // basename only: argv[0] is an absolute store path once installed, and the
  // store is read only.
  std::string name = argc > 0 ? argv[0] : "smoke";
  const auto slash = name.find_last_of('/');
  if (slash != std::string::npos) {
    name = name.substr(slash + 1);
  }
  const std::string path = name + ".mcap";
  std::remove(path.c_str());

  auto context = foxglove::Context::create();

  foxglove::McapWriterOptions options{};
  options.path = path;
  options.context = context;
  auto writer = foxglove::McapWriter::create(options);
  if (!writer.has_value()) {
    std::fprintf(stderr, "McapWriter::create failed\n");
    return 1;
  }

  auto channel = foxglove::RawChannel::create("/smoke", "json", std::nullopt, context);
  if (!channel.has_value()) {
    std::fprintf(stderr, "RawChannel::create failed\n");
    return 1;
  }

  const std::string msg = R"({"hello":"foxglove"})";
  auto err = channel->log(reinterpret_cast<const std::byte*>(msg.data()), msg.size());
  if (err != foxglove::FoxgloveError::Ok) {
    std::fprintf(stderr, "log failed: %s\n", foxglove::strerror(err));
    return 1;
  }

  if (writer->close() != foxglove::FoxgloveError::Ok) {
    std::fprintf(stderr, "close failed\n");
    return 1;
  }

  std::FILE* f = std::fopen(path.c_str(), "rb");
  if (f == nullptr) {
    std::fprintf(stderr, "mcap file was not written\n");
    return 1;
  }
  std::fseek(f, 0, SEEK_END);
  const long size = std::ftell(f);
  std::fclose(f);
  std::remove(path.c_str());

  if (size <= 0) {
    std::fprintf(stderr, "mcap file is empty\n");
    return 1;
  }

  std::printf("ok: wrote %ld bytes of mcap\n", size);
  return 0;
}
