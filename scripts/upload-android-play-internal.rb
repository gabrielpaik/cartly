#!/usr/bin/env ruby
# frozen_string_literal: true

require 'base64'
require 'json'
require 'net/http'
require 'openssl'
require 'time'
require 'uri'

PACKAGE_NAME = ENV.fetch('PLAY_PACKAGE_NAME', 'com.seungdae.cartly')
TRACK = ENV.fetch('PLAY_TRACK', 'internal')
AAB_PATH = ENV['PLAY_AAB_PATH'] || File.expand_path('../build/app/outputs/bundle/release/app-release.aab', __dir__)
DEFAULT_SERVICE_ACCOUNT_JSON = File.expand_path('~/Library/Application Support/Cartly/play/cartly-play-api.json')
SERVICE_ACCOUNT_JSON = ENV['PLAY_SERVICE_ACCOUNT_JSON'] || DEFAULT_SERVICE_ACCOUNT_JSON
RELEASE_NAME = ENV['PLAY_RELEASE_NAME']
RELEASE_STATUS = ENV.fetch('PLAY_RELEASE_STATUS', 'completed')
IN_APP_UPDATE_PRIORITY = Integer(ENV.fetch('PLAY_IN_APP_UPDATE_PRIORITY', '0'))

abort "missing AAB: #{AAB_PATH}" unless File.exist?(AAB_PATH)
abort "missing service account json: #{SERVICE_ACCOUNT_JSON}" unless File.exist?(SERVICE_ACCOUNT_JSON)

creds = JSON.parse(File.read(SERVICE_ACCOUNT_JSON))
private_key = OpenSSL::PKey::RSA.new(creds.fetch('private_key'))
token_uri = URI(creds.fetch('token_uri'))


def base64url(value)
  Base64.urlsafe_encode64(value, padding: false)
end


def fetch_access_token(token_uri, creds, private_key)
  now = Time.now.to_i
  header = { alg: 'RS256', typ: 'JWT' }
  claim = {
    iss: creds.fetch('client_email'),
    scope: 'https://www.googleapis.com/auth/androidpublisher',
    aud: token_uri.to_s,
    exp: now + 3600,
    iat: now,
  }

  unsigned = "#{base64url(header.to_json)}.#{base64url(claim.to_json)}"
  signature = base64url(private_key.sign(OpenSSL::Digest::SHA256.new, unsigned))
  jwt = "#{unsigned}.#{signature}"

  response = Net::HTTP.post_form(token_uri, {
    'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    'assertion' => jwt,
  })

  body = JSON.parse(response.body)
  return body.fetch('access_token') if response.is_a?(Net::HTTPSuccess)

  abort "token request failed (#{response.code}): #{response.body}"
end


def request_json(method, url, token, body = nil, content_type: 'application/json')
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request_class = case method
                  when :get then Net::HTTP::Get
                  when :post then Net::HTTP::Post
                  when :put then Net::HTTP::Put
                  when :patch then Net::HTTP::Patch
                  else
                    raise "unsupported method: #{method}"
                  end
  request = request_class.new(uri)
  request['Authorization'] = "Bearer #{token}"
  request['Content-Type'] = content_type
  request.body = body if body
  response = http.request(request)
  parsed = response.body.to_s.empty? ? {} : JSON.parse(response.body)
  return parsed if response.is_a?(Net::HTTPSuccess)

  abort "request failed #{method.to_s.upcase} #{url} (#{response.code}): #{response.body}"
end


def upload_bundle(url, token, aab_path)
  uri = URI(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  request = Net::HTTP::Post.new(uri)
  request['Authorization'] = "Bearer #{token}"
  request['Content-Type'] = 'application/octet-stream'
  request.body = File.binread(aab_path)
  response = http.request(request)
  parsed = JSON.parse(response.body)
  return parsed if response.is_a?(Net::HTTPSuccess)

  abort "bundle upload failed (#{response.code}): #{response.body}"
end

access_token = fetch_access_token(token_uri, creds, private_key)
create_edit_url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/#{PACKAGE_NAME}/edits"
edit = request_json(:post, create_edit_url, access_token, '{}')
edit_id = edit.fetch('id')

upload_url = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications/#{PACKAGE_NAME}/edits/#{edit_id}/bundles?uploadType=media"
bundle = upload_bundle(upload_url, access_token, AAB_PATH)
version_code = bundle.fetch('versionCode').to_s
release_name = RELEASE_NAME || "#{ENV.fetch('PLAY_VERSION_NAME', '1.0.5')} (#{version_code})"

track_body = {
  track: TRACK,
  releases: [
    {
      name: release_name,
      versionCodes: [version_code],
      status: RELEASE_STATUS,
      inAppUpdatePriority: IN_APP_UPDATE_PRIORITY,
    },
  ],
}.to_json

track_url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/#{PACKAGE_NAME}/edits/#{edit_id}/tracks/#{TRACK}"
request_json(:put, track_url, access_token, track_body)

commit_url = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications/#{PACKAGE_NAME}/edits/#{edit_id}:commit"
request_json(:post, commit_url, access_token, '{}')

puts "UPLOAD_OK"
puts "package=#{PACKAGE_NAME}"
puts "track=#{TRACK}"
puts "versionCode=#{version_code}"
puts "releaseName=#{release_name}"
puts "aab=#{AAB_PATH}"
