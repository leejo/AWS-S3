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

package main;

use Test::More;
use Test::Deep;
use FindBin qw/ $Script /;

use Carp 'confess';
$SIG{__DIE__} = \&confess;

use_ok('AWS::S3');

note( "construction" );
my $s3 = AWS::S3->new(
    access_key_id     => $ENV{AWS_ACCESS_KEY_ID}     // 'foo',
    secret_access_key => $ENV{AWS_SECRET_ACCESS_KEY} // 'bar',
    endpoint          => $ENV{AWS_ENDPOINT}          // 's3.baz.com',
);

use_ok('AWS::S3::File');
use_ok('AWS::S3::Bucket');
use_ok('AWS::S3::Request::SetFileContents');

monkey_patch_module();

isa_ok(
    my $file = AWS::S3::File->new(
        key          => $ENV{AWS_TEST_KEY} // "$Script",
        contents     => sub { 'test file contents' },
        is_encrypted => 0,
        bucket       => AWS::S3::Bucket->new(
            s3   => $s3,
            name => $ENV{AWS_TEST_BUCKET} // 'maibucket',
        ),
    ),
    'AWS::S3::File'
);

can_ok(
    $file,
    qw/
        key
        bucket
        size
        etag
        owner
        storage_class
        lastmodified
        contenttype
        is_encrypted
        contents
    /,
);

note( "attributes" );
isa_ok( $file->bucket,'AWS::S3::Bucket','bucket' );
is( $file->key,$Script,'key' );
is( $file->size,'18','size' );
isa_ok( $file->etag,'main','etag' );
is( $file->owner,undef,'owner' );
is( $file->storage_class,'STANDARD','storage_class' );
is( $file->lastmodified,undef,'lastmodified' );
is( $file->contenttype,'binary/octet-stream','contenttype' );
is( $file->is_encrypted,0,'is_encrypted' );
isa_ok( $file->contents,'SCALAR','contents' );

note( "methods" );
ok( !$file->update,'update without args' );
ok( $file->update( contents => \'new contents' ),'update with args' );

is(
    $file->signed_url( 1406712744 ),
    'http://maibucket.s3.baz.com/file.t?AWSAccessKeyId=foo&Expires=1406712744&Signature=aaJJMHorwf0rUABnKFq1204gzi0=',
    'signed_url'
);

no warnings 'once';
my $mocked_response = Mocked::HTTP::Response->new( 200,'bar' );
*LWP::UserAgent::Determined::request = sub { $mocked_response };
$mocked_response->{_msg} = '';

ok( $file->delete,'->delete' );
ok( $file->_get_contents,'_get_contents' );

done_testing();

sub monkey_patch_module {
    # monkey patching for true(r) unit tests
    no warnings 'redefine';
    no warnings 'once';

    sub response { return shift; }
    sub header { return shift; }
    sub friendly_error { return; }

    *AWS::S3::Request::SetFileContents::request = sub {
        return bless( {},'main' );
    };
}