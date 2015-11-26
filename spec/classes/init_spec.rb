require 'spec_helper'
describe 'report_consul_kv' do

  context 'with defaults for all parameters' do
    it { should contain_class('report_consul_kv') }
  end
end
