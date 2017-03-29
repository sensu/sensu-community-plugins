require 'spec_helper'

describe CheckOpenTSDBSeries do
  let(:metric_df_inodes_total_good) do
    File.read(File.expand_path("#{FIXTURE_DIRECTORY}/df.inodes.total.txt", __FILE__))
  end

  let(:metric_df_inodes_used_good) do
    File.read(File.expand_path("#{FIXTURE_DIRECTORY}/df.inodes.used.txt", __FILE__))
  end

  let(:metric_df_inodes_used_series_good) do
    File.read(File.expand_path("#{FIXTURE_DIRECTORY}/df.inodes.used-series.txt", __FILE__))
  end

  let(:data_handler) { metric_df_inodes_used_good }

  let(:checker) { described_class.new }

  let(:checker_cfg) do
    {
      host: 'localhost',
      port: 4242,
      metric: 'df.inodes.used',
      tags: 'host=stage-web-thermo-1001.va.opower.it',
      threshold: '10',
      comparator: :>
    }
  end

  # XXX: Sensu plugins run in the context of an at_exit handler. This prevents
  # XXX: code-under-test from being run at the end of the rspec suite.
  before(:all) do
    # rubocop:disable AvoidClassVars
    Sensu::Plugin::CLI.class_eval do
      class PluginStub
        def run; end
        def ok(*); end
        def warning(*); end
        def critical(*); end
        def unknown(*); end
      end
      @@autorun = PluginStub
    end
    # rubocop:enable AvoidClassVars
  end

  before(:each) do
    checker.stub(:config) { checker_cfg }
    checker.stub(:get_data) { data_handler }
  end

  describe 'options' do

    describe ':port' do
      it 'treats the parameter as an integer' do
        checker.parse_options(%w{--port 1000})
        checker.config[:port].should eq 1000
      end
    end

    describe ':metric' do
      it 'accept multiple metrics' do
        checker.parse_options(%w{--metric df.inodes.used,df.inodes.total})
        checker.config[:metric].should eq "df.inodes.used,df.inodes.total"
      end
    end

    describe ':threshold' do
      it 'treats the parameter as a float' do
        checker.parse_options(%w{--threshold 37.2})
        checker.config[:threshold].should eq 37.2
      end
    end

    describe ':ratio_threshold' do
      it 'treats the parameter as a float' do
        checker.parse_options(%w{--ratio_threshold 0.3})
        checker.config[:ratio_threshold].should eq 0.3
      end
    end

    describe ':rate' do
      it 'treats the parameter as a boolean' do
        checker.parse_options(%w{--rate})
        checker.config[:rate].should eq true
      end
    end

    describe ':comparator' do
      it 'maps gt to >' do
        checker.parse_options(%w{--comparator gt})
        checker.config[:comparator].should eq :>
      end

      it 'maps lt to <' do
        checker.parse_options(%w{--comparator lt})
        checker.config[:comparator].should eq :<
      end

      it 'returns an unknown comparator as a string to make it easy to report an error' do
        checker.parse_options(%w{--comparator foo})
        checker.config[:comparator].should eq 'foo'
      end
    end

    describe 'returns unknown when missing' do
      [:metric, :tags].each do |required|
        it "#{required.to_s}" do
          checker_cfg.delete(required)
          checker.should_receive(:unknown).with("Missing require parameter #{required.to_s}")
          checker.check_config
        end
      end
    end

    describe ':threshold and :ratio_threshold parameters' do
      it 'when both are defined returns unknown' do
        checker_cfg.merge!({ ratio_threshold: 0.3, metric: 'df.inodes.used,df.inodes.total' })
        checker.should_receive(:unknown).with("Must set either threshold (10) or ratio_threshold (0.3) parameter but not both.")
        checker.check_config
      end

      it 'when both are missing returns unknown' do
        checker_cfg.merge!({ threshold: nil, ratio_threshold: nil })
        checker.should_receive(:unknown).with("Must set either threshold or ratio_threshold parameter.")
        checker.check_config
      end
    end

  end

  describe '#run' do

    describe 'with a single metric' do
      it 'and default comparison (:>) returns ok' do
        checker.should_receive(:ok)
        checker.run
      end

      it 'and a comparison of :< returns ok' do
        checker_cfg.merge!({ threshold: 1000000, comparator: :< })
        checker.should_receive(:ok)
        checker.run
      end

      [:==, :<=, :>=].each do |operator|
        it "and a comparison of #{operator} returns ok" do
          checker_cfg.merge!({ threshold: 6997, comparator: operator })
          checker.should_receive(:ok)
          checker.run
        end
      end

      context 'with multiple series' do
        let(:data_handler) { metric_df_inodes_used_series_good }

        it 'returns ok' do
          checker.should_receive(:ok)
          checker.run
        end
      end

      context 'when value exceeds threshold' do
        let(:data_handler) { metric_df_inodes_used_good }

        it 'returns critical' do
          checker_cfg.merge!({ threshold: 1000000 })
          checker.should_receive(:critical).with('Check failed (> 1000000) for metric df.inodes.used with tags host=web-1001.example.com:tier=stage')
          checker.run
        end
      end
    end

    context 'with multiple metrics' do
      let(:data_handler) { metric_df_inodes_used_good + metric_df_inodes_total_good }

      describe 'and a threshold' do

        it 'returns ok' do
          checker_cfg.merge!({ metric: 'df.inodes.used,df.inodes.total'})
          checker.should_receive(:ok)
          checker.run
        end

        it 'returns critical' do
          checker_cfg.merge!({ metric: 'df.inodes.used,df.inodes.total', threshold: 9000000 })
          checker.should_receive(:critical).with('Check failed (> 9000000) for metric df.inodes.used with tags host=web-1001.example.com:tier=stagemetric df.inodes.total with tags host=web-1001.example.com:tier=stage')
          checker.run
        end
      end

      describe 'and a ratio threshold' do

        it 'returns unknown when metrics != 2' do
          checker_cfg.merge!({ metric: 'df.inodes.used,df.inodes.total,df.something', ratio_threshold: 0.3, threshold: nil })
          checker.should_receive(:unknown).with('Must specify only 2 metrics when using ratio_threshold parameter')
          checker.check_config
        end

        it 'returns ok' do
          checker_cfg.merge!({ metric: 'df.inodes.used,df.inodes.total', ratio_threshold: 0.3, threshold: nil })
          checker.should_receive(:ok)
          checker.run
        end

        it 'returns critical' do
          checker_cfg.merge!({ metric: 'df.inodes.used,df.inodes.total', ratio_threshold: 1.01, threshold: nil })
          checker.should_receive(:critical).with('Check failed (> 1.01) for df.inodes.used/df.inodes.total and tags host=web-1001.example.com:tier=stage')
          checker.run
        end
      end
    end

  end
end
