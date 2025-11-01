package Api::Model;
use strict;
use warnings;

use DBI;
use Time::Piece;
use JSON::MaybeXS qw(encode_json decode_json);
use UUID::Tiny ':std';

sub new_from_env {
    my ($class) = @_;
    my $db_host = $ENV{DB_HOST} // 'db';
    my $db_port = $ENV{DB_PORT} // 5432;
    my $db_name = $ENV{DB_NAME} // 'service_catalog';
    my $db_user = $ENV{DB_USER} // 'svcuser';
    my $db_pass = $ENV{DB_PASS} // 'svcpass';
    my $dsn = "dbi:Pg:dbname=$db_name;host=$db_host;port=$db_port";

    # Retry loop: the DB container might take a moment to become available
    my $dbh;
    for my $attempt (1..12) {
        eval {
            $dbh = DBI->connect($dsn, $db_user, $db_pass, { AutoCommit => 1, RaiseError => 1, pg_enable_utf8 => 1 });
        };
        if ($dbh) { last }
        warn "DB connect attempt $attempt failed: $@";
        sleep 2;
    }
    die "DB connection failed after retries" unless $dbh;
    return bless { dbh => $dbh }, $class;
}

sub list_apis {
    my ($self, $filters) = @_;
    my $sql = 'SELECT * FROM api_instances WHERE logical_address = ? AND interoperability_specification_id = ?';
    my @bind = ($filters->{logicalAddress}, $filters->{interoperabilitySpecificationId});
    if ($filters->{status}) {
        $sql .= ' AND status = ?'; push @bind, $filters->{status};
    }
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute(@bind);
    my @rows;
    while (my $r = $sth->fetchrow_hashref) { push @rows, $self->_row_to_api($r) }
    return \@rows;
}

sub get_api {
    my ($self, $id) = @_;
    my $sth = $self->{dbh}->prepare('SELECT * FROM api_instances WHERE id = ?');
    $sth->execute($id);
    my $r = $sth->fetchrow_hashref or return;
    return $self->_row_to_api($r);
}

sub create_api {
    my ($self, $data) = @_;
    my $id = $data->{id} // create_uuid_as_string(UUID_V4);
    my $now = Time::Piece->new->datetime;
    my $sth = $self->{dbh}->prepare(q{
        INSERT INTO api_instances (id, logical_address, organization_id, organization_name,
          interoperability_specification_id, api_standard, url, status,
          access_model_type, access_model_metadata_url, signature, created_at, updated_at)
        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)
    });
    $sth->execute(
        $id,
        $data->{logicalAddress},
        $data->{organization}{id},
        $data->{organization}{name},
        $data->{interoperabilitySpecificationId},
        $data->{apiStandard},
        $data->{url},
        $data->{status},
        $data->{accessModel}{type},
        $data->{accessModel}{metadataUrl},
        $data->{signature},
        $now,
        $now,
    );
    return $id;
}

sub update_api {
    my ($self, $id, $data) = @_;
    my $now = Time::Piece->new->datetime;
    my $sth = $self->{dbh}->prepare(q{
        UPDATE api_instances SET logical_address=?, organization_id=?, organization_name=?,
          interoperability_specification_id=?, api_standard=?, url=?, status=?,
          access_model_type=?, access_model_metadata_url=?, signature=?, updated_at=?
        WHERE id = ?
    });
    $sth->execute(
        $data->{logicalAddress},
        $data->{organization}{id},
        $data->{organization}{name},
        $data->{interoperabilitySpecificationId},
        $data->{apiStandard},
        $data->{url},
        $data->{status},
        $data->{accessModel}{type},
        $data->{accessModel}{metadataUrl},
        $data->{signature},
        $now,
        $id,
    );
    return 1;
}

sub delete_api {
    my ($self, $id) = @_;
    my $sth = $self->{dbh}->prepare('DELETE FROM api_instances WHERE id = ?');
    $sth->execute($id);
    return 1;
}

sub sync_apis {
    my ($self, $filters) = @_;
    my $sql = 'SELECT * FROM api_instances WHERE 1=1';
    my @bind;
    if ($filters->{updatedSince}) {
        $sql .= ' AND updated_at > ?'; push @bind, $filters->{updatedSince};
    }
    if ($filters->{organizationId}) { $sql .= ' AND organization_id = ?'; push @bind, $filters->{organizationId} }
    if ($filters->{interoperabilitySpecificationId}) { $sql .= ' AND interoperability_specification_id = ?'; push @bind, $filters->{interoperabilitySpecificationId} }
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute(@bind);
    my @rows;
    while (my $r = $sth->fetchrow_hashref) { push @rows, $self->_row_to_api($r) }
    return \@rows;
}

sub _row_to_api {
    my ($self, $r) = @_;
    return {
        id => $r->{id},
        logicalAddress => $r->{logical_address},
        organization => { id => $r->{organization_id}, name => $r->{organization_name} },
        interoperabilitySpecificationId => $r->{interoperability_specification_id},
        apiStandard => $r->{api_standard},
        url => $r->{url},
        status => $r->{status},
        accessModel => { type => $r->{access_model_type}, metadataUrl => $r->{access_model_metadata_url} },
        signature => $r->{signature},
        createdAt => $r->{created_at},
        updatedAt => $r->{updated_at},
    };
}

1;
