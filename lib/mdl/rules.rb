rule "MD001", "Header levels should only increment by one level at a time" do
  tags :headers
  check do |doc|
    headers = doc.find_type(:header)
    old_level = nil
    errors = []
    headers.each do |h|
      if old_level and h[:level] > old_level + 1
        errors << h[:location]
      end
      old_level = h[:level]
    end
    errors
  end
end

rule "MD002", "First header should be a h1 header" do
  tags :headers
  check do |doc|
    first_header = doc.find_type(:header).first
    [first_header[:location]] if first_header and first_header[:level] != 1
  end
end

rule "MD003", "Header style" do
  # Header styles are things like ### and adding underscores
  # See http://daringfireball.net/projects/markdown/syntax#header
  tags :headers
  # :style can be one of :consistent, :atx, :atx_closed, :setext
  params :style => :consistent
  check do |doc|
    headers = doc.find_type_elements(:header)
    if headers.empty?
      nil
    else
      if @params[:style] == :consistent
        doc_style = doc.header_style(headers.first)
      else
        doc_style = @params[:style]
      end
      headers.map { |h| doc.element_linenumber(h) \
                    if doc.header_style(h) != doc_style }.compact
    end
  end
end

rule "MD004", "Unordered list style" do
  tags :bullet, :ul
  # :style can be one of :consistent, :asterisk, :plus, :dash
  params :style => :consistent
  check do |doc|
    bullets = doc.find_type_elements(:ul).map {|l|
      doc.find_type_elements(:li, false, l.children)}.flatten
    if bullets.empty?
      nil
    else
      if @params[:style] == :consistent
        doc_style = doc.list_style(bullets.first)
      else
        doc_style = @params[:style]
      end
      bullets.map { |b| doc.element_linenumber(b) \
                    if doc.list_style(b) != doc_style }.compact
    end
  end
end

rule "MD005", "Inconsistent indentation for list items at the same level" do
  tags :bullet, :ul, :indentation
  check do |doc|
    bullets = doc.find_type(:li)
    errors = []
    indent_levels = []
    bullets.each do |b|
      indent_level = doc.indent_for(doc.element_line(b))
      if indent_levels[b[:element_level]].nil?
        indent_levels[b[:element_level]] = indent_level
      end
      if indent_level != indent_levels[b[:element_level]]
        errors << doc.element_linenumber(b)
      end
    end
    errors
  end
end

rule "MD006", "Consider starting bulleted lists at the beginning of the line" do
  # Starting at the beginning of the line means that indendation for each
  # bullet level can be identical.
  tags :bullet, :ul, :indentation
  check do |doc|
    doc.find_type(:ul, false).select{
      |e| doc.indent_for(doc.element_line(e)) != 0 }.map{ |e| e[:location] }
  end
end

rule "MD007", "Unordered list indentation" do
  tags :bullet, :ul, :indentation
  params :indent => 2
  check do |doc|
    indents = []
    errors = []
    indents = doc.find_type(:ul).map {
      |e| [doc.indent_for(doc.element_line(e)), doc.element_linenumber(e)] }
    curr_indent = indents[0][0] unless indents.empty?
    indents.each do |indent, linenum|
      if indent > curr_indent and indent - curr_indent != @params[:indent]
        errors << linenum
      end
      curr_indent = indent
    end
    errors
  end
end

rule "MD009", "Trailing spaces" do
  tags :whitespace
  check do |doc|
    doc.matching_lines(/\s$/)
  end
end

rule "MD010", "Hard tabs" do
  tags :whitespace, :hard_tab
  check do |doc|
    doc.matching_lines(/\t/)
  end
end

rule "MD011", "Reversed link syntax" do
  tags :links
  check do |doc|
    doc.matching_text_element_lines(/\([^)]+\)\[[^\]]+\]/)
  end
end

rule "MD012", "Multiple consecutive blank lines" do
  tags :whitespace, :blank_lines
  check do |doc|
    # Every line in the document that is part of a code block. Blank lines
    # inside of a code block are acceptable.
    codeblock_lines = doc.find_type_elements(:codeblock).map{
      |e| (doc.element_linenumber(e)..
           doc.element_linenumber(e) + e.value.count('\n') - 1).to_a }.flatten
    blank_lines = doc.matching_lines(/^\s*$/)
    cons_blank_lines = blank_lines.each_cons(2).select{
      |p, n| n - p == 1}.map{|p, n| n}
    cons_blank_lines - codeblock_lines
  end
end

rule "MD013", "Line length" do
  tags :line_length
  params :line_length => 80
  check do |doc|
    doc.matching_lines(/^.{#{@params[:line_length]}}.*\s/)
  end
end

rule "MD014", "Dollar signs used before commands without showing output" do
  tags :code
  check do |doc|
    doc.find_type_elements(:codeblock).select{
      |e| not e.value.split(/\n+/).map{|l| l.match(/^\$\s/)}.include?(nil)
    }.map{|e| doc.element_linenumber(e)}
  end
end

rule "MD018", "No space after hash on atx style header" do
  tags :headers, :atx, :spaces
  check do |doc|
    doc.find_type_elements(:header).select do |h|
      doc.header_style(h) == :atx and doc.element_line(h).match(/^#+[^#\s]/)
    end.map { |h| doc.element_linenumber(h) }
  end
end

rule "MD019", "Multiple spaces after hash on atx style header" do
  tags :headers, :atx, :spaces
  check do |doc|
    doc.find_type_elements(:header).select do |h|
      doc.header_style(h) == :atx and doc.element_line(h).match(/^#+\s\s/)
    end.map { |h| doc.element_linenumber(h) }
  end
end

rule "MD020", "No space inside hashes on closed atx style header" do
  tags :headers, :atx_closed, :spaces
  check do |doc|
    doc.find_type_elements(:header).select do |h|
      doc.header_style(h) == :atx_closed \
        and (doc.element_line(h).match(/^#+[^#\s]/) \
             or doc.element_line(h).match(/[^#\s\\]#+$/))
    end.map { |h| doc.element_linenumber(h) }
  end
end

rule "MD021", "Multiple spaces inside hashes on closed atx style header" do
  tags :headers, :atx_closed, :spaces
  check do |doc|
    doc.find_type_elements(:header).select do |h|
      doc.header_style(h) == :atx_closed \
        and (doc.element_line(h).match(/^#+\s\s/) \
             or doc.element_line(h).match(/\s\s#+$/))
    end.map { |h| doc.element_linenumber(h) }
  end
end

rule "MD022", "Headers should be surrounded by blank lines" do
  tags :headers, :blank_lines
  check do |doc|
    errors = []
    doc.find_type_elements(:header).each do |h|
      header_bad = false
      linenum = doc.element_linenumber(h)
      # Check previous line
      if linenum > 1 and not doc.lines[linenum - 2].empty?
        header_bad = true
      end
      # Check next line
      next_line_idx = doc.header_style(h) == :setext ? linenum + 1 : linenum
      next_line = doc.lines[next_line_idx]
      header_bad = true if not next_line.nil? and not next_line.empty?
      errors << linenum if header_bad
    end
    # Kramdown requires that headers start on a block boundary, so in most
    # cases it won't pick up a header without a blank line before it. We need
    # to check regular text and pick out headers ourselves too
    doc.find_type_elements(:p).each do |p|
      linenum = doc.element_linenumber(p)
      text = p.children.select { |e| e.type == :text }.map {|e| e.value }.join
      lines = text.split("\n")
      prev_lines = ["", ""]
      lines.each do |line|
        # First look for ATX style headers without blank lines before
        if line.match(/^\#{1,6}/) and not prev_lines[1].empty?
          errors << linenum
        end
        # Next, look for setext style
        if line.match(/^(-+|=+)\s*$/) and not prev_lines[0].empty?
          errors << linenum - 1
        end
        linenum += 1
        prev_lines << line
        prev_lines.shift
      end
    end
    errors.sort
  end
end

rule "MD023", "Headers must start at the beginning of the line" do
  tags :headers, :spaces
  check do |doc|
    errors = []
    # The only type of header with spaces actually parsed as such is setext
    # style where only the text is indented. We check for that first.
    doc.find_type_elements(:header).each do |h|
      errors << doc.element_linenumber(h) if doc.element_line(h).match(/^\s/)
    end
    # Next we have to look for things that aren't parsed as headers because
    # they start with spaces.
    doc.find_type_elements(:p).each do |p|
      linenum = doc.element_linenumber(p)
      lines = doc.extract_text(p)
      prev_line = ""
      lines.each do |line|
        # First look for ATX style headers
        if line.match(/^\s+\#{1,6}/)
          errors << linenum
        end
        # Next, look for setext style
        if line.match(/^\s+(-+|=+)\s*$/) and not prev_line.empty?
          errors << linenum - 1
        end
        linenum += 1
        prev_line = line
      end
    end
    errors.sort
  end
end

rule "MD024", "Multiple headers with the same content" do
  tags :headers
  check do |doc|
    header_content = Set.new
    doc.find_type(:header).select do |h|
      not header_content.add?(h[:raw_text])
    end.map { |h| doc.element_linenumber(h) }
  end
end

rule "MD025", "Multiple top level headers in the same document" do
  tags :headers
  check do |doc|
    headers = doc.find_type(:header).select { |h| h[:level] == 1 }
    if not headers.empty? and doc.element_linenumber(headers[0]) == 1
      headers[1..-1].map { |h| doc.element_linenumber(h) }
    end
  end
end

rule "MD026", "Trailing punctuation in header" do
  tags :headers
  params :punctuation => '.,;:!?'
  check do |doc|
    doc.find_type(:header).select {
      |h| h[:raw_text].match(/[#{params[:punctuation]}]$/) }.map {
      |h| doc.element_linenumber(h) }
  end
end

rule "MD027", "Multiple spaces after blockquote symbol" do
  tags :blockquote, :whitespace, :indentation
  check do |doc|
    errors = []
    doc.find_type_elements(:blockquote).each do |e|
      linenum = doc.element_linenumber(e)
      lines = doc.extract_text(e, /^\s*> /)
      lines.each do |line|
        errors << linenum if line.start_with?(" ")
        linenum += 1
      end
    end
    errors
  end
end

rule "MD028", "Blank line inside blockquote" do
  tags :blockquote, :whitespace
  check do |doc|
    def check_blockquote(errors, elements)
      prev = [nil, nil, nil]
      elements.each do |e|
        prev.shift
        prev << e.type
        if prev == [:blockquote, :blank, :blockquote]
          # The current location is the start of the second blockquote, so the
          # line before will be a blank line in between the two, or at least the
          # lowest blank line if there are more than one.
          errors << e.options[:location] - 1
        end
        check_blockquote(errors, e.children)
      end
    end
    errors = []
    check_blockquote(errors, doc.elements)
    errors
  end
end

rule "MD029", "Ordered list item prefix" do
  tags :ol
  # Style can be :one or :ordered
  params :style => :one
  check do |doc|
    if params[:style] == :ordered
      doc.find_type_elements(:ol).map { |l|
        doc.find_type_elements(:li, false, l.children).map.with_index { |i, idx|
          doc.element_linenumber(i) \
            unless doc.element_line(i).strip.start_with?("#{idx+1}. ")
        }
      }.flatten.compact
    elsif params[:style] == :one
      doc.find_type_elements(:ol).map { |l|
        doc.find_type_elements(:li, false, l.children) }.flatten.map { |i|
          doc.element_linenumber(i) \
            unless doc.element_line(i).strip.start_with?('1. ') }.compact
    end
  end
end

rule "MD030", "Spaces after list markers" do
  tags :ol, :ul, :whitespace
  params :ul_single => 1, :ol_single => 1, :ul_multi => 1, :ol_multi => 1
  check do |doc|
    errors = []
    doc.find_type_elements([:ul, :ol]).each do |l|
      list_type = l.type.to_s
      items = doc.find_type_elements(:li, false, l.children)
      # The entire list is to use the multi-paragraph spacing rule if any of
      # the items in it have multiple paragraphs/other block items.
      srule = items.map { |i| i.children.length }.max > 1 ? "multi" : "single"
      items.each do |i|
        actual_spaces = doc.element_line(i).match(/^\s*\S+(\s+)/)[1].length
        required_spaces = params["#{list_type}_#{srule}".to_sym]
        errors << doc.element_linenumber(i) if required_spaces != actual_spaces
      end
    end
    errors
  end
end
