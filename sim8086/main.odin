package main

import "core:fmt"
import "core:os"
import "core:strings"

regW    :: [8]string{"ax", "cx", "dx", "bx", "sp", "bp", "si", "di"}
regB    :: [8]string{"al", "cl", "dl", "bl", "ah", "ch", "dh", "bh"}
effAddr := [8]string{"bx + si", "bx + di", "bp + si", "bp + di", "si", "di", "bp", "bx"}

// In order of Table 4-12. 8086 Instruction Encoding
// MOV
rm_to_reg  :: 0b100010   // Register/memory to/from register
imm_to_reg :: 0b1011     // Immediate to register/memory
imm_to_rm  :: 0b1100011  // Immediate to register
mem_to_acc :: 0b1010000  // Memory to accumulator
acc_to_mem :: 0b1010001  // Accumulator to memory

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
            w := b >> 3 & 0b1
            regTbl := regW if w == 1 else regB
            dst := regTbl[b & 0b111]
            i += 1 // consume next byte
            lsb := u16(data[i])
            msb: u16 = 0
            if w == 1 {
                i += 1 // consume next byte
                msb = u16(data[i])
            }
            fmt.sbprintf(&out, "mov %s, %d\n", dst, lsb + msb << 8)
        } else if b >> 2 == rm_to_reg {
            // if d is 0: reg is src, if d is 1: reg is dst
            // if d = 0, srcDst[d] = reg and srcDst[(d+1) & 1] = other, id d = 1, srcDst[d] = reg and srcDst[(d+1) & 1] = other
            // and srcDst[0] is src, srcDst[1] is dst -- always
            d := b >> 1 & 0b1
            srcDst := [2]string{}

            w := b & 0b1
            regTbl := regW if w == 1 else regB

            i += 1 // consume next byte
            b := data[i]

            srcDst[d] = regTbl[b >> 3 & 0b111]
            rm := b & 0b111
            addr := effAddr[rm]

            mod := b >> 6
            switch mod {
            case 0b00:
                if rm == 0b110 {
                    // direct address special case -- ignore the rm and addr, we don't need it
                    fmt.sbprintf(&out, "mov %s, [%d]\n", srcDst[d], u16(data[i+1]) + u16(data[i+2]) << 8)
                    i += 2 // we consumed two bytes
                    continue
                }
                srcDst[(d+1) & 1] = make_ea(addr, data[i:], false, false)
            case 0b01:
                srcDst[(d+1) & 1] = make_ea(addr, data[i+1:], true, false)
                i += 1 // we consumed one byte
            case 0b10:
                srcDst[(d+1) & 1] = make_ea(addr, data[i+1:], true, true)
                i += 2 // we consumed two bytes
            case 0b11:
                srcDst[(d+1) & 1] = regTbl[rm]
            }
            fmt.sbprintf(&out, "mov %s, %s\n", srcDst[1], srcDst[0])
        } else if b >> 1 == mem_to_acc {
            w := b & 0b1
            fmt.sbprintf(&out, "mov ax, [%d]\n", read_lo_hi(data[i+1:], w))
            i += w == 1 ? 2 : 1  // consumed bytes
        } else if b >> 1 == acc_to_mem {
            w := b & 0b1
            fmt.sbprintf(&out, "mov [%d], ax\n", read_lo_hi(data[i+1:], w))
            i += w == 1 ? 2 : 1  // consumed bytes
        } else if b >> 1 == imm_to_rm {
            w := b & 0b1
            regTbl := regW if w == 1 else regB
            i += 1 // consume next byte

            dst : string
            b := data[i]
            rm := b & 0b111
            addr := effAddr[rm]
            mod := b >> 6
            switch mod {
            case 0b00:
                if rm == 0b110 {
                    // this shouldn't happen, because we don't have a reg, right?
                    fmt.printf("imm_to_rm with rm == 0b110, mistake? byte #%d\n", i)
                    continue
                }
                dst = make_ea(addr, data[i:], false, false)
            case 0b01:
                dst = make_ea(addr, data[i+1:], true, false)
                i += 1 // we consumed one byte
            case 0b10:
                dst = make_ea(addr, data[i+1:], true, true)
                i += 2 // we consumed two bytes
            case 0b11:
                dst = regTbl[rm]
            }
            // now calculate data, i is our current position
            imm := read_lo_hi(data[i+1:], w)
            fmt.sbprintf(&out, "mov %s, %s %d\n", dst, w == 1 ? "word" : "byte", imm)
            i += w == 1 ? 2 : 1
        } else {
            fmt.printf("found bad instruction: 0b%8b byte #%d, exiting\n", b, i)
            os.exit(1)
        }
    }

    os.write_entire_file(os.args[2], out.buf[:])
}

make_ea :: proc(addr: string, data: []byte, displacement: bool, wide: bool) -> string {
    if !displacement {
        return fmt.tprintf("[%s]", addr)
    }

    val := i16(data[0])
    if wide {
        val += i16(data[1]) << 8
    } else {
        val = i16(sign_extend(u8(val)))
    }
    if val != 0 {
        return fmt.tprintf("[%s %+d]", addr, val)
    }
    return fmt.tprintf("[%s]", addr)
}

read_lo_hi :: proc(data: []byte, w: u8) -> u16 {
    val := u16(data[0])
    if w == 1 {
        val += u16(data[1]) << 8
    }
    return val
}

sign_extend :: proc(b: u8) -> u16 {
    mask := ((~u16(0)) >> 8) << 8
    sign := b & 0x80
    if sign != 0 {
        return mask | u16(b)
    }
    return u16(b)
}
