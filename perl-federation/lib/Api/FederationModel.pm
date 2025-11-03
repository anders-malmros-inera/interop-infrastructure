package Api::FederationModel;
use strict;
use warnings;

use DBI;
use Time::Piece;
use UUID::Tiny ':std';

sub new_from_env {
    my ($class) = @_;
    my $db_host = $ENV{DB_HOST} // 'db';
    my $db_port = $ENV{DB_PORT} // 5432;
    my $db_name = $ENV{DB_NAME} // 'service_catalog';
    my $db_user = $ENV{DB_USER} // 'svcuser';
    my $db_pass = $ENV{DB_PASS} // 'svcpass';
    my $dsn = "dbi:Pg:dbname=$db_name;host=$db_host;port=$db_port";

    my $dbh;
    for my $attempt (1..12) {
        eval { $dbh = DBI->connect($dsn, $db_user, $db_pass, { AutoCommit => 1, RaiseError => 1, pg_enable_utf8 => 1 }); };
        if ($dbh) { last }
        warn "DB connect attempt $attempt failed: $@";
        sleep 2;
    }
    die "DB connection failed after retries" unless $dbh;
    return bless { dbh => $dbh }, $class;
}

sub list_members {
    my ($self, $filters) = @_;
    my $sql = 'SELECT * FROM members WHERE 1=1';
    my @bind;
    if ($filters->{organizationId}) { $sql .= ' AND organization_id = ?'; push @bind, $filters->{organizationId} }
    if ($filters->{status}) { $sql .= ' AND status = ?'; push @bind, $filters->{status} }
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute(@bind);
    my @rows;
    while (my $r = $sth->fetchrow_hashref) { push @rows, $self->_row_to_member($r) }
    return \@rows;
}

sub get_member {
    my ($self, $id) = @_;
    my $sth = $self->{dbh}->prepare('SELECT * FROM members WHERE id = ?');
    $sth->execute($id);
    my $r = $sth->fetchrow_hashref or return;
    return $self->_row_to_member($r);
}

sub create_member {
    my ($self, $data) = @_;
    my $id = $data->{id} // create_uuid_as_string(UUID_V4);
    my $now = Time::Piece->new->datetime;
    my $sth = $self->{dbh}->prepare(q{
        INSERT INTO members (id, organization_id, name, status, created_at, updated_at)
        VALUES (?,?,?,?,?,?)
    });
    $sth->execute($id, $data->{organizationId} // $data->{organization_id}, $data->{name}, $data->{status}, $now, $now);
    return $id;
}

sub update_member {
    my ($self, $id, $data) = @_;
    my $now = Time::Piece->new->datetime;
    my $sth = $self->{dbh}->prepare(q{
        UPDATE members SET organization_id=?, name=?, status=?, updated_at=? WHERE id = ?
    });
    $sth->execute($data->{organizationId} // $data->{organization_id}, $data->{name}, $data->{status}, $now, $id);
    return 1;
}

sub delete_member {
    my ($self, $id) = @_;
    my $sth = $self->{dbh}->prepare('DELETE FROM members WHERE id = ?');
    $sth->execute($id);
    return 1;
}

sub _row_to_member {
    my ($self, $r) = @_;
    return {
        id => $r->{id},
        organizationId => $r->{organization_id},
        name => $r->{name},
        status => $r->{status},
        createdAt => $r->{created_at},
        updatedAt => $r->{updated_at},
    };
}

1;
