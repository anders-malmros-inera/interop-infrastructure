package Api::App;
use strict;
use warnings;

use Dancer2 appname => 'Api::App';
use Dancer2::Serializer::JSON;
use JSON::MaybeXS (); # don't import encode/decode to avoid prototype conflicts
use Time::Piece;
use POSIX qw(strftime);
use Try::Tiny;
use lib 'lib';
use Api::Model;

set serializer => 'JSON';

my $model = Api::Model->new_from_env();

get '/_ping' => sub {
    # Return a plain data structure. Use POSIX strftime to ensure a plain string
    # (avoid returning any blessed Time::Piece objects which JSON::MaybeXS can't encode by default)
    my $now = strftime("%Y-%m-%dT%H:%M:%S%z", localtime);
    return { ok => 1, now => $now };
};

get '/apis' => sub {
    my $params = params;
    warn "GET /apis called with: " . join(', ', map { "$_=" . ($params->{$_} // '') } keys %$params) . "\n";
    my $logical = $params->{logicalAddress};
    my $interop = $params->{interoperabilitySpecificationId};
    my $status = $params->{status};

    unless ($logical && $interop) {
        status 400;
        return { error => 'logicalAddress and interoperabilitySpecificationId are required' };
    }

    my $rows = $model->list_apis({ logicalAddress => $logical, interoperabilitySpecificationId => $interop, status => $status });
    # Ensure JSON is returned and log the payload for debugging
    content_type 'application/json';
    # Return the raw data structure and let Dancer2 serialize to JSON
    return $rows;
};

post '/apis' => sub {
    my $data = body_parameters->as_hashref;
    unless ($data && ref $data eq 'HASH') { status 400; return { error => 'Invalid JSON' } }
    try {
        my $id = $model->create_api($data);
        status 201;
        return { id => $id };
    } catch {
        status 400;
        return { error => "Create failed: $_" };
    }
};

get '/apis/:id' => sub {
    my $id = route_parameters->get('id');
    my $row = $model->get_api($id);
    unless ($row) { status 404; return { error => 'Not found' } }
    return $row;
};

put '/apis/:id' => sub {
    my $id = route_parameters->get('id');
    my $data = body_parameters->as_hashref;
    try {
        $model->update_api($id, $data);
        return { ok => 1 };
    } catch {
        status 400; return { error => "Update failed: $_" };
    }
};

del '/apis/:id' => sub {
    my $id = route_parameters->get('id');
    $model->delete_api($id);
    status 204;
    return '';
};

get '/sync/apis' => sub {
    my $params = params;
    my $filters = {
        updatedSince => $params->{updatedSince},
        organizationId => $params->{organizationId},
        interoperabilitySpecificationId => $params->{interoperabilitySpecificationId},
    };
    my $rows = $model->sync_apis($filters);
    return $rows;
};

1;
