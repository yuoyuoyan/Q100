// data width parameters
`define LEN_INSTR       32
`define LEN_RS1          5
`define LEN_RS2          5
`define LEN_RD           5
`define LEN_FUNCT7       7
`define LEN_FUNCT3       3
`define LEN_IMM         32
`define LEN_INSTR_TYPE   3
`define LEN_OPCODE       7
`define LEN_REG         32
`define LEN_REG_VAL     32
`define LEN_CSR         32
`define LEN_CSR_ADDR    12
`define LEN_ADD_SUB_VAL 32
`define LEN_ALU_OP       4
`define LEN_SHAMT        5
`define LEN_PORTA_SEL    3
`define LEN_PORTB_SEL    3
`define LEN_PORTA_MUL   16
`define LEN_PORTB_MUL   16
`define DTCM_ADDR_WIDTH 17
`define DTCM_BANK        4
`define DTCM_DATA_WIDTH 32
`define ITCM_ADDR_WIDTH 12
`define ITCM_DATA_WIDTH 32

// funct3 type
`define FUNCT3_BEQ         3'b000
`define FUNCT3_BNE         3'b001
`define FUNCT3_BLT         3'b100
`define FUNCT3_BGE         3'b101
`define FUNCT3_BLTU        3'b110
`define FUNCT3_BGEU        3'b111
`define FUNCT3_LB          3'b000
`define FUNCT3_LH          3'b001
`define FUNCT3_LW          3'b010
`define FUNCT3_LBU         3'b100
`define FUNCT3_LHU         3'b101
`define FUNCT3_SB          3'b000
`define FUNCT3_SH          3'b001
`define FUNCT3_SW          3'b010
`define FUNCT3_ADDI        3'b000
`define FUNCT3_SLTI        3'b010
`define FUNCT3_SLTIU       3'b011
`define FUNCT3_XORI        3'b100
`define FUNCT3_ORI         3'b110
`define FUNCT3_ANDI        3'b111
`define FUNCT3_SLLI        3'b001
`define FUNCT3_SRLI_SRAI   3'b101
`define FUNCT3_ADD_SUB     3'b000
`define FUNCT3_SLL         3'b001
`define FUNCT3_SLT         3'b010
`define FUNCT3_SLTU        3'b011
`define FUNCT3_XOR         3'b100
`define FUNCT3_SRL_SRA     3'b101
`define FUNCT3_OR          3'b110
`define FUNCT3_AND         3'b111
`define FUNCT3_FENCE       3'b000
`define FUNCT3_FENCEI      3'b001
`define FUNCT3_ECALL_EBRAK 3'b000
`define FUNCT3_CSRRW       3'b001
`define FUNCT3_CSRRS       3'b010
`define FUNCT3_CSRRC       3'b011
`define FUNCT3_CSRRWI      3'b101
`define FUNCT3_CSRRSI      3'b110
`define FUNCT3_CSRRCI      3'b111

// opcode type
`define TYPE_R     0
`define TYPE_I     1
`define TYPE_S     2
`define TYPE_B     3
`define TYPE_U     4
`define TYPE_J     5
`define TYPE_ERR   6

// alu operation type
`define ALU_ADD   0
`define ALU_SUB   1
`define ALU_SLL   2
`define ALU_SRL   3
`define ALU_SRA   4
`define ALU_AND   5
`define ALU_OR    6
`define ALU_XOR   7
`define ALU_EQ    8
`define ALU_LT    9
`define ALU_LTU   10
`define ALU_GEQ   11
`define ALU_NOP   12

// opcode detail
`define OPCODE_LUI     7'b0110111
`define OPCODE_AUIPC   7'b0010111
`define OPCODE_JAL     7'b1101111
`define OPCODE_JALR    7'b1100111
`define OPCODE_BEQ_BNE_BLT_BGE_BLTU_BGEU  7'b1100011
`define OPCODE_LB_LH_LW_LBU_LHU  7'b0000011
`define OPCODE_SB_SH_SW 7'b0100011
`define OPCODE_ADDI_SLTI_SLTIU_XORI_ORI_ANDI_SLLI_SRLI_SRAI 7'b0010011
`define OPCODE_ADD_SUB_SLL_SLT_SLTU_XOR_SRL_SRA_OR_AND 7'b0110011
`define OPCODE_FENCE 7'b0001111
`define OPCODE_ECALL_EBREAK_CSR 7'b1110011

// csr address
`define CSR_DONE_STATUS 12'h0

// RV32I all commands
// lui rd, imm : x[rd] = sext(imm[31:12]<<12)
// auipc rd, imm : x[rd] = pc+sext(imm[31:12]<<12)
// jal rd, offset : x[rd] = pc+4; pc += sext(offset)
// jalr rd, offset(rs1) : t = pc+4; pc = (x[rs1]+sext(offset))&-1; x[rd]=t
// beq rs1, rs2, offset : if(rs1==rs2) pc+=sext(offset)
// bne rs1, rs2, offset : if(rs1!=rs2) pc+=sext(offset)
// blt rs1, rs2, offset : if(rs1<rs2) pc+=sext(offset)
// bge rs1, rs2, offset : if(rs1>=rs2) pc+=sext(offset)
// bltu rs1, rs2, offset : if(rs1_u<rs2_u) pc+=sext(offset)
// bgeu rs1, rs2, offset : if(rs1_u>=rs2_u) pc+=sext(offset)
// lb rd, offset(rs1) : x[rd] = sext(M[x[rs1]+sext(offset)][7:0])
// lh rd, offset(rs1) : x[rd] = sext(M[x[rs1]+sext(offset)][15:0])
// lw rd, offset(rs1) : x[rd] = sext(M[x[rs1]+sext(offset)][31:0])
// lbu rd, offset(rs1) : x[rd] = M[x[rs1]+sext(offset)][7:0]
// lhu rd, offset(rs1) : x[rd] = M[x[rs1]+sext(offset)][15:0]
// sb rs2, offset(rs1) : M[x[rs1]+sext(offset)] = x[rs2][7:0]
// sh rs2, offset(rs1) : M[x[rs1]+sext(offset)] = x[rs2][15:0]
// sw rs2, offset(rs1) : M[x[rs1]+sext(offset)] = x[rs2][31:0]
// addi rd, rs1, imm : x[rd] = x[rs1]+sext(imm)
// slti rd, rs1, imm : x[rd] = (x[rs1]<sext(imm))
// sltiu rd, rs1, imm : x[rd] = (x[rs1]_u<sext(imm))
// xori rd, rs1, imm : x[rd] = x[rs1]^sext(imm)
// ori rd, rs1, imm : x[rd] = x[rs1]|sext(imm)
// andi rd, rs1, imm : x[rd] = x[rs1]&sext(imm)
// slli rd, rs1, shamt : x[rd] = x[rs1]<<shamt
// srli rd, rs1, shamt : x[rd] = x[rs1]>>shamt
// srai rd, rs1, shamt : x[rd] = x[rs1]>>>shamt
// add rd, rs1, rs2 : x[rd] = x[rs1]+x[rs2]
// sub rd, rs1, rs2 : x[rd] = x[rs1]-x[rs2]
// sll rd, rs1, rs2 : x[rd] = x[rs1]<<x[rs2]
// slt rd, rs1, rs2 : x[rd] = (x[rs1]<x[rs2])
// sltu rd, rs1, rs2 : x[rd] = (x[rs1]_u<x[rs2]_u)
// xor rd, rs1, rs2 : x[rd] = x[rs1]^x[rs2]
// srl rd, rs1, rs2 : x[rd] = x[rs1]>>x[rs2]
// sra rd, rs1, rs2 : x[rd] = x[rs1]>>>x[rs2]
// or rd, rs1, rs2 : x[rd] = x[rs1]|x[rs2]
// and rd, rs1, rs2 : x[rd] = x[rs1]&x[rs2]
// fence pred, succ
// fence.i store, fetch
// ecall
// ebreak
// csrrw rd, csr, zimm[4:0] : t = CSRs[csr]; CSRs[csr] = x[rs1]; x[rd] = t
// csrrs rd, csr, rs1 : t = CSRs[csr]; CSRs[csr] = t | x[rs1]; x[rd] = t
// csrrc rd, csr, rs1 : t = CSRs[csr]; CSRs[csr] = t & ~x[rs1]; x[rd] = t
// csrrwi rd, csr, zimm[4:0] : x[rd] = CSRs[csr]; CSRs[csr] = zimm
// csrrsi rd, csr, zimm[4:0] : t = CSRs[csr]; CSRs[csr] = t | zimm; x[rd] = t
// csrrci rd, csr, zimm[4:0] : t = CSRs[csr]; CSRs[csr] = t & ~zimm; x[rd] = t
// mul rd, rs1, rs2 : x[rd] = x[rs1] X x[rs2]
// mulh rd, rs1, rs2 : x[rd] = (x[rs1] X x[rs2]) >> XLEN