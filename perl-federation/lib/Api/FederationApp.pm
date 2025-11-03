package Api::FederationApp;
use strict;
use warnings;

use Dancer2 appname => 'Api::FederationApp';
use Dancer2::Serializer::JSON;
use JSON::MaybeXS ();
use POSIX qw(strftime);
use Try::Tiny;
use lib 'lib';
use Api::FederationModel;

set serializer => 'JSON';

my $model = Api::FederationModel->new_from_env();

get '/_ping' => sub {
    my $now = strftime("%Y-%m-%dT%H:%M:%S%z", localtime);
    return { ok => 1, now => $now };
};

get '/members' => sub {
    my $params = params;
    my $rows = $model->list_members($params);
    content_type 'application/json';
    return $rows;
};

post '/members' => sub {
    my $raw = request->body;
    my $data;
    try {
        $data = JSON::MaybeXS::decode_json($raw // '{}');
    } catch {
        status 400; return { error => 'Invalid JSON body' };
    };
    unless ($data && ref $data eq 'HASH') { status 400; return { error => 'Invalid JSON payload' } }
    try {
        my $id = $model->create_member($data);
        status 201; return { id => $id };
    } catch {
        status 400; return { error => "Create failed: $_" };
    }
};

get '/members/:id' => sub {
    my $id = route_parameters->get('id');
    my $row = $model->get_member($id);
    unless ($row) { status 404; return { error => 'Not found' } }
    return $row;
};

put '/members/:id' => sub {
    my $id = route_parameters->get('id');
    my $raw = request->body;
    my $data;
    try {
        $data = JSON::MaybeXS::decode_json($raw // '{}');
    } catch {
        status 400; return { error => 'Invalid JSON body' };
    };
    try {
        $model->update_member($id, $data);
        return { ok => 1 };
    } catch {
        status 400; return { error => "Update failed: $_" };
    }
};

del '/members/:id' => sub {
    my $id = route_parameters->get('id');
    $model->delete_member($id);
    status 204; return '';
};

1;
