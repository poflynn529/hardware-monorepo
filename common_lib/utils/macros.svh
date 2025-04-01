`ifndef UTILS_SVH
`define UTILS_SVH

`define INFO(msg)  $display("%t, [INFO]    %s", $time, msg)
`define DEBUG(msg) $display("%t, [DEBUG]   %s", $time, msg)
`define WARN(msg)  $display("%t, [WARNING] %s", $time, msg)
`define ERROR(msg) $display("%t, [ERROR]   %s", $time, msg)

`endif