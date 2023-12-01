package main

import "core:fmt"
import "core:os"
import "core:strings"

regW :: [8]string{"ax", "cx", "dx", "bx", "sp", "bp", "si", "di"}
regB :: [8]string{"al", "cl", "dl", "bl", "ah", "ch", "dh", "bh"}

main :: proc() {
	if len(os.args) != 3 {
		fmt.println("Usage: sim8086 asm_bin asm_out_filename")
		return
	}
	data, ok := os.read_entire_file(os.args[1])
	if !ok {
		fmt.println("could not read file")
		return
	}
	defer delete(data)

	out := strings.builder_make()
	defer strings.builder_destroy(&out)
	fmt.sbprintln(&out, "bits 16\n")

	for i := 0; i < len(data); i += 1 {
		b := data[i]
		// fmt.printf("%b\n", b)
		if b >> 2 == 0b100010 {
			w := b & 0b1 == 0b1
			reg := regW if w else regB

			// Note: ignoring d, for now assuming d=0 (source is REG (first) field)
			i += 1  // consume next byte
			b := data[i]
			dst := reg[b << 5 >> 5]
			src := reg[b << 2 >> 5]
			fmt.sbprintf(&out, "mov %s, %s\n", dst, src)
		} else {
			continue
		}
	}

	os.write_entire_file(os.args[2], out.buf[:])
}
