module Pem
  module Utils
    require "#{File.dirname(__FILE__)}/utils/config"
    require "#{File.dirname(__FILE__)}/utils/setup"
    require "#{File.dirname(__FILE__)}/utils/modules"
    require "#{File.dirname(__FILE__)}/utils/envs"

    # Merge (recursive) two hashes 
    #
    # Shameless robbed from SO
    # https://stackoverflow.com/questions/8415240/how-to-merge-ruby-hashes
    #
    # @param [Hash] a the first hash to be merged
    # @param [Hash] b the second hash to be merged
    #
    def merge_recursively(a, b)
      a.merge(b) {|key, a_item, b_item| merge_recursively(a_item, b_item) }
    end

  end
end
