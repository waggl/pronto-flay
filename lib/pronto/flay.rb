require 'pronto'
require 'flay'

module Pronto
  class Flay < Runner
    def initialize
      @flay = ::Flay.new
    end

    def run(patches)
      return [] unless patches

      ruby_patches = patches.select { |patch| patch.additions > 0 }
                            .select { |patch| ruby_file?(patch.new_file_full_path) }

      files = ruby_patches.map { |patch| File.new(patch.new_file_full_path) }

      if files.any?
        @flay.process(*files)
        @flay.analyze
        masses = Array(@flay.masses)

        messages_from(masses, ruby_patches)
      else
        []
      end
    end

    def messages_from(masses, ruby_patches)
      masses.map do |mass|
        hash = mass.first

        nodes(hash).map do |node|
          patch = patch_for_node(ruby_patches, node)

          line = patch.added_lines.select do |added_line|
            added_line.new_lineno == node.line
          end.first

          new_message(line, node) if line
        end
      end.flatten.compact
    end

    def patch_for_node(ruby_patches, node)
      ruby_patches.select do |patch|
        patch.new_file_full_path.to_s == node.file.path
      end.first
    end

    def new_message(line, node)
      hash = node.structural_hash
      patch = line.owner.owner
      Message.new(patch.delta.new_file[:path], line, level(hash), message(hash))
    end

    def level(hash)
      same?(hash) ? :error : :warning
    end

    def same?(hash)
      @flay.identical[hash]
    end

    def message(hash)
      match = same?(hash) ? 'Identical' : 'Similar'
      location = nodes(hash).map do |node|
        "#{File.basename(node.file.path)}:#{node.line}"
      end

      "#{match} code found in #{location.join(', ')}"
    end

    def nodes(hash)
      @flay.hashes[hash]
    end
  end
end
