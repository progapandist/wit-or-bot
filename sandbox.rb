require_relative 'rubotnik/wit_understander'

understander = Rubotnik::WitUnderstander.new("ZI243GVZYMZFWGIFMGI4PNUNLGVFLFUZ")
p understander.full_response("What should I do?")
