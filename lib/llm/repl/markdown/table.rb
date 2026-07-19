# frozen_string_literal: true

class LLM::Repl::Markdown
  ##
  # Renders Kramdown `:table` nodes as aligned columns.
  module Table
    ##
    # Renders a table node by collecting all cells first to
    # compute column widths, then emitting each row with
    # padded text.
    def walk_table(node, attrs)
      rows = collect_rows(node, attrs)
      return if rows.empty?
      widths = column_widths(rows)
      rows.each do |row|
        emit("| ", attrs)
        row.each_with_index do |chunks, i|
          text = chunks.map { _1[:text] }.join
          width = widths[i]
          chunks.each { |c| emit(c[:text].ljust(width), c[:attrs]) }
          emit(" | ", attrs) unless i == row.size - 1
        end
        emit(" |", attrs)
        emit("\n", attrs)
      end
      emit("\n", attrs)
    end

    private

    def collect_rows(node, attrs)
      node.children.each_with_object([]) do |section, rows|
        next unless [:thead, :tbody].include?(section.type)
        section.children.each do |tr|
          next unless tr.type == :tr
          cells = tr.children.filter_map do |td|
            next unless [:td, :th].include?(td.type)
            collect_chunks(td, attrs)
          end
          rows << cells
        end
      end
    end

    def collect_chunks(node, attrs)
      [].tap do |chunks|
        walk_collect(node, attrs, chunks)
      end
    end

    def walk_collect(node, attrs, chunks)
      case node.type
      when :text
        chunks << {text: node.value.to_s, attrs:}
      when :strong
        node.children.each { walk_collect(_1, Curses::A_BOLD, chunks) }
      when :em
        node.children.each { walk_collect(_1, Curses::A_UNDERLINE, chunks) }
      when :codespan
        chunks << {text: node.value, attrs: Curses::A_REVERSE}
      when :a
        node.children.each { walk_collect(_1, Curses::A_UNDERLINE, chunks) }
      else
        node.children.each { walk_collect(_1, attrs, chunks) }
      end
    end

    def column_widths(rows)
      return [] if rows.empty?
      cols = rows.first.size
      (0...cols).map do |i|
        rows.map { |r| r[i].map { _1[:text] }.join.length }.max
      end
    end
  end
end
