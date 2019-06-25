
package AWS::S3::Request::GetPreSignedUrl;
use Moose;

use AWS::S3::Signer;
use Signer::AWSv4::S3;
use URI::Escape qw(uri_escape);

with 'AWS::S3::Roles::Request';

has 'bucket' => ( is => 'ro', isa => 'Str', required => 1 );
has 'key' => ( is => 'ro', isa => 'Str', required => 1 );
has 'expires' => ( is => 'ro', isa => 'Int', required => 1 );

sub request {
    my $s = shift;

    my $uri = $s->_uri;

    my $req = "GET\n\n\n"
        . $s->expires . "\n/"
        . $s->bucket . "/"
        . $s->key;

    my $signer = AWS::S3::Signer->new(
        s3             => $s->s3,
        method         => "GET",
        uri            => $uri,
        string_to_sign => $req,
    );

    my $signed_uri = $uri->as_string
        . '?AWSAccessKeyId=' . $s->s3->access_key_id
        . '&Expires=' . $s->expires
        . '&Signature=' . uri_escape( $signer->signature );

warn $signed_uri;

	my $region = $s->s3->bucket($s->bucket)->location_constraint;
	my $v4_signer = Signer::AWSv4::S3->new(
		access_key => $s->s3->access_key_id,
		secret_key => $s->s3->secret_access_key,
		method     => 'GET',
		key        => $s->key,
		bucket     => '',
		region     => $region,
		expires    => $s->expires < 604800 ? $s->expires : 604799,
	);

	# Signer::AWSv4::S3 won't let us initialize the object with bucket_host
	# and it is set to read only so we can't then set it. just break the
	# encapsulation here to set it
	$v4_signer->{bucket_host} = my $host = join( '.',$s->bucket,$s->s3->endpoint );
warn $v4_signer->signed_url;

	# and then remove the extraneous slash that we will add back at some point
    my $url = $v4_signer->signed_url;
	$url =~ s!$host/!$host!;

	#	if ( ! $s->s3->secure ) {
	#	$url =~ s/https:/http:/;
	#}

	return $url;
}

__PACKAGE__->meta->make_immutable;
