package test

import "core:fmt"

main :: proc() {
		x := 0xFF
		mask := ((~u16(0)) >> 8) << 8
		sign := 0x80 & 0b1000_1000
		fmt.printf("%+d\n", i16(u16(x) | mask))
		fmt.printf("%+d\n", 2)
		fmt.printf("%t\n", sign != 0)
		fmt.printf("%#b\n", ~u16(0))
		fmt.printf("%#b\n", mask)
		fmt.printf("%#b\n", 0x80)
		fmt.printf("%#b\n", x)
		fmt.printf("%#b\n", (x << 1))
		fmt.printf("%#b\n", (x << 1) >> 1)
		fmt.printf("%#b\n", i16(x) << 8 >> 8)
		fmt.printf("%#b\n", i8(x) << 7 >> 7)
}
