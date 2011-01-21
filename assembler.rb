#!/usr/bin/ruby

$LOAD_PATH << "."
require 'OPCODE_TABLE'
require 'REGISTER_TABLE'
require 'Dutility'

class DAssembler
  def initialize (filename, outfile)
    @assembly = File.read(filename).split("\n").map{|x| x.chomp}
    @out = File.open(outfile, "w")

    @intermediate = []
    @symbols = {}
    @modifications = []
    @baseAddress = nil
  end

  def assemble!
    processPass1
    processPass2
    @out.close
  end

  def processPass1
    # delete invalid (comment) lines
    @assembly.delete_if {|s| not s.match PATTERN_1 and not s.match PATTERN_2 and not s.match PATTERN_4 and not s.match PATTERN_3}
    @assembly.each do |s|
      case s.operator
      when "START"
        @startAddress = s.operand.to_i
        @locationCounter = @startAddress
        @intermediate << {:code => s, :programCounter => @locationCounter}
        next
      when "END"
        @programLength = @locationCounter - @startAddress
        @intermediate << {:code => s, :programCounter => @locationCounter}
        break
      else
        if not s.label.nil? then
          die "Duplicate symbol: #{s.label}." if not @symbols[s.label].nil?
          @symbols[s.label] = @locationCounter
        end

        operator = s.operator.scan(/^[+]?([A-Z]+)$/)[0][0]
        if not OPCODE_TABLE[operator].nil? then
          @locationCounter += (s.operator.start_with? "+") ? 4 : OPCODE_TABLE[operator][:length]
        else
          case s.operator
          when "BASE"
            ;
          when "NOBASE"
            ;
          when "WORD"
            @locationCounter += 3
          when "RESB"
            die "Invalid number: #{s.operand} for RESB." if s.operand.to_i <= 0
            @locationCounter += s.operand.to_i
          when "RESW"
            die "Invalid number: #{s.operand} for RESW." if s.operand.to_i <= 0
            @locationCounter += (3 * s.operand.to_i)
          when "BYTE"
            @locationCounter += s.operand.scan(/X'(.*)'/)[0][0].length/2 if s.operand.match(/X'.*'/)
            @locationCounter += s.operand.scan(/C'(.*)'/)[0][0].length if s.operand.match(/C'.*'/)
          else
            die "Invalid operator: #{s.operator}."
          end
        end

        @intermediate << {:code => s, :programCounter => @locationCounter}
      end
    end
  end


  def processPass2
    textRecord = nil
    textRecordProgramCounter = @startAddress

    @intermediate.each do |line|
      s = line[:code]
      case s.operator
      when "START"
        @out.puts "H#{sprintf("%-5s", s.label)}#{sprintf("%06X", @startAddress)}#{sprintf("%06X", @programLength)}"
        next
      when "END"
        # print remaining text records
        if not textRecord.nil? then
          @out.puts "T#{sprintf("%06X", textRecordProgramCounter)}#{sprintf("%02X", textRecord.length/2)}#{textRecord}"
        end

        # print modification records
        @modifications.each do |m|
          @out.puts "M#{sprintf("%06X", m)}05"
        end

        @out.puts "E#{sprintf("%06X", @startAddress)}"
        break
      else
        case s.operator
        when "BASE"
          @baseAddress = (@symbols[s.operand].nil?) ? s.operand.to_i : @symbols[s.operand]
        when "NOBASE"
          @baseAddress = nil
        when "RESW"
          ;
        when "RESB"
          ;
        else
          objectCode = assembleInstruction(line)
          if not textRecord.nil? and (textRecord.length >= (0x1D*2) or (line[:programCounter] - textRecordProgramCounter) >= 0x1000) then
            @out.puts "T#{sprintf("%06X", textRecordProgramCounter)}#{sprintf("%02X", textRecord.length/2)}#{textRecord}"
            textRecord = nil
            textRecordProgramCounter = line[:programCounter] - objectCode.length/2
          end

          if textRecord.nil? then
            textRecord = objectCode
          else
            textRecord += objectCode
          end
        end
      end
    end
  end


  def assembleInstruction (line)
    s = line[:code]
    case s.operator
    when "WORD"
      return sprintf("%06X", (@symbols[s.operand].nil?) ? s.operand.to_i : @symbols[s.operand])
    when "BYTE"
      return s.operand.scan(/C'([A-Z0-9]+)'/)[0][0].bytes.map{|x| sprintf("%02X", x)}.join("") if s.operand.match /C'[A-Z0-9]+'/
      return s.operand.scan(/X'([A-F0-9]+)'/)[0][0] if s.operand.match /X'[A-F0-9]+'/
      die "Invalid operand: #{s.operand} for BYTE."
    when "RESB"
      ;
    when "RESW"
      ;
    else
      operator = s.operator.scan(/^[+]?([A-Z]+)$/)[0][0]
      die "Extended format cannot be applied on operator: #{operator}" if s.operator.start_with? "+" and OPCODE_TABLE[operator][:length] != 3
      case OPCODE_TABLE[operator][:length]
      when 1
        return assembleFormat1(OPCODE_TABLE[operator][:opcode])
      when 2
        if s.operand.include? "," then
          operands = s.operand.split(",").map{|x| x.delete(" ")}
          r1 = (REGISTER_TABLE[operands[0]].nil?) ? operands[0].to_i : REGISTER_TABLE[operands[0]]
          r2 = (REGISTER_TABLE[operands[1]].nil?) ? operands[1].to_i : REGISTER_TABLE[operands[1]]
          return assembleFormat2(OPCODE_TABLE[operator][:opcode], r1, r2)
        else
          r1 = (REGISTER_TABLE[s.operand].nil?) ? s.operand.to_i : REGISTER_TABLE[s.operand]
          return assembleFormat2(OPCODE_TABLE[operator][:opcode], r1, 0)
        end
      when 3
        if not s.operator.start_with? "+" then
          # format 3
          n, i, x, b, p = 1, 1, 0, 0, 0
          thereIsAConstant = false

          if s.operand.nil? then
            return assembleFormat3(OPCODE_TABLE[operator][:opcode], n, i, x, b, p, 0, 0)
          end

          operand = s.operand
          if operand.match /^[\#@A-Z0-9]+\s*,\s*[X]{1}$/
            # it is indexing
            operand = operand.scan(/^([\#@A-Z0-9]+)\s*,\s*[X]{1}$/)[0][0]
            x = 1
          end

          if operand.start_with? "\#" then
            # immediate addressing
            operand = operand.scan(/^\#([A-Z0-9]+)$/)[0][0]
            if @symbols[operand].nil? then
              thereIsAConstant = true
              address = operand.to_i
            else
              address = @symbols[operand]
            end
            n = 0
          elsif operand.start_with? "@" then
            # indirect addressing
            operand = operand.scan(/^@([A-Z0-9]+)$/)[0][0]
            if @symbols[operand].nil? then
              thereIsAConstant = true
              address = operand.to_i
            else
              address = @symbols[operand]
            end
            i = 0
          else
            # simple addresssing
            die "Undefinied symbol: #{operand}" if @symbols[operand].nil? and not operand.match /^[0-9]+$/
            if @symbols[operand].nil? then
              address = operand.to_i
              thereIsAConstant = true
            else
              address = @symbols[operand]
            end
          end

          # check if the constant to large, and, select an addressing method
          if thereIsAConstant == true then
            die "Too large contant: #{s.operand}" if address > 4095
            targetAddress = address
          else
            # is pc-relative ok? (by default, we choose pc-relative)
            targetAddress = address - line[:programCounter]
            if targetAddress >= -2048 and targetAddress < 2048 then
              targetAddress += 4096 if targetAddress < 0
              p = 1
            elsif not @baseAddress.nil?
              # pc-relative is not, we try base-relative (if available)
              targetAddress = (address - @baseAddress)
              die "Displacement is too large" if targetAddress < 0 or targetAddress >= 4096
              b = 1
            else
              die "Displacement is too large"
            end
          end

          return assembleFormat3(OPCODE_TABLE[operator][:opcode], n, i, x, b, p, 0, targetAddress)
        else
          # format 4 (TODO: abstraction between fmt3 and fmt4
          n, i, x, b, p = 1, 1, 0, 0, 0

          needModification = true

          operand = s.operand
          if operand.match /^[@\#A-Z0-9]+\s*,\s*[X]{1}$/
            # it is indexing
            operand = operand.scan(/^([@\#A-Z0-9]+)\s*,\s*[X]{1}$/)[0][0]
            x = 1
          end

          if operand.start_with? "\#" then
            # immediate addressing
            operand = s.operand.scan(/^\#([A-Z0-9]+)$/)[0][0]
            if @symbols[operand].nil? then
              targetAddress = operand.to_i
            else
              targeTAddress = @symbols[operand]
            end
            needModification = false
            n = 0
          elsif operand.start_with? "@" then
            # indirect addressing
            operand = operand.scan(/^@([A-Z0-9]+)$/)[0][0]
            if @symbols[operand].nil? then
              targetAddress = operand.to_i
            else
              targetAddress = @symbols[operand]
            end
            i = 0
          else
            # simple addresssing
            die "Undefinied symbol: #{operand}" if @symbols[operand].nil? and not operand.match /^[0-9]+$/
            if @symbols[operand].nil? then
              address = operand.to_i
              thereIsAConstant = true
            else
              address = @symbols[operand]
            end
          end

          @modifications << (line[:programCounter] - 4 - @startAddress + 1) if needModification

          return assembleFormat4(OPCODE_TABLE[operator][:opcode], n, i, x, b, p, 1, targetAddress)
        end
      end
    end
  end


  def assembleFormat1 (opcode)
    return sprintf("%02X", opcode)
  end


  def assembleFormat2 (opcode, r1, r2)
    last_byte = "#{r1.to_s(2).rjust(4, '0')}#{r2.to_s(2).rjust(4, '0')}".to_i(2)
    return "#{sprintf("%02X", opcode)}#{sprintf("%02X", last_byte)}"
  end


  def assembleFormat3 (opcode, n, i, x, b, p, e, disp)
    bytes = Array.new(3)

    bytes[0] = "#{opcode.to_s(2).rjust(8, '0')[0..5]}#{n.to_s(2)}#{i.to_s(2)}".to_i(2)
    bytes[1] = "#{x.to_s(2)}#{b.to_s(2)}#{p.to_s(2)}#{e.to_s(2)}#{disp.to_s(2).rjust(12, '0')[0..3]}".to_i(2)
    bytes[2] = "#{disp.to_s(2).rjust(12, '0')[4..-1]}".to_i(2)

    return bytes.map{|x| sprintf("%02X", x)}.join("")
  end


  def assembleFormat4 (opcode, n, i, x, b, p, e, address)
    bytes = Array.new(4)

    bytes[0] = "#{opcode.to_s(2).rjust(8, '0')[0..5]}#{n.to_s(2)}#{i.to_s(2)}".to_i(2)
    bytes[1] = "#{x.to_s(2)}#{b.to_s(2)}#{p.to_s(2)}#{e.to_s(2)}#{address.to_s(2).rjust(20, '0')[0..3]}".to_i(2)
    bytes[2] = "#{address.to_s(2).rjust(20, '0')[4..11]}".to_i(2)
    bytes[3] = "#{address.to_s(2).rjust(20, '0')[12..-1]}".to_i(2)

    return bytes.map{|x| sprintf("%02X", x)}.join("")
  end
end

# ===========================================
#  Main Routine
# ===========================================

die "Usage: #{$0} [assembly file] [output file]" if ARGV.length != 2

myAssembler = DAssembler.new(ARGV[0], ARGV[1])
myAssembler.assemble!
