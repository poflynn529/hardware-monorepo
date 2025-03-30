package utils;

function automatic logic [63:0] reverse_byte_endianess(logic [63:0] value, int size);
    case (size)
        16: return {value[7:0], value[15:8]};
        32: return {value[7:0], value[15:8], value[23:16], value[31:24]};
        64: return {value[7:0], value[15:8], value[23:16], value[31:24],
                    value[39:32], value[47:40], value[55:48], value[63:56]};
        default: $fatal(1, "Invalid input size for reverse_byte_endianess");
    endcase
endfunction

function automatic int open_file(string path, string mode);
    int file = $fopen(path, mode);
    if (file == 0) begin
        $fatal(1, "Error: Could not open file at %s", path);
    end
    return file;
endfunction

function automatic void copy_byte_array(ref byte input_array[], ref byte output_array[], input int copy_length, input int start_idx);
    for (int i = 0; i < copy_length; i++) begin
        output_array[i] = input_array[start_idx + i];
    end
endfunction

endpackage