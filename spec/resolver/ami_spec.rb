require 'uri'
require 'helper/spec_helper'
require 'bora/resolver/ami'

describe Bora::Resolver::Ami do
  let(:bora_stack) do
    s = double(Bora::Stack)
    allow(s).to receive(:region).and_return(DEFAULT_REGION)
    s
  end

  let(:resolver) { Bora::Resolver::Ami.new(bora_stack) }

  let(:ec2) do
    ec2 = double(Aws::EC2::Client)
    allow(Aws::EC2::Client).to receive(:new).with(region: DEFAULT_REGION).and_return(ec2)
    ec2
  end

  it "returns the latest image from the 'self' account" do
    expect(ec2).to receive(:describe_images)
      .with(describe_images_request('my_ami_*', ['self']))
      .and_return(describe_images_response)

    expect(resolver.resolve(URI('ami://my_ami_*'))).to eq('ami-2')
  end

  it 'returns the latest image from the specified account' do
    expect(ec2).to receive(:describe_images)
      .with(describe_images_request('my_ami_*', ['amazon']))
      .and_return(describe_images_response)

    expect(resolver.resolve(URI('ami://my_ami_*?owner=amazon'))).to eq('ami-2')
  end

  it 'raises an exception if no ami is found' do
    expect(ec2).to receive(:describe_images).and_return(empty_describe_images_response)
    expect { resolver.resolve(URI('ami://my_ami')) }.to raise_exception(Bora::Resolver::Ami::NoAMI)
  end

  it 'raises an exception if the URI is invalid' do
    expect { resolver.resolve(URI('ami:///foo')) }.to raise_exception(Bora::Resolver::Ami::InvalidParameter)
  end

  it 'raises an exception if the Owner parameter in URI is invalid' do
    expect(ec2).to receive(:describe_images)
      .with(describe_images_request('amzn-ami-hv*x86_64-gp2', ['111']))
      .and_raise(Aws::EC2::Errors::InvalidUserIDMalformed.new(nil, nil))

    expect { resolver.resolve(URI('ami://amzn-ami-hv*x86_64-gp2?owner=111')) }
      .to raise_exception(Bora::Resolver::Ami::InvalidUserId)
  end

  def describe_images_request(ami, owner)
    {
      owners: owner,
      filters: [
        { name: 'name', values: [ami] },
        { name: 'state', values: ['available'] }
      ]
    }
  end

  def describe_images_response
    Hashie::Mash.new(
      images: [
        {
          image_id: 'ami-2',
          creation_date: '2016-09-21T02:50:46.000Z'
        },
        {
          image_id: 'ami-1',
          creation_date: '2016-09-21T02:50:45.000Z'
        }
      ]
    )
  end

  def empty_describe_images_response
    Hashie::Mash.new(images: [])
  end
end
