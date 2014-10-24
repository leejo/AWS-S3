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

my $xml = do { local $/; <DATA> };

no warnings 'once';
*LWP::UserAgent::Determined::request = sub {
	return Mocked::HTTP::Response->new( 200,$xml );
};

isa_ok( $s3->owner,'AWS::S3::Owner' );

my @buckets = $s3->buckets;
cmp_deeply( \@buckets,[],'->buckets' );
ok( ! $s3->bucket( 'maibucket'),'->bucket' );

__DATA__
<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
    <Name>bucket</Name>
    <Prefix/>
    <Marker/>
    <MaxKeys>1000</MaxKeys>
    <IsTruncated>false</IsTruncated>
    <Contents>
        <Key>my-image.jpg</Key>
        <LastModified>2009-10-12T17:50:30.000Z</LastModified>
        <ETag>&quot;fba9dede5f27731c9771645a39863328&quot;</ETag>
        <Size>434234</Size>
        <StorageClass>STANDARD</StorageClass>
        <Owner>
            <ID>75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a</ID>
            <DisplayName>mtd@amazon.com</DisplayName>
        </Owner>
    </Contents>
    <Contents>
       <Key>my-third-image.jpg</Key>
         <LastModified>2009-10-12T17:50:30.000Z</LastModified>
        <ETag>&quot;1b2cf535f27731c974343645a3985328&quot;</ETag>
        <Size>64994</Size>
        <StorageClass>STANDARD</StorageClass>
        <Owner>
            <ID>75aa57f09aa0c8caeab4f8c24e99d10f8e7faeebf76c078efc7c6caea54ba06a</ID>
            <DisplayName>mtd@amazon.com</DisplayName>
        </Owner>
    </Contents>
</ListBucketResult>
