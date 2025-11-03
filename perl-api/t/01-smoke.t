#!/usr/bin/env perl
use strict;
use warnings;
use Test::More tests => 3;
use HTTP::Tiny;
use JSON::MaybeXS;

my $base = $ENV{PERL_API_BASE} || 'http://localhost:5000';
my $http = HTTP::Tiny->new(timeout => 10);

# 1) Ping endpoint
my $res = $http->get("$base/_ping");
ok($res->{status} == 200, '_ping returns 200');
my $data = JSON::MaybeXS::decode_json($res->{content} // '{}');
ok($data->{ok}, '_ping returned ok flag');

# 3) Create an API (will require DB; run after compose is up)
my $payload = { logicalAddress => 'urn:smoke-test', interoperabilitySpecificationId => 'spec-smoke', name => 'smoke' };
$res = $http->post("$base/apis", { headers => { 'content-type' => 'application/json' }, content => JSON::MaybeXS::encode_json($payload) });
ok($res->{status} == 201, 'POST /apis returned 201 (create)');

__END__
