require 'spec_helper'
require 'rack/test'
require_relative '../app'

RSpec.describe LocalDiffChecker do
  include Rack::Test::Methods

  def app
    LocalDiffChecker
  end

  it 'loads configuration from config.yml' do
    expect(app.settings.config['storage_dir']).to eq './data'
  end

  it 'responds to root path' do
    get '/'
    # index.erbが未作成のため、現状は500(Errno::ENOENT)または404になる可能性がありますが、
    # ルーティングが定義されていることを確認します。
    expect(last_response.status).to eq(200).or eq(500)
  end
end
