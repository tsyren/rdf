module RDF
  ##
  # An RDF basic graph pattern query.
  #
  # @example Filtering solutions using a hash
  #   query.filter(:author  => RDF::URI.new("http://ar.to/#self"))
  #   query.filter(:author  => "Arto Bendiken")
  #   query.filter(:author  => [RDF::URI.new("http://ar.to/#self"), "Arto Bendiken"])
  #   query.filter(:updated => RDF::Literal.new(Date.today))
  #
  # @example Filtering solutions using a block
  #   query.filter { |solution| solution.author.literal? }
  #   query.filter { |solution| solution.title =~ /^SPARQL/ }
  #   query.filter { |solution| solution.price < 30.5 }
  #   query.filter { |solution| solution.bound?(:date) }
  #   query.filter { |solution| solution.age.datatype == RDF::XSD.integer }
  #   query.filter { |solution| solution.name.language == :es }
  #
  # @example Reordering solutions based on a variable
  #   query.order_by(:updated)
  #   query.order_by(:updated, :created)
  #
  # @example Selecting particular variables only
  #   query.select(:title)
  #   query.select(:title, :description)
  #
  # @example Eliminating duplicate solutions
  #   query.distinct!
  #
  # @example Limiting the number of solutions
  #   query.offset(25).limit(10)
  #
  # @example Counting the number of solutions
  #   query.count
  #
  # @example Iterating over all found solutions
  #   query.each_solution { |solution| puts solution.inspect }
  #
  class Query
    autoload :Pattern,  'rdf/query/pattern'
    autoload :Solution, 'rdf/query/solution'
    autoload :Variable, 'rdf/query/variable'

    include ::Enumerable

    # @return [Hash{Symbol => Variable}]
    attr_reader :variables

    # @return [Array<Pattern>]
    attr_reader :patterns

    # @return [Array<Hash{Symbol => Value}>] An unordered sequence of query solutions.
    attr_accessor :solutions

    ##
    # @param  [Hash{Symbol => Object}] options
    # @yield  [query]
    # @yieldparam [Query]
    def initialize(options = {}, &block)
      @variables = options.delete(:variables) || {}
      @patterns  = options.delete(:patterns)  || []
      @solutions = options.delete(:solutions) || []
      @options   = options

      if block_given?
        case block.arity
          when 1 then block.call(self)
          else instance_eval(&block)
        end
      end
    end

    ##
    # Enumerates over each query solution.
    #
    # @yield  [solution]
    # @yieldparam [Solution]
    # @return [Enumerator]
    def each_solution(&block)
      solutions.each do |bindings|
        block.call(Solution.new(bindings))
      end
    end

    alias_method :each, :each_solution

    ##
    # Returns the number of query solutions.
    #
    # @return [Integer]
    def size
      solutions.size
    end

    alias_method :count, :size

    ##
    # Filters the solution sequence by the given criteria.
    #
    # @param  [Hash{Symbol => Object}] criteria
    # @yield  [solution]
    # @yieldparam  [Solution] solution
    # @yieldreturn [Boolean]
    # @return [Query]
    def filter(criteria = {}, &block)
      if block_given?
        solutions.reject! do |bindings|
          !block.call(Solution.new(bindings))
        end
      else
        solutions.reject! do |bindings|
          results = criteria.map do |name, value|
            bindings[name] == value
          end
          !results.all?
        end
      end
      self
    end

    alias_method :filter!, :filter

    ##
    # Reorders the solution sequence based on `variables`.
    #
    # @param  [Array<Symbol>] variables
    # @return [Query]
    def order(*variables)
      if variables.empty?
        raise ArgumentError.new("wrong number of arguments (0 for 1)")
      else
        # TODO: support for descending sort, e.g. order(:s => :asc, :p => :desc)
        variables.map! { |variable| variable.to_sym }
        solutions.sort! do |a, b|
          a = variables.map { |variable| a[variable].to_s }
          b = variables.map { |variable| b[variable].to_s }
          a <=> b
        end
      end
      self
    end

    alias_method :order_by, :order

    ##
    # Restricts the the solution sequence to the given `variables` only.
    #
    # @param  [Array<Symbol>] variables
    # @return [Query]
    def project(*variables)
      unless variables.empty?
        variables.map! { |variable| variable.to_sym }
        solutions.each do |bindings|
          bindings.delete_if { |k, v| !variables.include?(k) }
        end
      end
      self
    end

    alias_method :select, :project

    ##
    # Ensures solutions in the solution sequence are unique.
    #
    # @return [Query]
    def distinct
      solutions.uniq!
      self
    end

    alias_method :distinct!, :distinct
    alias_method :reduced,   :distinct
    alias_method :reduced!,  :distinct

    ##
    # Limits the solution sequence to bindings starting from the `start`
    # offset in the overall solution sequence.
    #
    # @param  [Integer] start
    # @return [Query]
    def offset(start)
      slice(start, solutions.size - start)
    end

    ##
    # Limits the number of solutions to `length`.
    #
    # @param  [Integer] length
    # @return [Query]
    def limit(length)
      slice(0, length)
    end

    ##
    # Limits the solution sequence to `length` bindings starting from the
    # `start` offset in the overall solution sequence.
    #
    # @param  [Integer] start
    # @param  [Integer] length
    # @return [Query]
    def slice(start, length)
      if start < solutions.size
        solutions.slice!(start, length)
      else
        solutions = []
      end
      self
    end

    alias_method :slice!, :slice
  end
end
