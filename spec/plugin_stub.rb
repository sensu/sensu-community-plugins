shared_context :plugin_stub do
  # XXX: Sensu plugins run in the context of an at_exit handler. This prevents
  # XXX: code-under-test from being run at the end of the rspec suite.
  before(:all) do
    Sensu::Plugin::CLI.class_eval do
      class PluginStub
        def run; end

        def ok(*); end

        def warning(*); end

        def critical(*); end

        def unknown(*); end
      end
      # rubocop:disable all
      @@autorun = PluginStub
      # rubocop:enable all
    end
  end
end
