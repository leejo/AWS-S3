#!perl

use strict;
use warnings;

package Mocked::HTTP::Response;

use Moose;
extends 'HTTP::Response';

sub content { return shift->{_msg}; }

1;

package main;

use Test::More 'no_plan';
use Test::MockObject;
use Test::Deep;
use Data::Section::Simple 'get_data_section';

use Carp 'confess';
$SIG{__DIE__} = \&confess;

use_ok('AWS::S3');

my $s3 = AWS::S3->new(
  access_key_id     => $ENV{AWS_ACCESS_KEY_ID}     // 'foo',
  secret_access_key => $ENV{AWS_SECRET_ACCESS_KEY} // 'bar',
  endpoint          => 'bad.hostname',
);

my $bucket_name = "aws-s3-test-" . int(rand() * 1_000_000) . '-' . time() . "-foo";

eval {
    my $bucket = $s3->add_bucket( name => $bucket_name, location => 'us-west-1' );
};

like(
    $@,
    qr/Can't connect to aws-s3-test-.*?bad\.hostname/,
    'endpoint was used'
);

isa_ok(
	$s3->request( 'CreateBucket',bucket => 'foo' ),
	'AWS::S3::Request::CreateBucket'
);

my $xml = get_data_section('ListAllMyBucketsResult.xml');

no warnings 'once';
*LWP::UserAgent::Determined::request = sub {
    return Mocked::HTTP::Response->new( 200,$xml );
};
isa_ok( $s3->owner,'AWS::S3::Owner' );

my @buckets = $s3->buckets;
cmp_deeply( \@buckets,
    [ obj_isa('AWS::S3::Bucket'), obj_isa('AWS::S3::Bucket') ], '->buckets' );
ok( ! $s3->bucket( 'does not exist' ),'!->bucket' );
is( $s3->bucket( 'foo' )->name, 'foo', '->bucket' );

#{
#    my $xml = get_data_section('error.xml');
#
#    no warnings 'redefine';
#    *LWP::UserAgent::Determined::request = sub {
#        return Mocked::HTTP::Response->new( 404,$xml );
#    };
#
#    my $bucket = $s3->buckets;
#    ok( ! $bucket, '!->bucket' );
#}
__DATA__
@@ ListAllMyBucketsResult.xml
<?xml version="1.0" encoding="UTF-8"?>
<ListAllMyBucketsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Owner>
    <ID>bcaf1ffd86f41161ca5fb16fd081034f</ID>
    <DisplayName>webfile</DisplayName>
  </Owner>
  <Buckets>
    <Bucket>
      <Name>foo</Name>
      <CreationDate>2006-02-03T16:45:09.000Z</CreationDate>
    </Bucket>
    <Bucket>
      <Name>bar</Name>
      <CreationDate>2006-02-03T16:41:58.000Z</CreationDate>
    </Bucket>
 </Buckets>
</ListAllMyBucketsResult>
@@ error.xml
<?xml version="1.0" encoding="UTF-8"?>
<Error>
  <Code>NoSuchBucket</Code>
  <Message>The specified bucket does not exist.</Message>
  <Resource>/mybucket</Resource>
  <RequestId>4442587FB7D0A2F9</RequestId>
</Error>
