#!/usr/bin/ruby

PATTERN_1  = /^\s*([a-zA-Z]+)\s*$/ # OPERATOR
PATTERN_2  = /^\s+([+a-zA-Z]+)\s+([\#@='a-zA-Z0-9,]+)\s*$/ # OPERATOR + OPERAND(s)
PATTERN_4  = /^([a-zA-Z]+)\s+([+a-zA-Z]+)\s*$/ # LABEL + OPERATOR
PATTERN_3  = /^\s*([a-zA-Z]+)\s+([+a-zA-Z]+)\s+([\#@='a-zA-Z0-9,]+)\s*$/ # LABEL + OPERATOR + OPERAND(s)

class String
  def label
    return self.scan(PATTERN_4)[0][0].upcase if self.match PATTERN_4
    return self.scan(PATTERN_3)[0][0].upcase if self.match PATTERN_3
    return nil
  end
  def operator
    return self.scan(PATTERN_1)[0][0].upcase if self.match PATTERN_1
    return self.scan(PATTERN_2)[0][0].upcase if self.match PATTERN_2
    return self.scan(PATTERN_4)[0][1].upcase if self.match PATTERN_4
    return self.scan(PATTERN_3)[0][1].upcase if self.match PATTERN_3
    return nil
  end
  def operand
    return self.scan(PATTERN_2)[0][1].upcase if self.match PATTERN_2
    return self.scan(PATTERN_3)[0][2].upcase if self.match PATTERN_3
  end
end

def die (reason)
  STDERR.puts reason
  STDERR.puts "Program halts."
  exit
end

def putserr (string)
  STDERR.puts string
end
