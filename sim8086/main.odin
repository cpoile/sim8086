package main

import "core:fmt"
import "core:os"
import "core:strings"

regW    :: [8]string{"ax", "cx", "dx", "bx", "sp", "bp", "si", "di"}
regB    :: [8]string{"al", "cl", "dl", "bl", "ah", "ch", "dh", "bh"}
effAddr := [8]string{"bx + si", "bx + di", "bp + si", "bp + di", "si", "di", "bp", "bx"}

imm_to_reg :: 0b1011
rm_to_reg  :: 0b100010
imm_to_rm  :: 0b1100011

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
        if b >> 4 == imm_to_reg {
            w := b >> 3 & 0b1 == 0b1
            reg := regW if w else regB
            dst := reg[b & 0b111]
            i += 1 // consume next byte
            lsb := u16(data[i])
            msb: u16 = 0
            if w {
                i += 1 // consume next byte
                msb = u16(data[i])
            }
            fmt.sbprintf(&out, "mov %s, %d\n", dst, lsb + msb << 8)
        } else if b >> 2 == rm_to_reg {
            d := b >> 1 & 0b1 == 0b1
            w := b & 0b1 == 0b1
            regTbl := regW if w else regB

            i += 1 // consume next byte
            b := data[i]

            // if d is 0: reg is src, if d is 1: reg is dst
            reg := regTbl[b >> 3 & 0b111]
            rm := b & 0b111
            addr := effAddr[rm]

            mod := b >> 6
            switch mod {
            case 0b00:
                if rm == 0b110 {
                    // direct address special case -- ignore the rm and addr, we don't need it
                    fmt.sbprintf(&out, "mov %s, [%d]\n", reg, u16(data[i+1]) + u16(data[i+2]) << 8)
                    i += 2 // we consumed two bytes
                    continue
                }
                ea := make_ea(addr, data[i:], false, false)
                dst, src := d ? reg : ea, d ? ea : reg
                fmt.sbprintf(&out, "mov %s, %s\n", dst, src)
            case 0b01:
                ea := make_ea(addr, data[i+1:], true, false)
                dst, src := d ? reg : ea, d ? ea : reg
                fmt.sbprintf(&out, "mov %s, %s\n", dst, src)
                i += 1 // we consumed one byte
            case 0b10:
                ea := make_ea(addr, data[i+1:], true, true)
                dst, src := d ? reg : ea, d ? ea : reg
                fmt.sbprintf(&out, "mov %s, %s\n", dst, src)
                i += 2 // we consumed two bytes
            case 0b11:
                otherReg := regTbl[rm]
                dst, src := d ? reg : otherReg, d ? otherReg : reg
                fmt.sbprintf(&out, "mov %s, %s\n", dst, src)
            }
        } else if b >> 1 == imm_to_rm {
            fmt.println("rm to reg")
        }
    }

    os.write_entire_file(os.args[2], out.buf[:])
}

make_ea :: proc(addr: string, data: []byte, displacement: bool, wide: bool) -> string {
    if !displacement {
        return fmt.tprintf("[%s]", addr)
    }

    val := u16(data[0])
    if wide {
        val += u16(data[1]) << 8
    }
    if val > 0 {
        return fmt.tprintf("[%s + %d]", addr, val)
    }
    return fmt.tprintf("[%s]", addr)
}
