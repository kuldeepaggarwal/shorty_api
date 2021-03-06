require 'rails_helper'

RSpec.describe TinyUrlsController, type: :api do
  describe '#create' do
    let(:params) { Hash.new }
    let(:response) { TinyUrlSerializer.new(subject).to_json }

    context 'when valid paramaters' do
      context 'when shortcode specified' do
        let(:subject) { TinyUrl.new(shortcode: 'TysboE', url: Faker::Internet.url) }
        let(:params) { subject.attributes.slice('url', 'shortcode') }
        before { post shorten_path(params: params) }

        it 'returns 201 status code' do
          expect(last_response.status).to eq(201)
        end

        it 'returns specified shortcode' do
          expect(last_response.body).to eq(response)
        end
      end

      context 'when shortcode unspecified' do
        let(:subject) { TinyUrl.new(shortcode: 'TYsboE', url: Faker::Internet.url) }
        let(:params) { subject.attributes.slice('url') }
        before do
          allow(Faker::Base).to receive(:regexify).with(Regexp.new(TinyUrl::SHORTCODE_REGEX_STRING)).and_return(subject.shortcode)
          post shorten_path(params: params)
        end

        it 'returns 201 status code' do
          expect(last_response.status).to eq(201)
        end

        it 'returns specified shortcode' do
          expect(last_response.body).to eq(response)
        end
      end
    end

    context 'when invalid paramaters' do
      context 'when url is absent' do
        before { post shorten_path }

        it 'returns 400 status code' do
          expect(last_response.status).to eq(400)
        end

        it 'retuns "url is not present." error message' do
          expect(last_response.body).to eq({
            error: 'url is not present.'
          }.to_json)
        end
      end

      context 'when shortcode has been already taken' do
        let(:tiny_url) { FactoryGirl.create(:tiny_url) }
        before { post shorten_path(params: { shortcode: tiny_url.shortcode, url: 'test.com' }) }

        it 'returns 409 status code' do
          expect(last_response.status).to eq(409)
        end

        it 'retuns "The the desired shortcode is already in use. Shortcodes are case-sensitive." error message' do
          expect(last_response.body).to eq({
            error: 'The desired shortcode is already in use. Shortcodes are case-sensitive.'
          }.to_json)
        end
      end

      context 'when shortcode does not match with Regex' do
        before { post shorten_path(params: { shortcode: 'invalid short code', url: 'test.com' }) }

        it 'returns 422 status code' do
          expect(last_response.status).to eq(422)
        end

        it 'retuns "The shortcode fails to meet the following regexp: #{ TinyUrl::SHORTCODE_REGEX_STRING }." error message' do
          expect(last_response.body).to eq({
            error: "The shortcode fails to meet the following regexp: #{ TinyUrl::SHORTCODE_REGEX_STRING }."
          }.to_json)
        end
      end
    end
  end

  describe '#show' do
    context 'when shortcode found' do
      let(:tiny_url) { FactoryGirl.create(:tiny_url) }
      before { get tiny_url.shortcode }

      it 'returns 302 code' do
        expect(last_response.status).to eq(302)
      end

      it 'sets location header' do
        expect(last_response.headers['Location']).to eq(tiny_url.url)
      end

      it 'updates visiting attributes' do
        old_last_seen_at = tiny_url.last_seen_at
        old_count = tiny_url.redirect_count
        tiny_url.reload
        expect(tiny_url.last_seen_at).to_not eq(old_last_seen_at)
        expect(tiny_url.redirect_count).to eq(old_count + 1)
      end
    end

    context 'when shortcode does not found' do
      before { get '/fake-short-code' }

      it 'returns 404 code' do
        expect(last_response.status).to eq(404)
      end

      it 'returns error message' do
        expect(last_response.body).to eq({
          error: "The 'fake-short-code' cannot be found in the system"
        }.to_json)
      end
    end
  end

  describe '#statistics' do
    context 'when shortcode found' do
      let(:tiny_url) { FactoryGirl.create(:tiny_url) }
      before { get "/#{tiny_url.shortcode}/stats" }

      it 'returns 200 code' do
        expect(last_response.status).to eq(200)
      end

      it 'returns tiny_url details(redirectCount, startDate, lastSeenAt)' do
        expect(last_response.body).to eq(TinyUrlStatsSerializer.new(tiny_url).to_json)
      end
    end

    context 'when shortcode does not found' do
      before { get '/fake-short-code/stats' }

      it 'returns 404 code' do
        expect(last_response.status).to eq(404)
      end

      it 'returns error message' do
        expect(last_response.body).to eq({
          error: "The 'fake-short-code' cannot be found in the system"
        }.to_json)
      end
    end
  end
end
