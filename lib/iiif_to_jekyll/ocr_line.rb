class OcrLine
  # upper left corner coordinates
  attr_accessor :x_min, :y_min

  # bottom right corner coordinates
  attr_accessor :x_max, :y_max

  # child annotations
  attr_accessor :annotations

  def initialize
    self.annotations = []
    self.x_min = nil
    self.x_max = nil
    self.y_min = nil
    self.y_max = nil
  end

  def width
    x_max - x_min
  end

  def height
    y_max - y_min
  end

  def font_size
    total_height = annotations.inject(0) { |accum, anno| accum += anno.h_px }
    total_height / annotations.count # mean height
  end

  def ends_farther_right_than_beginning_of?(next_word)
    self.x_max > next_word.x_px
  end

  def bottom_higher_than_top_of?(next_word)
    self.y_max < next_word.y_px
  end

  # tests to see if an annotation starts a new line or not
  def ends_before?(next_word)
    if self.bottom_higher_than_top_of?(next_word)
      # this is clear-cut -- the new word's top is below this line's bottom
#      print "\tbottom of line #{self.y_max} higher than top of next word (#{next_word.text}) #{next_word.y_px}\n"
      return true
    else
      # ambiguous scenario: a real new line could start above our bottom due to positive degree skewing
      # TODO: test with highly skewed works in both directions

      # a real continuation will have similar y values, but will start further left than our line ends
      # (so our line ends farther right then the beginning fo the new word)
      if self.ends_farther_right_than_beginning_of?(next_word)
#        print "\tline ends farther right #{self.x_max} than beginning of next word (#{next_word.text}) #{next_word.x_px}\n"
        return true
      end  
    end
    false
  end

  def add_word(next_word)
    annotations << next_word
    if x_min.nil?
      # initialize to the first word's values
      self.x_min = next_word.x_px
      self.x_max = next_word.right_x
      self.y_min = next_word.y_px
      self.y_max = next_word.bottom_y
    else
      # compare with extisting values and set accordingly
      if self.x_min > next_word.x_px
        # SHOULD NEVER HAPPEN! Drop into debugger to figure out what went wrong
        binding.pry
        self.x_min = next_word.x_px
      end
      if self.x_max < next_word.right_x
        # should always happen, since we're tacking words onto a line if we're here
        self.x_max = next_word.right_x
      end
      if self.y_min > next_word.y_px
        # can happen due to skew and OCR bbox drift
        self.y_min = next_word.y_px
      end
      if self.y_max < next_word.bottom_y
        # can happen due to skew and OCR bbox drift
        self.y_max = next_word.bottom_y
      end
    end

    self
  end


  def self.lines_from_words(annotations)
    # for each annotation on this canvas
    # does it start a new line?
    # how do we decide this?  new lines should be below previous lines, and
    # may be to the left of previous words
    #
    # A (straightforward):
    # one two three
    # four five
    #
    # in A, two.x > one.x or (one.x+one.w)
    # in A, two.y should be _close_ to one.y, but possibly above or below it
    # in A, [one two].x_min << three.x, and [one two].x_max < three.x
    # in A, [one two].y_min =~ three.y, and [one two].y_max =~ three.x
    # in A, [one two three].x_min =~ four.x
    # in A, [one two three].x_max >> four,x
    # in A, [one two three].y_min << four.y
    # in A, [one two three].y_max < four.y


    # B (indentation):
    # one two three
    # four
    #      five six
    #
    # [one two three] <=> four as in A
    # four.x << five.x
    # [four].x_max < five.x
    # [four].x_min << five.x
    # above are identical in profile to four <=> five in A, even though five starts a new line in B
    # [four].y_min << five.y
    # [four].y_max < five.y
    # [four].y_max << five.y+five.h


    # C (extreme skew):
    # one 
    #      two
    # four      three
    #      five

    # (test for new x < old x to see if this word is farther to the left then the last word)
    # OR (test for y > old y+h to see if this line starts below where the previous word ended)

    lines = []
    this_line = OcrLine.new

    annotations.each do |next_word|
#      binding.pry
#      print "#{next_word.x_px},#{next_word.y_px}\n"
      if this_line.annotations.empty? && lines.empty?
        # handle starting scenario
#        print "\tfirst word -- adding\t#{next_word.text}\n"
        this_line.add_word(next_word)
      else      
        if this_line.ends_before?(next_word)
#          print "\tstarting new line\t#{next_word.text}\n"
          lines << this_line
          this_line = OcrLine.new
          this_line.add_word(next_word)
        else
#          print "\tcontinuation--adding\t#{next_word.text}\n"
          this_line.add_word(next_word)
        end
      end
    end
    lines << this_line unless this_line.annotations.empty? # add the last line

    lines
  end

end


