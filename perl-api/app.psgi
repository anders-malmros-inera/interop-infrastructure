use strict;
use warnings;

use lib 'lib';
use Dancer2;
use Api::App;

# Return the Dancer2 PSGI app in a compatible way
return Dancer2->psgi_app;
