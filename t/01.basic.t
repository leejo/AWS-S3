#-*-Perl-*-

# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.t'

use strict;
use ExtUtils::MakeMaker;
use FindBin '$Bin';
use constant TEST_COUNT => 9;

use lib "$Bin/lib","$Bin/../lib","$Bin/../blib/lib","$Bin/../blib/arch";

use Test::More tests => TEST_COUNT;

use_ok('AWS::Signature4');
use_ok('HTTP::Request::Common');

my $signer = AWS::Signature4->new(-access_key => 'AKIDEXAMPLE',
				  -secret_key => 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY');
ok($signer,'AWS::Signature4->new');
my $request = POST('https://iam.amazonaws.com',
		   [Action=>'ListUsers', Version=>'2010-05-08'],
		   Date    => '1 January 2014 01:00:00 -0500',
    );
$signer->sign($request);

is($request->method,'POST','request method correct');
is($request->header('Host'),'iam.amazonaws.com','host correct');
is($request->header('X-Amz-Date'),'20140101T060000Z','timestamp correct');
is($request->content,'Action=ListUsers&Version=2010-05-08','payload correct');
is($request->header('Authorization'),'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20140101/us-east-1/iam/aws4_request, SignedHeaders=content-length;content-type;date;host;x-amz-date, Signature=02602afd2fea62f4759cee1fb8efd8c9a23677db0cd158cecf161cef7d218d9d','signature correct');
is($signer->signed_url($request),'https://iam.amazonaws.com?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIDEXAMPLE%2F20140101%2Fus-east-1%2Fiam%2Faws4_request&X-Amz-Date=20140101T060000Z&X-Amz-SignedHeaders=host&X-Amz-Signature=a5a51663feedc8a57a7958321cc5cb4fead89e50df943c5d7b62e1dac7013e49','signed url correct');

exit 0;

