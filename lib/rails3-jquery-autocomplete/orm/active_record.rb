module Rails3JQueryAutocomplete
  module Orm
    module ActiveRecord
      def get_autocomplete_order(method, options, model=nil)
        order = options[:order]

        table_prefix = model ? "#{model.table_name}." : ""
        order || "#{table_prefix}#{method.first} ASC"
      end

      def get_autocomplete_items(parameters)
        model   = parameters[:model]
        term    = parameters[:term]
        method  = Array(parameters[:method])
        options = parameters[:options]
        scopes  = Array(options[:scopes])
        where   = options[:where]
        limit   = get_autocomplete_limit(options)
        order   = get_autocomplete_order(method, options, model)


        items = model.scoped

        scopes.each { |scope| items = items.send(*Array(scope)) } unless scopes.empty?

        items = items.select(get_autocomplete_select_clause(model, method, options)) unless options[:full_model]
        items = items.where(get_autocomplete_where_clause(model, term, method, options)).
            limit(limit).order(order)
        items = items.where(where) unless where.blank?

        current_ability ? items.accessible_by(current_ability) : items
      end

      def get_autocomplete_select_clause(model, method, options)
        table_name = model.table_name
        (["#{table_name}.#{model.primary_key}", "#{table_name}.#{method.first}"] + (options[:extra_data].blank? ? [] : options[:extra_data]))
      end

      def get_autocomplete_where_clause(model, term, method, options)
        table_name = model.table_name
        is_full_search = options[:full]
        like_clause = (postgres?(model) ? 'ILIKE' : 'LIKE')
        
        where_clause = ["LOWER(#{table_name}.#{method}) #{like_clause} ?", "#{(is_full_search ? '%' : '')}#{term.downcase}%"]
        
        if options.has_key?(:extra_data) && options[:extra_data].count >= 1
          where_string = "LOWER(#{table_name}.#{method}) #{like_clause} ?"
          arg = "#{(is_full_search ? '%' : '')}#{term.downcase}%"

          options[:extra_data].each { |data| where_string += " OR LOWER(#{table_name}.#{data}) #{like_clause} ?" }
          
          where_clause = [where_string]
          (1..options[:extra_data].count+1).each { |i| where_clause.push(arg) }
        end

        where_clause
      end

      def postgres?(model)
        # Figure out if this particular model uses the PostgreSQL adapter
        model.connection.class.to_s.match(/PostgreSQLAdapter/)
      end
    end
  end
end
