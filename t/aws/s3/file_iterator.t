#!perl

use strict;
use warnings;

package Mocked::HTTP::Response;

use Moose;
extends 'HTTP::Response';

sub content        { shift->{_msg}; }
sub code           { 200 }
sub friendly_error {}
sub is_success     { 1 }
sub header         { $_[1] =~ /content-length/i ? 1 : 'header' }

1;

use Test::More;
use FindBin qw/ $Script /;

use Carp 'confess';
$SIG{__DIE__} = \&confess;

use_ok('AWS::S3');
use_ok('AWS::S3::FileIterator');
use_ok('AWS::S3::Bucket');

my $s3 = AWS::S3->new(
    access_key_id     => $ENV{AWS_ACCESS_KEY_ID}     // 'foo',
    secret_access_key => $ENV{AWS_SECRET_ACCESS_KEY} // 'bar',
    endpoint          => $ENV{AWS_ENDPOINT}          // 's3.baz.com',
);

isa_ok(
    my $bucket = AWS::S3::Bucket->new(
        s3   => $s3,
        name => $ENV{AWS_TEST_BUCKET} // 'maibucket',
    ),
    'AWS::S3::Bucket'
);


isa_ok(
	my $iterator = AWS::S3::FileIterator->new(
		page_number => 1,
		page_size   => 1,
		bucket      => $bucket,
	),
	'AWS::S3::FileIterator'
);

is( $iterator->marker,'','marker' );
is( $iterator->pattern,qr/.*/,'pattern' );
isa_ok( $iterator->bucket,'AWS::S3::Bucket' );
is( $iterator->page_size,1,'page_size' );
is( $iterator->has_prev,'','has_prev' );
is( $iterator->has_next,undef,'has_next' );
is( $iterator->page_number,0,'page_number' );

my $xml = do { local $/; <DATA> };

no warnings 'once';
my $mocked_response = Mocked::HTTP::Response->new( 200,$xml );
*LWP::UserAgent::Determined::request = sub { $mocked_response };

ok( $iterator->next_page,'next_page' );

done_testing();

__DATA__
<?xml version="1.0" encoding="UTF-8"?>
<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
    <Name>bucket</Name>
    <Prefix/>
    <Marker/>
    <MaxKeys>1000</MaxKeys>
    <IsTruncated>false</IsTruncated>
    <Contents>
        <Key>my image.jpg</Key>
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
