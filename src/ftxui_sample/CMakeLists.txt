add_executable(intro main.cpp)

target_link_libraries(
  intro
  PRIVATE tinyChat::tinyChat_options
          tinyChat::tinyChat_warnings)

target_link_system_libraries(
  intro
  PRIVATE
          CLI11::CLI11
          fmt::fmt
          spdlog::spdlog
          lefticus::tools
          ftxui::screen
          ftxui::dom
          ftxui::component
          range-v3::range-v3
          asio::asio
          json::json)

target_include_directories(intro PRIVATE "${CMAKE_BINARY_DIR}/configured_files/include")
