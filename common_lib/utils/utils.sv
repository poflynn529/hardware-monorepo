package utils;

// function automatic logic [63:0] reverse_byte_endianess(logic [63:0] value, int size);
//     case (size)
//         16: return {value[7:0], value[15:8]};
//         32: return {value[7:0], value[15:8], value[23:16], value[31:24]};
//         64: return {value[7:0], value[15:8], value[23:16], value[31:24],
//                     value[39:32], value[47:40], value[55:48], value[63:56]};
//         default: $fatal(1, "Invalid input size for reverse_byte_endianess");
//     endcase
// endfunction

// function automatic int open_file(string path, string mode);
//     int file = $fopen(path, mode);
//     if (file == 0) begin
//         $fatal(1, "Error: Could not open file at %s", path);
//     end
//     return file;
// endfunction

// function automatic void copy_byte_array(
//     ref byte input_array[], 
//     ref byte output_array[], 
//     input int start_idx_input,
//     input int start_idx_output, 
//     input int copy_length
// );
//     for (int i = 0; i < copy_length; i++) begin
//         output_array[start_idx_output + i] = input_array[start_idx_input + i];
//     end
// endfunction

// function automatic string byte_array_to_hex_string(byte data[]);
//   string result = "";
  
//   foreach (data[i]) begin
//     if (i > 0) result = {result, " "};
//     result = {result, $sformatf("%02X", data[i])};
//   end
  
//   return result;
// endfunction

function automatic int cdiv(int numerator, int denominator);
    return (numerator + denominator - 1) / denominator;
endfunction

// task automatic sim_timeout(const ref logic clk, input int timeout);
//     repeat(timeout) @(posedge(clk));
//     $fatal(1, "Sim timeout reached");
// endtask

endpackage
