# Source code for constructing a covering grammar, with error productions, for a grammar in Chomsky Normal Form (CNF).
# Also includes methods for eliminating epsilon and unit productions in order to keep the grammar in CNF.

class Production
  attr_accessor :left, :right, :dist

  # A production can be given as a string in one of the following format:
  # "A->BC"
  # "A->a"
  # "A->B"
  # "A->"    (means "A->epsilon")
  # "A2->BC" (means A->BC with 2 errors)
  # ... 
  #
  # Works only with single letter non-terminals and at most two non-terminals on the right side
  def initialize(str)
    @left = str[0]
    arrowPos = str.index("->")
    distStr = str[1..arrowPos-1]
    if distStr=='' then
       @dist = 0
    else
       @dist = Integer(distStr)
    end
    @right = str[arrowPos+2..-1]
  end

  def self.fromArr(p)
    p.map{|s| Production.new(s)}
  end 

  # True if production has form A->a  
  def terminal
    @right.length == 1 and @right[0] == @right[0].downcase
  end

  # True if production has form A->epsilon 
  def epsilon
    @right.length == 0
  end

  # True if production has form A->B 
  def unit
    @right.length == 1 and not terminal
  end

  # printable string in the format A->[1]BC or A->BC or A->a or A->[1]a etc.
  def to_s
    a=@left+"->"
    if @dist == 0 then
      a+=@right 
    else
      a+="[#{@dist}]#{@right}" 
    end
    if @right.length==0 then 
      a+="epsilon"
    end
    # ugly hack just for example in the paper
    #a.gsub "C","A1"
    a
  end
end

# Adds productions for insert, delete, replace
def constructCover(p, t, n)
  q = p.clone
  q += Production.fromArr(["H->HI", "H->I"])
  q += Production.fromArr(t.map{|a| "I1->#{a}"})
  p.each do |pr|
    if pr.terminal then # A->a
      #substitution
      t.each do |b|
        if b != pr.right then
          q.push(Production.new("#{pr.left}1->#{b}")) # A->b
        end
      end

      # deletion
      q.push(Production.new("#{pr.left}1->")) # A->epsilon

      # series of insertions
      q.push(Production.new("#{pr.left}->H#{pr.left}")) # A->HA
      q.push(Production.new("#{pr.left}->#{pr.left}H")) # A->AH 
     
    end
  end
  q
end

# Tries to add production pr to array p unless a "better" production already exists
def tryAdd(p, pr)
  #puts "Trying to add", pr
  i = p.index {|q| q.left == pr.left and q.right == pr.right}
  if i != nil then
    pi = p[i]
    if pi.dist <= pr.dist then
      # nothing to do
      return false
    else
      p[i]=pr
      return true
    end
  end
  p.push(pr)
  return true
end

# Adds all derived productions of the form A->epsilon
def addAllNullable(p)
  p = p.clone
  loop do
    more=false
    p.each do |pr|
      if pr.right.length == 2 then # A->BC
        ib = p.index {|q| q.left == pr.right[0] and q.epsilon } # B->epsilon
        ic = p.index {|q| q.left == pr.right[1] and q.epsilon } # C->epsilon
        if ib != nil and ic != nil then
           pb=p[ib]
           pc=p[ic]
           if tryAdd(p, Production.new("#{pr.left}#{pb.dist+pc.dist}->")) # A->epsilon
             more = true
	   end
        end
      end
    end
    break if !more 
  end
  p
end

# Eliminates all epsilon productions by adding new unit productions
def eliminateEpsilon(p)
    p = p.clone
    p.each do |pr|
      if pr.epsilon then # A->epsilon
        p.each do |pab|
          if pab.right.length==2 and pab.right[0] == pr.left then  # C->AB
             tryAdd(p, Production.new("#{pab.left}#{pr.dist}->#{pab.right[1]}")) # C->B
          end
          if pab.right.length==2 and pab.right[1] == pr.left then  # C->BA
             tryAdd(p, Production.new("#{pab.left}#{pr.dist}->#{pab.right[0]}")) # C->B
          end
        end
      end
    end
    p.delete_if { |pr| pr.epsilon }
end

# Adds all derived unit productions of the form A->B
def addAllUnit(p)
  p = p.clone
  loop do
    more=false
    p.each do |pr|
      if pr.unit then # A->B
        ib = p.index {|q| q.left == pr.right[0] and q.unit and q.right[0] != pr.left } # B->C
        if ib != nil then
           pb=p[ib]
           if tryAdd(p, Production.new("#{pr.left}#{pr.dist+pb.dist}->#{pb.right}")) # A->C
             more = true
	   end
        end
      end
    end
    break if !more 
  end
  p
end

# Eliminates all unit productions by adding new CNF productions of the form A->a or A->BC
def eliminateUnit(p)
    p = p.clone
    p.each do |pr|
      if pr.unit then # A->B
        p.each do |pb|
          if pr.right[0] == pb.left then # B->...
            if pb.terminal or pb.right.length==2 then   # B->b or B->CD
              tryAdd(p, Production.new("#{pr.left}#{pr.dist+pb.dist}->#{pb.right}")) # A->b or A->CD
            end
          end
        end
      end
    end
    p.delete_if { |pr| pr.unit }
end

# Example for a^nb^n grammar
p=Production.fromArr ["S->AC", "S->AB", "C->SB", "A->a", "B->b"]
n=["S","A","B","C"]
t=["a","b"]

puts "Original productions:",p

q=p
p=constructCover(p,t,n)
puts "Add cover productions:"
puts p-q

q=p
p=addAllNullable(p)
puts "Add nullable productions:"
puts p-q

q=p
p=eliminateEpsilon(p)
puts "Eliminate epsilon; new productions:"
puts p-q

q=p
p=addAllUnit(p)
puts "Add derived unit productions:"
puts p-q

q=q
p=eliminateUnit(p)
puts "Eliminate unit; new productions:"
puts p-q

puts "Final grammar", p

