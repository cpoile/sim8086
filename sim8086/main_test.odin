package main

import "core:fmt"
import "core:strconv"
import "core:strings"
import "core:testing"

Case :: struct {
	listing: string,
	hex:     string,
	exp_asm: string,
}

@(test)
test_mov :: proc(t: ^testing.T) {
	expect :: testing.expect
	expect_value :: testing.expect_value
	cases := []Case {
		{"37", "89d9", "mov cx, bx"},
		 {
			"38",
			"89d988e589da89de89fb88c888ed89c389f389fc89c5",
			"mov cx, bx\nmov ch, ah\nmov dx, bx\nmov si, bx\nmov bx, di\nmov al, cl\nmov ch, ch\nmov bx, ax\nmov bx, si\nmov sp, di\nmov bp, ax",
		},
		 {
			"39",
			"89de88c6b10cb5f4b90c00b9f4ffba6c0fba94f08a008b1b8b56008a60048a8087138909880a886e00",
			"mov si, bx\nmov dh, al\nmov cl, 12\nmov ch, 244\nmov cx, 12\nmov cx, 65524\nmov dx, 3948\nmov dx, 61588\nmov al, [bx + si]\nmov bx, [bp + di]\nmov dx, [bp]\nmov ah, [bx + si +4]\nmov al, [bx + si +4999]\nmov [bx + di], cx\nmov [bp + si], cl\nmov [bp], ch",
		},
		 {
			"40",
			"8b41db898cd4fe8b57e0c60307c78585035b018b2e05008b1e820da1fb09a11000a3fa09a30f00",
			"mov ax, [bx + di -37]\nmov [si -300], cx\nmov dx, [bx -32]\nmov [bp + di], byte 7\nmov [di +901], word 347\nmov bp, [5]\nmov bx, [3458]\nmov ax, [2555]\nmov ax, [16]\nmov [2554], ax\nmov [15], ax",
		},
		{"41", "035e00", "add bx, [bp + 0]"},
	}

	out := strings.builder_make()
	defer strings.builder_destroy(&out)
	bin := make([dynamic]byte, 0)
	defer delete(bin)

	for c in cases {
		strings.builder_reset(&out)
		clear(&bin)

		for i := 0; i < len(c.hex); i += 2 {
			c, ok := strconv.parse_uint(string(c.hex[i:i + 2]), 16)
			expect(t, ok)
			append(&bin, u8(c))
		}

		err := process_data(&out, bin[:])
		expect_value(t, err, Error.None)

		got := strings.trim_suffix(strings.to_string(out), "\n")
		testing.expect_value(t, got, c.exp_asm)
		//expect_string(t, c.exp_asm, got, c.listing)
		/* fmt.println(got) */
		/* fmt.println(c.exp_asm) */
	}
}

expect_string :: proc(t: ^testing.T, actual: string, expected: string, name := "", loc := #caller_location) {
	if strings.compare(expected, actual) != 0 {
		fmt.printf("expected: %s\n", expected)
		fmt.printf("actual:   %s\n", actual)
		fmt.printf("[%v] %v\n", loc, name)
		testing.expect_value(t, expected, actual)
	}
}
