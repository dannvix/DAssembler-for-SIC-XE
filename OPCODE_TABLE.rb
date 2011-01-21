#!/usr/bin/ruby

OPCODE_TABLE = {}
OPCODE_TABLE["CLEAR"]  = {:opcode => 0xb4, :length => 2}
OPCODE_TABLE["COMP"]   = {:opcode => 0x28, :length => 3}
OPCODE_TABLE["COMPR"]  = {:opcode => 0xa0, :length => 2}
OPCODE_TABLE["J"]      = {:opcode => 0x3c, :length => 3}
OPCODE_TABLE["JEQ"]    = {:opcode => 0x30, :length => 3}
OPCODE_TABLE["JLT"]    = {:opcode => 0x38, :length => 3}
OPCODE_TABLE["JSUB"]   = {:opcode => 0x48, :length => 3}
OPCODE_TABLE["LDA"]    = {:opcode => 0x00, :length => 3}
OPCODE_TABLE["LDB"]    = {:opcode => 0x68, :length => 3}
OPCODE_TABLE["LDCH"]   = {:opcode => 0x50, :length => 3}
OPCODE_TABLE["LDT"]    = {:opcode => 0x74, :length => 3}
OPCODE_TABLE["RD"]     = {:opcode => 0xd8, :length => 3}
OPCODE_TABLE["RSUB"]   = {:opcode => 0x4c, :length => 3}
OPCODE_TABLE["STA"]    = {:opcode => 0x0c, :length => 3}
OPCODE_TABLE["STCH"]   = {:opcode => 0x54, :length => 3}
OPCODE_TABLE["STL"]    = {:opcode => 0x14, :length => 3}
OPCODE_TABLE["STX"]    = {:opcode => 0x10, :length => 3}
OPCODE_TABLE["TD"]     = {:opcode => 0xe0, :length => 3}
OPCODE_TABLE["TIXR"]   = {:opcode => 0xb8, :length => 2}
OPCODE_TABLE["WD"]     = {:opcode => 0xdc, :length => 3}
