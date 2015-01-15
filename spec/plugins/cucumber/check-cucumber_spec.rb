#! /usr/bin/env ruby
#
#   check-cucumber_spec
#
# DESCRIPTION:
#
# OUTPUT:
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: check-cucumber
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require_relative '../../../plugins/cucumber/check-cucumber'
require_relative '../../../spec_helper'

describe CheckCucumber do
  check_cucumber = nil
  default_args = [
    '--name',
    'example-name',
    '--handler',
    'example-handler',
    '--metric-handler',
    'example-metric-handler',
    '--metric-prefix',
    'example-metric-prefix',
    '--command',
    'cucumber-js features/',
    '--working-dir',
    'example-working-dir'
  ]

  before(:each) do
    check_cucumber = CheckCucumber.new
  end

  describe 'run()' do
    args = nil

    before(:each) do
      args = []
    end

    describe 'when it checks the config' do
      before(:each) do
        args = default_args.dup
        check_cucumber = CheckCucumber.new(args)
      end

      describe 'when the config is valid' do
        before(:each) do
          expect(check_cucumber).to receive('config_is_valid?') { true }
        end

        it 'executes Cucumber' do
          expect(check_cucumber).to receive('execute_cucumber') do
            { results: '[]', exit_status: 0 }
          end
          check_cucumber.run
        end
      end

      describe 'when the config is invalid' do
        before(:each) do
          expect(check_cucumber).to receive('config_is_valid?') { false }
        end

        it 'does not execute Cucumber' do
          expect(check_cucumber).to_not receive('execute_cucumber')
          check_cucumber.run
        end
      end
    end

    describe 'when all the mandatory config has been specified' do
      before(:each) do
        args = default_args.dup
        check_cucumber = CheckCucumber.new(args)
        check_cucumber.stub(:send_sensu_event) {}
      end

      describe 'when cucumber executes and provides results' do
        results = nil

        before(:each) do
          results = []
          expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 0.0) do
            { results: results.to_json, exit_status: 0 }
          end
          Time.stub_chain(:now, :getutc, :to_i) { 123 }
        end

        describe 'when there are no features' do
          it 'returns warning' do
            expect(check_cucumber).to receive('warning').with(generate_output(status: :warning, scenarios: 0))
          end

          it 'does not raise any events' do
            expect(check_cucumber).to receive('raise_sensu_events').with([]) do
              []
            end
          end
        end

        describe 'when there are no scenarios' do
          before(:each) do
            feature = generate_feature
            feature.delete :elements
            results << feature
          end

          it 'returns warning' do
            expect(check_cucumber).to receive('warning').with(generate_output(status: :warning, scenarios: 0))
          end

          it 'does not raise any events' do
            expect(check_cucumber).to receive('raise_sensu_events').with([]) do
              []
            end
          end
        end

        describe 'when there is a scenario with no steps' do
          before(:each) do
            feature = generate_feature(scenarios: [{ step_statuses: [] }])
            feature[:elements][0].delete :steps
            results << feature
          end

          it 'returns ok' do
            expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 1, passed: 1))
          end

          it 'raises an ok event' do
            sensu_event = generate_sensu_event(status: :passed, results: results)
            expect(check_cucumber).to receive('raise_sensu_events').with([sensu_event]) do
              []
            end
          end
        end

        describe 'when there is a passing step' do
          before(:each) do
            results << generate_feature(scenarios: [{ step_statuses: :passed }])
          end

          it 'returns ok' do
            expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 1, passed: 1))
          end

          it 'raises an ok event and a metric event' do
            sensu_events = []
            sensu_events << generate_sensu_event(status: :passed, results: results)
            sensu_events << generate_metric_event(status: :passed, results: results)
            expect(check_cucumber).to receive('raise_sensu_events').with(sensu_events) do
              []
            end
          end
        end

        describe 'when there is a step with no result' do
          before(:each) do
            feature = generate_feature(scenarios: [{ step_statuses: :passed }])
            feature[:elements][0][:steps][0].delete :result
            results << feature
          end

          it 'returns ok' do
            expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 1, passed: 1))
          end

          it 'raises an ok event and a metric event' do
            sensu_event = generate_sensu_event(status: :passed, results: results)
            expect(check_cucumber).to receive('raise_sensu_events').with([sensu_event]) do
              []
            end
          end
        end

        describe 'when there is a passing step followed by a failing step' do
          before(:each) do
            results << generate_feature(scenarios: [{ step_statuses: [:passed, :failed] }])
          end

          it 'returns ok' do
            expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 1, failed: 1))
          end

          it 'raises a critical event' do
            sensu_event = generate_sensu_event(status: :failed, results: results)
            expect(check_cucumber).to receive('raise_sensu_events').with([sensu_event]) do
              []
            end
          end
        end

        describe 'when there is a passing step followed by a pending step' do
          before(:each) do
            results << generate_feature(scenarios: [{ step_statuses: [:passed, :pending] }])
          end

          it 'returns ok' do
            expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 1, pending: 1))
          end

          it 'raises a warning event' do
            sensu_event = generate_sensu_event(status: :pending, results: results)
            expect(check_cucumber).to receive('raise_sensu_events').with([sensu_event]) do
              []
            end
          end
        end

        describe 'when there is a passing step followed by a undefined step' do
          before(:each) do
            results << generate_feature(scenarios: [{ step_statuses: [:passed, :undefined] }])
          end

          it 'returns ok' do
            expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 1, undefined: 1))
          end

          it 'raises a warning event' do
            sensu_event = generate_sensu_event(status: :undefined, results: results)
            expect(check_cucumber).to receive('raise_sensu_events').with([sensu_event]) do
              []
            end
          end
        end

        describe 'when there is a background' do
          before(:each) do
            results << generate_feature(has_background: true, scenarios: [{ step_statuses: [] }])
          end

          it 'returns ok' do
            expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 1, passed: 1))
          end

          it 'raises an ok event' do
            sensu_events = []
            sensu_events << generate_sensu_event(status: :passed, results: results)
            expect(check_cucumber).to receive('raise_sensu_events').with(sensu_events) do
              []
            end
          end
        end

        describe 'when there are multiple scenarios' do
          before(:each) do
            results << generate_feature(scenarios: [{ step_statuses: :passed }, { step_statuses: :passed }])
          end

          it 'returns ok' do
            expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 2, passed: 2))
          end

          it 'raises multiple ok events and multiple metric events' do
            sensu_events = []
            sensu_events << generate_sensu_event(status: :passed, scenario_index: 0, results: results)
            sensu_events << generate_metric_event(status: :passed, scenario_index: 0, results: results)
            sensu_events << generate_sensu_event(status: :passed, scenario_index: 1, results: results)
            sensu_events << generate_metric_event(status: :passed, scenario_index: 1, results: results)
            expect(check_cucumber).to receive('raise_sensu_events').with(sensu_events) do
              []
            end
          end
        end

        describe 'when there are multiple features' do
          before(:each) do
            results << generate_feature(feature_index: 0, scenarios: [{ step_statuses: :passed }])
            results << generate_feature(feature_index: 1, scenarios: [{ step_statuses: :passed }])
          end

          it 'returns ok' do
            expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 2, passed: 2))
          end

          it 'raises multiple ok events and multiple metric events' do
            sensu_events = []
            sensu_events << generate_sensu_event(status: :passed, feature_index: 0, scenario_index: 0, results: results)
            sensu_events << generate_metric_event(status: :passed, feature_index: 0, scenario_index: 0, results: results)
            sensu_events << generate_sensu_event(status: :passed, feature_index: 1, scenario_index: 0, results: results)
            sensu_events << generate_metric_event(status: :passed, feature_index: 1, scenario_index: 0, results: results)
            expect(check_cucumber).to receive('raise_sensu_events').with(sensu_events) do
              []
            end
          end
        end

        describe 'when there is an error raising an event' do
          before(:each) do
            results << generate_feature(scenarios: [{ step_statuses: :passed }])
            sensu_events = []
            sensu_events << generate_sensu_event(status: :passed, feature_index: 0, scenario_index: 0, results: results)
            sensu_events << generate_metric_event(status: :passed, feature_index: 0, scenario_index: 0, results: results)
            expect(check_cucumber).to receive('raise_sensu_events').with(sensu_events) do
              [{ 'message' => 'example-message-1' }]
            end
          end

          it 'returns unknown, with the scenario counts and the error' do
            expected_output = generate_output(status: :unknown, scenarios: 1, passed: 1, errors: 'example-message-1')
            expect(check_cucumber).to receive('unknown').with(expected_output)
          end
        end

        describe 'when the Cucumber results JSON contains a UTF-8 character' do
          before(:each) do
            results << generate_feature(feature_description: "Contains the \u2190 leftwards arrow character".encode('utf-8'),
                                        scenarios: [{ step_statuses: :passed }])
          end

          it 'returns ok' do
            expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 1, passed: 1))
          end

          it 'raises an ok event and a metric event' do
            sensu_events = []
            sensu_events << generate_sensu_event(status: :passed, results: results)
            sensu_events << generate_metric_event(status: :passed, results: results)
            expect(check_cucumber).to receive('raise_sensu_events').with(sensu_events) do
              []
            end
          end
        end

        describe 'when using a variant of Cucumber that includes profile names in the Cucumber results (e.g. parallel-cucumber)' do
          before(:each) do
            results << generate_feature(profile: 'example-profile', scenarios: [{ step_statuses: :passed }])
          end

          it 'returns ok' do
            expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 1, passed: 1))
          end

          it 'raises an ok event and a metric event' do
            sensu_events = []
            sensu_events << generate_sensu_event(name: 'example-name.Feature-0.scenario-0.example-profile',
                                                 status: :passed, results: results)
            sensu_events << generate_metric_event(name: 'example-name.Feature-0.scenario-0.example-profile.metrics',
                                                  metric_prefix: 'example-metric-prefix.Feature-0.scenario-0.example-profile',
                                                  status: :passed, results: results)
            expect(check_cucumber).to receive('raise_sensu_events').with(sensu_events) do
              []
            end
          end
        end

        describe 'when the Cucumber results include attachments' do
          before(:each) do
            results << generate_feature(scenarios: [{ step_statuses: :passed,
                                                      step_attachments: [{ data: 'example-data',
                                                                           mime_type: 'text/plain' }] }])
          end

          describe 'when configured to include attachments in events' do
            before(:each) do
              check_cucumber.config[:attachments] = 'true'
            end

            it 'returns ok' do
              expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 1, passed: 1))
            end

            it 'raises an ok event and a metric event' do
              sensu_events = []
              sensu_events << generate_sensu_event(status: :passed, results: results)
              sensu_events << generate_metric_event(status: :passed, results: results)
              expect(check_cucumber).to receive('raise_sensu_events').with(sensu_events) do
                []
              end
            end
          end

          describe 'when configured not to include attachments in events' do
            before(:each) do
              check_cucumber.config[:attachments] = 'false'
            end

            it 'returns ok' do
              expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 1, passed: 1))
            end

            it 'raises an ok event and a metric event' do
              sensu_events = []
              sensu_events << generate_sensu_event(exclude_attachments: true,
                                                   status: :passed, results: results)
              sensu_events << generate_metric_event(status: :passed, results: results)
              expect(check_cucumber).to receive('raise_sensu_events').with(sensu_events) do
                []
              end
            end
          end
        end

        after(:each) do
          check_cucumber.run
        end
      end

      describe 'when cucumber exits with the exit code 0, indicating all scenarios passed' do
        before(:each) do
          results = [generate_feature(scenarios: [{ step_statuses: :passed }])]
          expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 0.0) do
            { results: results.to_json, exit_status: 0 }
          end
          expect(check_cucumber).to receive('raise_sensu_events') do
            []
          end
        end

        it 'returns ok' do
          expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 1, passed: 1))
          check_cucumber.run
        end
      end

      describe 'when cucumber exits with the exit code 1, indicating some or all scenarios failed' do
        before(:each) do
          results = [generate_feature(scenarios: [{ step_statuses: :passed }])]
          expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 0.0) do
            { results: results.to_json, exit_status: 1 }
          end
          expect(check_cucumber).to receive('raise_sensu_events') do
            []
          end
        end

        it 'returns ok' do
          expect(check_cucumber).to receive('ok').with(generate_output(status: :ok, scenarios: 1, passed: 1))
          check_cucumber.run
        end
      end

      describe 'when cucumber exits with the exit code -1, indicating an error' do
        before(:each) do
          expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 0.0) do
            { results: '', exit_status: -1 }
          end
        end

        it 'returns unknown' do
          expect(check_cucumber).to receive('unknown').with(generate_unknown_error('Cucumber returned exit code -1'))
          check_cucumber.run
        end
      end

      describe 'when cucumber exits with the exit code 2, indicating an error' do
        before(:each) do
          expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 0.0) do
            { results: '', exit_status: 2 }
          end
        end

        it 'returns unknown' do
          expect(check_cucumber).to receive('unknown').with(generate_unknown_error('Cucumber returned exit code 2'))
          check_cucumber.run
        end
      end
    end

    describe 'when an environment variable is specified' do
      before(:each) do
        args = default_args.dup
        args << '--env'
        args << 'NAME1=VALUE1'
        check_cucumber = CheckCucumber.new(args)
      end

      it 'passes the environment variable to Cucumber' do
        expected_env = { 'NAME1' => 'VALUE1' }
        expect(check_cucumber).to receive('execute_cucumber').with(expected_env, 'cucumber-js features/', 'example-working-dir', 0.0) do
          { results: '[]', exit_status: 0 }
        end
      end

      after(:each) do
        check_cucumber.run
      end
    end

    describe 'when multiple environment variables are specified' do
      before(:each) do
        args = default_args.dup
        args << '--env'
        args << 'NAME1=VALUE1'
        args << '--env'
        args << 'NAME2=VALUE2'
        check_cucumber = CheckCucumber.new(args)
      end

      it 'passes all the environment variables to Cucumber' do
        expected_env = { 'NAME1' => 'VALUE1', 'NAME2' => 'VALUE2' }
        expect(check_cucumber).to receive('execute_cucumber').with(expected_env, 'cucumber-js features/', 'example-working-dir', 0.0) do
          { results: '[]', exit_status: 0 }
        end
      end

      after(:each) do
        check_cucumber.run
      end
    end

    describe 'when a timeout is specified' do
      before(:each) do
        args = default_args.dup
        args << '--timeout'
        args << '123'
        check_cucumber = CheckCucumber.new(args)
      end

      it 'passes the environment variable to Cucumber' do
        expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 123) do
          { results: '[]', exit_status: 0 }
        end
      end

      describe 'when Cucumber execution exceeds the timeout' do
        before(:each) do
          expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 123) do
            fail Timeout::Error, 'Cucumber timed out'
          end
        end

        it 'returns unknown' do
          expect(check_cucumber).to receive('unknown').with(generate_unknown_error('Cucumber exceeded the timeout of 123.0 seconds'))
        end
      end

      after(:each) do
        check_cucumber.run
      end
    end

    describe 'when event data is specified' do
      results = nil
      event_data = nil

      before(:each) do
        results = []
        results << generate_feature(feature_index: 0, scenarios: [{ step_statuses: :passed }])
        results << generate_feature(feature_index: 1, scenarios: [{ step_statuses: :passed }])
        Time.stub_chain(:now, :getutc, :to_i) { 123 }
      end

      describe 'when there is a single event data item' do
        before(:each) do
          args = default_args.dup
          args << '--event-data'
          args << 'NAME1=VALUE1'
          check_cucumber = CheckCucumber.new(args)
          expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 0.0) do
            { results: results.to_json, exit_status: 0 }
          end
        end

        it 'adds the data to the events' do
          event_data = {
            'NAME1' => 'VALUE1'
          }
        end
      end

      describe 'when there are multiple event data items' do
        before(:each) do
          args = default_args.dup
          args << '--event-data'
          args << 'NAME1=VALUE1'
          args << '--event-data'
          args << 'NAME2=VALUE2'
          check_cucumber = CheckCucumber.new(args)
          expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 0.0) do
            { results: results.to_json, exit_status: 0 }
          end
        end

        it 'adds the data to the events' do
          event_data = {
            'NAME1' => 'VALUE1',
            'NAME2' => 'VALUE2'
          }
        end
      end

      { '123' => 123, '-123' => -123 }.each do |string_value, integer_value|
        describe "when an event data item is an integer and its value is #{string_value}" do
          before(:each) do
            args = default_args.dup
            args << '--event-data'
            args << "NAME1=#{string_value}"
            check_cucumber = CheckCucumber.new(args)
            expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 0.0) do
              { results: results.to_json, exit_status: 0 }
            end
          end

          it 'adds the data to the events as an integer' do
            event_data = {
              'NAME1' => integer_value
            }
          end
        end
      end

      ["123\ntext", "text\n123", "text\n123\ntext"].each do |string_value|
        describe "when an event data item is almost an integer and its value is #{string_value.gsub("\n", '\\n')}" do
          before(:each) do
            args = default_args.dup
            args << '--event-data'
            args << "NAME1=#{string_value}"
            check_cucumber = CheckCucumber.new(args)
            expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 0.0) do
              { results: results.to_json, exit_status: 0 }
            end
          end

          it 'adds the data to the events as a string' do
            event_data = {
              'NAME1' => string_value
            }
          end
        end
      end

      { '12.3' => 12.3, '-12.3' => -12.3, '1.23' => 1.23, '-1.23' => -1.23 }.each do |string_value, float_value|
        describe "when an event data item is a float and its value is #{string_value}" do
          before(:each) do
            args = default_args.dup
            args << '--event-data'
            args << "NAME1=#{string_value}"
            check_cucumber = CheckCucumber.new(args)
            expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 0.0) do
              { results: results.to_json, exit_status: 0 }
            end
          end

          it 'adds the data to the events as a float' do
            event_data = {
              'NAME1' => float_value
            }
          end
        end
      end

      ["12.3\ntext", "text\n12.3", "text\n12.3\ntext", '1a23'].each do |string_value|
        describe "when an event data item is almost a float and its value is #{string_value.gsub("\n", '\\n')}" do
          before(:each) do
            args = default_args.dup
            args << '--event-data'
            args << "NAME1=#{string_value}"
            check_cucumber = CheckCucumber.new(args)
            expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 0.0) do
              { results: results.to_json, exit_status: 0 }
            end
          end

          it 'adds the data to the events as a string' do
            event_data = {
              'NAME1' => string_value
            }
          end
        end
      end

      { 'true' => true, 'false' => false }.each do |string_value, boolean_value|
        describe "when an event data item is a boolean and its value is #{string_value}" do
          before(:each) do
            args = default_args.dup
            args << '--event-data'
            args << "NAME1=#{string_value}"
            check_cucumber = CheckCucumber.new(args)
            expect(check_cucumber).to receive('execute_cucumber').with({}, 'cucumber-js features/', 'example-working-dir', 0.0) do
              { results: results.to_json, exit_status: 0 }
            end
          end

          it 'adds the data to the events as a boolean' do
            event_data = {
              'NAME1' => boolean_value
            }
          end
        end
      end

      after(:each) do
        sensu_events = []
        sensu_events << generate_sensu_event(status: :passed, feature_index: 0, scenario_index: 0, results: results, event_data: event_data)
        sensu_events << generate_metric_event(status: :passed, feature_index: 0, scenario_index: 0, results: results)
        sensu_events << generate_sensu_event(status: :passed, feature_index: 1, scenario_index: 0, results: results, event_data: event_data)
        sensu_events << generate_metric_event(status: :passed, feature_index: 1, scenario_index: 0, results: results)
        expect(check_cucumber).to receive('raise_sensu_events').with(sensu_events) do
          []
        end
        check_cucumber.run
      end
    end
  end

  describe 'config_is_valid?' do
    args = nil

    before(:each) do
      args = []
    end

    it 'returns unknown if no name is specified' do
      check_cucumber = CheckCucumber.new(args)
      expect(check_cucumber).to receive('unknown').with(generate_unknown_error('No name specified'))
      check_cucumber.config_is_valid?
    end

    describe 'when the name is specified' do
      before(:each) do
        args << '--name'
        args << 'example-name'
      end

      it 'returns unknown if no handler is specified' do
        check_cucumber = CheckCucumber.new(args)
        expect(check_cucumber).to receive('unknown').with(generate_unknown_error('No handler specified'))
        check_cucumber.config_is_valid?
      end

      describe 'when the handler is specified' do
        before(:each) do
          args << '--handler'
          args << 'example-handler'
        end

        it 'returns unknown if no metric handler is specified' do
          check_cucumber = CheckCucumber.new(args)
          expect(check_cucumber).to receive('unknown').with(generate_unknown_error('No metric handler specified'))
          check_cucumber.config_is_valid?
        end

        describe 'when the metric handler is specified' do
          before(:each) do
            args << '--metric-handler'
            args << 'example-metric-handler'
          end

          it 'returns unknown if no metric prefix is specified' do
            check_cucumber = CheckCucumber.new(args)
            expect(check_cucumber).to receive('unknown').with(generate_unknown_error('No metric prefix specified'))
            check_cucumber.config_is_valid?
          end

          describe 'when the metric prefix is specified' do
            before(:each) do
              args << '--metric-prefix'
              args << 'example-metric-prefix'
            end

            it 'returns unknown if no cucumber command line is specified' do
              check_cucumber = CheckCucumber.new(args)
              expect(check_cucumber).to receive('unknown').with(generate_unknown_error('No cucumber command line specified'))
              check_cucumber.config_is_valid?
            end

            describe 'when the Cucumber command line is specified' do
              before(:each) do
                args << '--command'
                args << 'cucumber-js features/'
              end

              it 'returns unknown if no working dir is specified' do
                check_cucumber = CheckCucumber.new(args)
                expect(check_cucumber).to receive('unknown').with(generate_unknown_error('No working directory specified'))
                check_cucumber.config_is_valid?
              end

              describe 'when the Cucumber command line is specified' do
                before(:each) do
                  args << '--working-dir'
                  args << 'example-working-dir'
                  check_cucumber.stub(:send_sensu_event) {}
                end

                describe 'when attachments argument is not specified' do
                  it 'defaults the argument to true' do
                    check_cucumber = CheckCucumber.new(args)
                    check_cucumber.config_is_valid?
                    expect(check_cucumber.config[:attachments]).to be true
                  end
                end

                describe 'when attachments argument is set to true' do
                  it 'converts the argument value from a string to a boolean' do
                    args << '--attachment'
                    args << 'true'
                    check_cucumber = CheckCucumber.new(args)
                    check_cucumber.config_is_valid?
                    expect(check_cucumber.config[:attachments]).to be true
                  end
                end

                describe 'when attachments argument is set to false' do
                  it 'converts the argument value from a string to a boolean' do
                    args << '--attachment'
                    args << 'false'
                    check_cucumber = CheckCucumber.new(args)
                    check_cucumber.config_is_valid?
                    expect(check_cucumber.config[:attachments]).to be false
                  end
                end

                describe 'when attachments argument is not boolean' do
                  it 'returns unknown' do
                    args << '--attachment'
                    args << 'not-a-boolean'
                    check_cucumber = CheckCucumber.new(args)
                    expect(check_cucumber).to receive('unknown').with(generate_unknown_error('Attachments argument is not a valid boolean'))
                    check_cucumber.config_is_valid?
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  describe 'generate_name_from_scenario()' do
    feature = nil

    before(:each) do
      feature = {}
    end

    it 'returns the scenario id' do
      scenario = { id: 'text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text')
    end

    it 'replaces a period with a hyphen' do
      scenario = { id: 'text.text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text-text')
    end

    it 'replaces a semi colon with a period' do
      scenario = { id: 'text;text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text.text')
    end

    it 'replaces multiple semi colons with periods' do
      scenario = { id: 'text;text;text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text.text.text')
    end

    it 'does not replace hyphens' do
      scenario = { id: 'text-text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text-text')
    end

    it 'replaces every character (except letters, periods, hyphens and underscores) with hyphen' do
      id = ''
      (1..254).each { |ascii_code| id += ascii_code.chr }

      scenario = { id: id }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('0123456789.ABCDEFGHIJKLMNOPQRSTUVWXYZ-_-abcdefghijklmnopqrstuvwxyz')
    end

    it 'avoid consecutive periods' do
      scenario = { id: 'text;;text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text.text')
    end

    it 'removes a hyphen at the start' do
      scenario = { id: '-text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text')
    end

    it 'removes multiple hyphens at the start' do
      scenario = { id: '--text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text')
    end

    it 'removes a hyphen at the end' do
      scenario = { id: 'text-' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text')
    end

    it 'removes multiple hyphens at the end' do
      scenario = { id: 'text--' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text')
    end

    it 'replaces consecutive hyphens with a single hyphen' do
      scenario = { id: 'text--text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text-text')
    end

    it 'removes a period at the start' do
      scenario = { id: ';text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text')
    end

    it 'removes multiple periods at the start' do
      scenario = { id: ';;text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text')
    end

    it 'removes a period at the end' do
      scenario = { id: 'text;' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text')
    end

    it 'removes multiple periods at the end' do
      scenario = { id: 'text;;' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text')
    end

    it 'replaces consecutive periods with a single period' do
      scenario = { id: 'text;;text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text.text')
    end

    it 'removes a hyphen at the start of a part' do
      scenario = { id: 'text;-text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text.text')
    end

    it 'removes multiple hyphens at the start of a part' do
      scenario = { id: 'text;--text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text.text')
    end

    it 'removes a hyphen at the end of a part' do
      scenario = { id: 'text;-text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text.text')
    end

    it 'removes multiple hyphens at the end of a part' do
      scenario = { id: 'text;--text' }
      name = check_cucumber.generate_name_from_scenario(feature, scenario)
      expect(name).to eq('text.text')
    end

    describe 'when using a variant of Cucumber that includes profile names in the Cucumber results (e.g. parallel-cucumber)' do
      it 'returns the scenario id and the profile name' do
        feature = { profile: 'example-profile' }
        scenario = { id: 'text' }
        name = check_cucumber.generate_name_from_scenario(feature, scenario)
        expect(name).to eq('text.example-profile')
      end
    end
  end

  describe 'remove_attachments_from_scenario()' do
    it 'does not error when the scenario has no steps' do
      scenario = {}
      check_cucumber.remove_attachments_from_scenario(scenario)
    end

    it 'replaces the attachments of a step with an empty array' do
      scenario = {
        steps: [
          {
            embeddings: [{}]
          }
        ]
      }
      check_cucumber.remove_attachments_from_scenario(scenario)
      expect(scenario[:steps][0][:embeddings]).to be_empty
    end

    it 'replaces the attachments of multiple steps with empty arrays' do
      scenario = {
        steps: [
          {
            embeddings: [{}]
          },
          {
            embeddings: [{}]
          }
        ]
      }
      check_cucumber.remove_attachments_from_scenario(scenario)
      expect(scenario[:steps][0][:embeddings]).to be_empty
      expect(scenario[:steps][1][:embeddings]).to be_empty
    end

    it 'does not replace the attachments of a step with no attachments' do
      scenario = {
        steps: [
          {
          }
        ]
      }
      check_cucumber.remove_attachments_from_scenario(scenario)
      expect(scenario[:steps][0]).to_not include(:embeddings)
    end
  end

  describe 'generate_metrics_from_scenario()' do
    feature = nil
    scenario = nil

    before(:each) do
      check_cucumber.config[:metric_prefix] = 'example-metric-prefix'
      feature = {}
      scenario = { id: 'example-scenario-id', steps: [] }
    end

    it 'generates metrics for a single step' do
      scenario[:steps] << { result: { duration: 0.5 } }
      metrics = check_cucumber.generate_metrics_from_scenario(feature, scenario, :passed, 123)
      expected_metrics = "example-metric-prefix.example-scenario-id.duration 0.5 123\n" \
        "example-metric-prefix.example-scenario-id.step-count 1 123\n" \
        'example-metric-prefix.example-scenario-id.step-1.duration 0.5 123'
      expect(metrics).to eq(expected_metrics)
    end

    it 'generates metrics for multiple steps' do
      scenario[:steps] << { result: { duration: 0.5 } }
      scenario[:steps] << { result: { duration: 1.5 } }
      metrics = check_cucumber.generate_metrics_from_scenario(feature, scenario, :passed, 123)
      expected_metrics = "example-metric-prefix.example-scenario-id.duration 2.0 123\n" \
        "example-metric-prefix.example-scenario-id.step-count 2 123\n" \
        "example-metric-prefix.example-scenario-id.step-1.duration 0.5 123\n" \
        'example-metric-prefix.example-scenario-id.step-2.duration 1.5 123'
      expect(metrics).to eq(expected_metrics)
    end

    it 'ignores a scenario with no steps' do
      scenario.delete :steps
      metrics = check_cucumber.generate_metrics_from_scenario(feature, scenario, :passed, 123)
      expect(metrics).to be_nil
    end

    it 'ignores a scenario with an empty array of steps' do
      scenario[:steps] = []
      metrics = check_cucumber.generate_metrics_from_scenario(feature, scenario, :passed, 123)
      expect(metrics).to be_nil
    end

    it 'ignores a scenario with only steps that have no results' do
      scenario[:steps] << {}
      metrics = check_cucumber.generate_metrics_from_scenario(feature, scenario, :passed, 123)
      expect(metrics).to be_nil
    end

    it 'ignores a scenario with only steps that have no duration' do
      scenario[:steps] << { result: {} }
      metrics = check_cucumber.generate_metrics_from_scenario(feature, scenario, :passed, 123)
      expect(metrics).to be_nil
    end

    it 'ignores a step with no result' do
      scenario[:steps] << { result: { duration: 0.5 } }
      scenario[:steps] << {}
      metrics = check_cucumber.generate_metrics_from_scenario(feature, scenario, :passed, 123)
      expected_metrics = "example-metric-prefix.example-scenario-id.duration 0.5 123\n" \
        "example-metric-prefix.example-scenario-id.step-count 2 123\n" \
        'example-metric-prefix.example-scenario-id.step-1.duration 0.5 123'
      expect(metrics).to eq(expected_metrics)
    end

    it 'ignores a step with no duration' do
      scenario[:steps] << { result: { duration: 0.5 } }
      scenario[:steps] << { result: {} }
      metrics = check_cucumber.generate_metrics_from_scenario(feature, scenario, :passed, 123)
      expected_metrics = "example-metric-prefix.example-scenario-id.duration 0.5 123\n" \
        "example-metric-prefix.example-scenario-id.step-count 2 123\n" \
        'example-metric-prefix.example-scenario-id.step-1.duration 0.5 123'
      expect(metrics).to eq(expected_metrics)
    end

    it 'ignores a failed scenario' do
      scenario[:steps] << { result: { duration: 0.5 } }
      metrics = check_cucumber.generate_metrics_from_scenario(feature, scenario, :failed, 123)
      expect(metrics).to be_nil
    end

    it 'ignores a pending scenario' do
      scenario[:steps] << { result: { duration: 0.5 } }
      metrics = check_cucumber.generate_metrics_from_scenario(feature, scenario, :pending, 123)
      expect(metrics).to be_nil
    end

    it 'ignores an undefined scenario' do
      scenario[:steps] << { result: { duration: 0.5 } }
      metrics = check_cucumber.generate_metrics_from_scenario(feature, scenario, :undefined, 123)
      expect(metrics).to be_nil
    end
  end

  describe 'raise_sensu_events()' do
    describe 'when there are no events' do
      it 'does not call send_sensu_event() and returns no errors' do
        events = []
        expect(check_cucumber).to_not receive('send_sensu_event')
        errors = check_cucumber.raise_sensu_events(events)
        expect(errors).to be_empty
      end
    end

    describe 'when there is 1 event' do
      it 'calls send_sensu_event() once and returns no errors' do
        events = [{ name: 'example-event-1' }]
        expect(check_cucumber).to receive('send_sensu_event').with('{"name":"example-event-1"}')
        errors = check_cucumber.raise_sensu_events(events)
        expect(errors).to be_empty
      end
    end

    describe 'when there is more than 1 event' do
      it 'calls send_sensu_event() multiple times and returns no errors' do
        events = [{ name: 'example-event-1' }, { name: 'example-event-2' }]
        expect(check_cucumber).to receive('send_sensu_event').with('{"name":"example-event-1"}').ordered
        expect(check_cucumber).to receive('send_sensu_event').with('{"name":"example-event-2"}').ordered
        errors = check_cucumber.raise_sensu_events(events)
        expect(errors).to be_empty
      end
    end

    describe 'when an event includes a unicode character' do
      it 'escapes the unicode character using a JSON unicode escape sequence as the Sensu socket only supports ASCII characters' do
        events = [{ name: "example-\u2190-leftwards-arrow-character-event".encode('utf-8') }]
        expect(check_cucumber).to receive('send_sensu_event').with('{"name":"example-\u2190-leftwards-arrow-character-event"}')
        errors = check_cucumber.raise_sensu_events(events)
        expect(errors).to be_empty
      end
    end

    describe 'when sending an event raises a standard error' do
      it 'returns the error' do
        events = [{ name: 'example-event-1' }]
        expected_errors = [{
          'message' => 'Failed to raise event example-event-1',
          'error' => {
            'message' => 'example-standard-error-1',
            'backtrace' => '<backtrace>'
          }
        }]
        expect(check_cucumber).to receive('send_sensu_event').with('{"name":"example-event-1"}') do
          fail StandardError, 'example-standard-error-1'
        end
        errors = check_cucumber.raise_sensu_events(events)
        normalize_errors errors
        expect(errors).to match_array(expected_errors)
      end
    end

    describe 'when sending an event raises a connection refused error' do
      it 'returns the error' do
        events = [{ name: 'example-event-1' }]
        expected_errors = [{
          'message' => 'Failed to raise event example-event-1',
          'error' => {
            'message' => 'Connection refused - example-connection-refused-error-1',
            'backtrace' => '<backtrace>'
          }
        }]
        expect(check_cucumber).to receive('send_sensu_event').with('{"name":"example-event-1"}') do
          fail Errno::ECONNREFUSED, 'example-connection-refused-error-1'
        end
        errors = check_cucumber.raise_sensu_events(events)
        normalize_errors errors
        expect(errors).to match_array(expected_errors)
      end
    end

    describe 'when sending an event raises a broken pipe error' do
      it 'returns the error' do
        events = [{ name: 'example-event-1' }]
        expected_errors = [{
          'message' => 'Failed to raise event example-event-1',
          'error' => {
            'message' => 'Broken pipe - example-broken-pipe-error-1',
            'backtrace' => '<backtrace>'
          }
        }]
        expect(check_cucumber).to receive('send_sensu_event').with('{"name":"example-event-1"}') do
          fail Errno::EPIPE, 'example-broken-pipe-error-1'
        end
        errors = check_cucumber.raise_sensu_events(events)
        normalize_errors errors
        expect(errors).to match_array(expected_errors)
      end
    end

    describe 'when sending multiple events raises multiple standard errors' do
      it 'returns the error' do
        events = [{ name: 'example-event-1' }, { name: 'example-event-2' }]
        expected_errors = [
          {
            'message' => 'Failed to raise event example-event-1',
            'error' => {
              'message' => 'example-standard-error-1',
              'backtrace' => '<backtrace>'
            }
          },
          {
            'message' => 'Failed to raise event example-event-2',
            'error' => {
              'message' => 'example-standard-error-2',
              'backtrace' => '<backtrace>'
            }
          }
        ]
        expect(check_cucumber).to receive('send_sensu_event').with('{"name":"example-event-1"}').ordered do
          fail StandardError, 'example-standard-error-1'
        end
        expect(check_cucumber).to receive('send_sensu_event').with('{"name":"example-event-2"}').ordered do
          fail StandardError, 'example-standard-error-2'
        end
        errors = check_cucumber.raise_sensu_events(events)
        normalize_errors errors
        expect(errors).to match_array(expected_errors)
      end
    end
  end
end

def generate_feature(options = {})
  feature_index = options[:feature_index] || 0
  feature = {
    id: "Feature-#{feature_index}",
    name: "Feature #{feature_index}",
    description: options[:feature_description] || "This is Feature #{feature_index}",
    line: 1,
    keyword: 'Feature',
    uri: "features/feature-#{feature_index}.feature",
    elements: []
  }

  feature[:profile] = options[:profile] unless options[:profile].nil?

  if options[:has_background]
    feature[:elements] << {
      name: 'Background 0',
      keyword: 'Background',
      description: 'This is Background 0',
      type: 'background',
      line: 3,
      steps: [
        {
          name: 'a passing pre-condition',
          line: 4,
          keyword: 'Given '
        }
      ]
    }
  end

  scenario_index = 0

  Array(options[:scenarios]).each do |scenario_options|
    scenario = {
      name: "Scenario #{scenario_index}",
      id: "#{feature[:id]};scenario-#{scenario_index}",
      line: 3,
      keyword: "Scenario #{scenario_index}",
      description: "This is Scenario #{scenario_index}",
      type: 'scenario',
      steps: []
    }

    Array(scenario_options[:step_statuses]).each_with_index do |step_status, step_index|
      step = {
        name: 'example step',
        line: 4 + step_index,
        keyword: 'Given ',
        result: {
          duration: step_index + 0.5,
          status: step_status.to_s
        },
        match: {}
      }

      if scenario_options.key?(:step_attachments)
        step_attachment_options = scenario_options[:step_attachments][step_index]
        step[:embeddings] = [
          {
            mime_type: step_attachment_options[:mime_type],
            data: step_attachment_options[:data]
          }
        ]
      end

      scenario[:steps] << step
    end

    feature[:elements] << scenario
    scenario_index += 1
  end

  feature
end

def deep_dup(obj)
  Marshal.load(Marshal.dump(obj))
end

def generate_sensu_event(options = {})
  feature_index = options[:feature_index] || 0
  scenario_index = options[:scenario_index] || 0
  metric_prefix = options[:metric_prefix] || "example-metric-prefix.Feature-#{feature_index}.scenario-#{scenario_index}"

  feature = deep_dup(options[:results][feature_index])
  scenarios = feature[:elements].select { |element| element[:type] == 'scenario' }
  scenario = scenarios[scenario_index]
  feature[:elements] = [scenario]

  case options[:type]
  when :metric
    name = options[:name] || "example-name.Feature-#{feature_index}.scenario-#{scenario_index}.metrics"
    metrics = []

    if options[:status] == :passed
      scenario_duration = 0
      has_durations = false

      scenario[:steps].each.with_index do |step, step_index|
        if step.key?(:result)
          metrics << "#{metric_prefix}.step-#{step_index + 1}.duration #{step[:result][:duration]} 123"
          scenario_duration += step[:result][:duration]
          has_durations = true
        end
      end

      if has_durations
        metrics.unshift([
          "#{metric_prefix}.duration #{scenario_duration} 123",
          "#{metric_prefix}.step-count #{scenario[:steps].length} 123"
        ])
      end
    end

    metrics = metrics.join("\n")

    sensu_event = {
      name: name,
      type: 'metric',
      handlers: ['example-metric-handler'],
      output: metrics,
      status: 0
    }
    else
    name = options[:name] || "example-name.Feature-#{feature_index}.scenario-#{scenario_index}"
    data = {
      'status' => options[:status].to_s
    }

    steps = []

    Array(scenario[:steps]).each_with_index do |step, index|
      status = step.key?(:result) ? step[:result][:status] : 'unknown'

      steps << {
        'step' => "#{status.upcase} - #{index + 1} - #{step[:keyword]}#{step[:name]}"
      }
    end

    data['steps'] = steps

    status_code_map = {
      passed: 0,
      failed: 2,
      pending: 1,
      undefined: 1
    }

    sensu_event = {
      name: name,
      handlers: ['example-handler'],
      status: status_code_map[options[:status]],
      output: dump_yaml(data),
      results: [feature]
    }

    if options[:exclude_attachments]
      sensu_event[:results][0][:elements].each do |element|
        element[:steps].each do |step|
          step[:embeddings] = []
        end
      end
    end

    if options.key?(:event_data)
      options[:event_data].each do |key, value|
        sensu_event[key] = value
      end
    end
  end

  sensu_event
end

def generate_metric_event(options = {})
  options[:type] = :metric
  generate_sensu_event(options)
end

def generate_output(options = {})
  output = {
    'status' => options[:status].to_s || 'ok'
  }

  [:scenarios, :passed, :failed, :pending, :undefined].each do |item|
    output[item.to_s] = options[item] if options.key? item
  end

  if options.key? :errors
    errors = []

    Array(options[:errors]).each do |error|
      if error.is_a? String
        errors << {
          'message' => error
        }
      else
        errors << error
      end
    end

    output['errors'] = errors
  end

  dump_yaml(output)
end

def dump_yaml(data)
  data.to_yaml.gsub(/^---\r?\n/, '')
end

def generate_unknown_error(message)
  generate_output(status: :unknown, errors: message)
end

def normalize_errors(errors)
  errors.each do |error|
    error['error']['backtrace'] = '<backtrace>' if error['error'].key? 'backtrace'
  end
end
